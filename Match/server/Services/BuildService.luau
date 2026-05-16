local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local GridConfig = require(Shared:WaitForChild("Constants"):WaitForChild("GridConfig"))
local HexUtils = require(Shared:WaitForChild("Utils"):WaitForChild("HexUtils"))

type SocketState = {
	Owner: Player?,
	Building: string?,
	HP: number,
	ModelRef: Instance?,
}

type HexData = {
	TerrainType: string,
	HexPart: BasePart,
	Sockets: { [string]: SocketState },
}

type BuildRequest = {
	q: any,
	r: any,
	socketName: any,
	buildingType: any,
	rotation: any?,
}

local BuildService = Knit.CreateService({
	Name = "BuildService",

	Client = {},
})

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function isInteger(value: any): boolean
	return isFiniteNumber(value) and value % 1 == 0
end

local function isValidSocketName(socketName: any): boolean
	if socketName == "Center" then
		return true
	end

	if typeof(socketName) ~= "string" then
		return false
	end

	local edgeIndex = tonumber(string.match(socketName, "^Edge([1-6])$"))
	return edgeIndex ~= nil
end

local function createSocketState(): SocketState
	return {
		Owner = nil,
		Building = nil,
		HP = 0,
		ModelRef = nil,
	}
end

local function createSockets(): { [string]: SocketState }
	return {
		Center = createSocketState(),
		Edge1 = createSocketState(),
		Edge2 = createSocketState(),
		Edge3 = createSocketState(),
		Edge4 = createSocketState(),
		Edge5 = createSocketState(),
		Edge6 = createSocketState(),
	}
end

local function applyPartDefaults(hexPart: BasePart)
	if not GridConfig.AutoOptimizeHexParts then
		return
	end

	for propertyName, value in GridConfig.HexPartDefaults do
		local ok, message = pcall(function()
			(hexPart :: any)[propertyName] = value
		end)

		if not ok then
			warn(("[BuildService] Could not apply %s to %s: %s"):format(propertyName, hexPart:GetFullName(), message))
		end
	end
end

local function getTerrainType(hexPart: BasePart): string
	local terrainType = hexPart:GetAttribute("TerrainType")
	if typeof(terrainType) ~= "string" or terrainType == "" then
		return GridConfig.DefaultTerrainType
	end

	return terrainType
end

local function getFlatDistance(a: Vector3, b: Vector3): number
	local deltaX = a.X - b.X
	local deltaZ = a.Z - b.Z

	return math.sqrt((deltaX * deltaX) + (deltaZ * deltaZ))
end

local function isPartAlignedToCoord(hexPart: BasePart, q: number, r: number): boolean
	local coord = HexUtils.getHexCoordFromPart(hexPart, GridConfig)
	if coord.q ~= q or coord.r ~= r then
		return false
	end

	local expectedCenter = HexUtils.axialToWorld(
		q,
		r,
		GridConfig.HexWidth,
		GridConfig.HexHeight,
		hexPart.Position.Y,
		GridConfig.GridOrigin
	)

	return getFlatDistance(hexPart.Position, expectedCenter) <= GridConfig.HexSnapTolerance
end

function BuildService.Client:GetHexSnapshot(_player: Player, q: any, r: any): any
	if not isInteger(q) or not isInteger(r) then
		return nil
	end

	local hexData = self.Server:GetHexData(q, r)
	if hexData == nil then
		return nil
	end

	return {
		q = q,
		r = r,
		TerrainType = hexData.TerrainType,
	}
end

function BuildService.Client:RequestBuild(player: Player, request: BuildRequest): { ok: boolean, reason: string? }
	return self.Server:RequestBuild(player, request)
end

function BuildService:KnitInit()
	self._trove = Trove.new()
	self._boardState = {}
	self._partCoords = {}
end

function BuildService:KnitStart()
	self:RebuildBoardState()

	self._trove:Add(CollectionService:GetInstanceAddedSignal(GridConfig.BuildableHexTag):Connect(function(instance: Instance)
		self:_scanTaggedHex(instance)
	end))

	self._trove:Add(CollectionService:GetInstanceRemovedSignal(GridConfig.BuildableHexTag):Connect(function(instance: Instance)
		self:_removeTaggedHex(instance)
	end))
end

function BuildService:RebuildBoardState()
	table.clear(self._boardState)
	table.clear(self._partCoords)

	for _, taggedInstance in CollectionService:GetTagged(GridConfig.BuildableHexTag) do
		self:_scanTaggedHex(taggedInstance)
	end
end

function BuildService:GetHexData(q: number, r: number): HexData?
	local row = self._boardState[q]
	return if row ~= nil then row[r] else nil
end

function BuildService:RequestBuild(player: Player, request: BuildRequest): { ok: boolean, reason: string? }
	if type(request) ~= "table" then
		return { ok = false, reason = "InvalidRequest" }
	end

	local q = request.q
	local r = request.r
	local socketName = request.socketName
	local buildingType = request.buildingType

	if not isInteger(q) or not isInteger(r) then
		return { ok = false, reason = "InvalidCoord" }
	end

	if not isValidSocketName(socketName) then
		return { ok = false, reason = "InvalidSocket" }
	end

	if typeof(buildingType) ~= "string" or buildingType == "" then
		return { ok = false, reason = "InvalidBuilding" }
	end

	if request.rotation ~= nil and not isFiniteNumber(request.rotation) then
		return { ok = false, reason = "InvalidRotation" }
	end

	local hexData = self:GetHexData(q, r)
	if hexData == nil then
		return { ok = false, reason = "MissingHex" }
	end

	if hexData.HexPart.Parent == nil or not isPartAlignedToCoord(hexData.HexPart, q, r) then
		return { ok = false, reason = "StaleHex" }
	end

	if not GridConfig.BuildableTerrains[hexData.TerrainType] then
		return { ok = false, reason = "BlockedTerrain" }
	end

	local socketState = hexData.Sockets[socketName]
	if socketState == nil then
		return { ok = false, reason = "InvalidSocket" }
	end

	if socketState.Building ~= nil then
		return { ok = false, reason = "SocketOccupied" }
	end

	socketState.Owner = player
	socketState.Building = buildingType
	socketState.HP = 1
	socketState.ModelRef = nil

	return { ok = true }
end

function BuildService:_scanTaggedHex(taggedInstance: Instance)
	if not taggedInstance:IsA("BasePart") then
		warn(("[BuildService] Ignoring tagged non-BasePart %s"):format(taggedInstance:GetFullName()))
		return
	end

	local hexPart = taggedInstance :: BasePart
	local coord = HexUtils.getHexCoordFromPart(hexPart, GridConfig)
	local expectedCenter = HexUtils.axialToWorld(
		coord.q,
		coord.r,
		GridConfig.HexWidth,
		GridConfig.HexHeight,
		hexPart.Position.Y,
		GridConfig.GridOrigin
	)
	local snapDistance = getFlatDistance(hexPart.Position, expectedCenter)

	if snapDistance > GridConfig.HexSnapTolerance then
		warn(
			("[BuildService] Ignoring misaligned hex %s at (%d,%d); snap distance %.2f > %.2f"):format(
				hexPart:GetFullName(),
				coord.q,
				coord.r,
				snapDistance,
				GridConfig.HexSnapTolerance
			)
		)
		return
	end

	self._boardState[coord.q] = self._boardState[coord.q] or {}

	if self._boardState[coord.q][coord.r] ~= nil then
		warn(
			("[BuildService] Ignoring duplicate hex %s at (%d,%d)"):format(hexPart:GetFullName(), coord.q, coord.r)
		)
		return
	end

	applyPartDefaults(hexPart)

	self._boardState[coord.q][coord.r] = {
		TerrainType = getTerrainType(hexPart),
		HexPart = hexPart,
		Sockets = createSockets(),
	}
	self._partCoords[hexPart] = coord
end

function BuildService:_removeTaggedHex(taggedInstance: Instance)
	if not taggedInstance:IsA("BasePart") then
		return
	end

	local hexPart = taggedInstance :: BasePart
	local coord = self._partCoords[hexPart]
	if coord == nil then
		return
	end

	local row = self._boardState[coord.q]
	if row ~= nil and row[coord.r] ~= nil and row[coord.r].HexPart == hexPart then
		row[coord.r] = nil
	end

	self._partCoords[hexPart] = nil
end

function BuildService:Destroy()
	self._trove:Destroy()
	table.clear(self._boardState)
	table.clear(self._partCoords)
end

return BuildService
