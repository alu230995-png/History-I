local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local BuildingConfig = require(Shared:WaitForChild("Constants"):WaitForChild("BuildingConfig"))
local GridConfig = require(Shared:WaitForChild("Constants"):WaitForChild("GridConfig"))
local PlayerStates = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStates"))
local HexUtils = require(Shared:WaitForChild("Utils"):WaitForChild("HexUtils"))

type ResourceState = {
	Gold: number,
	PopulationUsed: number,
	PopulationCap: number,
}

type SocketState = {
	Owner: Player?,
	Building: string?,
	BlockedReason: string?,
	HP: number,
	ModelRef: Instance?,
	Trove: any?,
}

type HexData = {
	TerrainType: string,
	HexPart: BasePart,
	Center: Vector3,
	EdgePositions: { [string]: Vector3 },
	EdgeYawDegrees: { [string]: number },
	Sockets: { [string]: SocketState },
}

type BuildRequest = {
	hexPart: any,
	socketName: any,
	buildingType: any,
	rotation: any?,
}

local BuildService = Knit.CreateService({
	Name = "BuildService",

	Client = {
		BuildingPlaced = Knit.CreateSignal(),
		ResourcesChanged = Knit.CreateSignal(),
	},
})

local MIN_REQUEST_INTERVAL = 0.12
local HEALTH_BAR_SIZE = UDim2.fromOffset(72, 6)
local HEALTH_BAR_OFFSET = Vector3.new(0, 3, 0)

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function isValidSocketName(socketName: any): boolean
	if socketName == "Center" then
		return true
	end

	if typeof(socketName) ~= "string" then
		return false
	end

	return tonumber(string.match(socketName, "^Edge([1-6])$")) ~= nil
end

local function cloneResourceState(resourceState: ResourceState): ResourceState
	return {
		Gold = resourceState.Gold,
		PopulationUsed = resourceState.PopulationUsed,
		PopulationCap = resourceState.PopulationCap,
	}
end

local function createResourceState(): ResourceState
	local starting = BuildingConfig.StartingResources

	return {
		Gold = starting.Gold,
		PopulationUsed = starting.PopulationUsed,
		PopulationCap = starting.PopulationCap,
	}
end

local function createSocketState(): SocketState
	return {
		Owner = nil,
		Building = nil,
		BlockedReason = nil,
		HP = 0,
		ModelRef = nil,
		Trove = nil,
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

local function normalizeRotation(rotation: any, definition): number
	if definition.RotationLocked == true then
		return 0
	end

	if not isFiniteNumber(rotation) then
		return 0
	end

	return (math.round(rotation / 60) * 60) % 360
end

local function getPlacementRotation(hexData: HexData, socketName: string, requestRotation: any, definition): number
	local placementMode = definition.PlacementMode or BuildingConfig.PlacementModes.Center

	if placementMode == BuildingConfig.PlacementModes.Edge then
		return ((hexData.EdgeYawDegrees[socketName] or 0) + (definition.ModelYawOffset or 0)) % 360
	end

	return normalizeRotation(requestRotation, definition)
end

local function getSocketPosition(hexData: HexData, socketName: string): Vector3?
	if socketName == "Center" then
		return hexData.Center
	end

	return hexData.EdgePositions[socketName]
end

local function getPlacementCFrame(socketPosition: Vector3, rotation: number, definition): CFrame
	local offset = definition.PivotOffset or Vector3.zero

	return CFrame.new(socketPosition + Vector3.new(0, offset.Y, 0)) * CFrame.Angles(0, math.rad(rotation), 0)
end

local function splitPath(path: string): { string }
	local parts = {}

	for segment in string.gmatch(path, "[^/%.]+") do
		table.insert(parts, segment)
	end

	return parts
end

local function resolvePath(path: any): Instance?
	if typeof(path) ~= "string" or path == "" then
		return nil
	end

	local segments = splitPath(path)
	local firstSegment = segments[1]
	if firstSegment == nil then
		return nil
	end

	local ok, current = pcall(function()
		return game:GetService(firstSegment)
	end)

	if not ok then
		current = ({
			game = game,
			Game = game,
			ReplicatedStorage = ReplicatedStorage,
			ServerStorage = ServerStorage,
			Workspace = Workspace,
		})[firstSegment]
	end

	if current == nil then
		return nil
	end

	for index = 2, #segments do
		current = (current :: Instance):FindFirstChild(segments[index])
		if current == nil then
			return nil
		end
	end

	return current :: Instance
end

local function cloneBuildingModel(buildingType: string, definition): Model?
	local source = resolvePath(definition.Path)
	if source == nil then
		warn(("[BuildService] Missing model path for %s: %s"):format(buildingType, tostring(definition.Path)))
		return nil
	end

	if not source:IsA("Model") then
		warn(
			("[BuildService] Building path for %s must point to a Model, got %s"):format(buildingType, source.ClassName)
		)
		return nil
	end

	return source:Clone()
end

local function createBuildingId(player: Player, buildingType: string): string
	return `{buildingType}_{player.UserId}_{math.floor(os.clock() * 100000)}`
end

local function createHealthBillboard(model: Model): BillboardGui?
	local primaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if primaryPart == nil then
		return nil
	end

	local _boxCFrame, boxSize = model:GetBoundingBox()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = BuildingConfig.HealthBillboardName
	billboard.Adornee = primaryPart
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 220
	billboard.Size = HEALTH_BAR_SIZE
	billboard.StudsOffsetWorldSpace = Vector3.new(0, (boxSize.Y * 0.5) + HEALTH_BAR_OFFSET.Y, 0)

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(5, 6, 6)
	background.BackgroundTransparency = 0.35
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = billboard

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = background

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.15
	stroke.Parent = background

	billboard.Parent = primaryPart

	return billboard
end

local function bindHealthBillboard(model: Model, billboard: BillboardGui)
	local background = billboard:FindFirstChild("Background")
	local fill = if background ~= nil then background:FindFirstChild("Fill") else nil
	if fill == nil or not fill:IsA("Frame") then
		return nil
	end

	local function updateFill()
		local hp = model:GetAttribute("HP")
		local maxHp = model:GetAttribute("MaxHP")
		if typeof(hp) ~= "number" or typeof(maxHp) ~= "number" or maxHp <= 0 then
			fill.Size = UDim2.fromScale(0, 1)
			return
		end

		fill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	end

	updateFill()
	local hpConnection = model:GetAttributeChangedSignal("HP"):Connect(updateFill)
	local maxHpConnection = model:GetAttributeChangedSignal("MaxHP"):Connect(updateFill)

	return function()
		hpConnection:Disconnect()
		maxHpConnection:Disconnect()
	end
end

local function preparePlacedModel(model: Model, player: Player, buildingType: string, definition, buildingId: string)
	model.Name = buildingId
	model:SetAttribute("BuildingId", buildingId)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("BuildingType", buildingType)
	model:SetAttribute("HP", definition.HP)
	model:SetAttribute("MaxHP", definition.HP)
	model:SetAttribute("Interactable", definition.Interactable == true)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = true
			descendant.CanTouch = false
			descendant.CanQuery = true
		end
	end
end

local function snapshotSockets(sockets: { [string]: SocketState }): { [string]: any }
	local snapshot = {}

	for socketName, socketState in sockets do
		snapshot[socketName] = {
			OwnerUserId = if socketState.Owner ~= nil then socketState.Owner.UserId else nil,
			Building = socketState.Building,
			BlockedReason = socketState.BlockedReason,
			Occupied = socketState.Building ~= nil,
			HP = socketState.HP,
		}
	end

	return snapshot
end

function BuildService.Client:GetResources(player: Player): ResourceState
	return cloneResourceState(self.Server:_getResources(player))
end

function BuildService.Client:GetHexSnapshot(_player: Player, hexPart: any): any
	if typeof(hexPart) ~= "Instance" or not hexPart:IsA("BasePart") then
		return nil
	end

	local hexData = self.Server:GetHexData(hexPart)
	if hexData == nil then
		return nil
	end

	return {
		hexPart = hexData.HexPart,
		TerrainType = hexData.TerrainType,
		Sockets = snapshotSockets(hexData.Sockets),
	}
end

function BuildService.Client:RequestBuild(
	player: Player,
	request: BuildRequest
): { ok: boolean, reason: string?, resources: ResourceState? }
	return self.Server:RequestBuild(player, request)
end

function BuildService:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._boardState = {}
	self._resources = {}
	self._lastRequestAt = {}
	self._gameService = nil

	self._placedFolder = Instance.new("Folder")
	self._placedFolder.Name = BuildingConfig.PlacedFolderName
	self._placedFolder.Parent = Workspace
	self._trove:Add(self._placedFolder)
end

function BuildService:KnitStart()
	self._gameService = Knit.GetService("GameService")
	self:RebuildBoardState()

	self._trove:Add(Players.PlayerAdded:Connect(function(player: Player)
		self:_initializePlayer(player)
	end))

	self._trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self._resources[player] = nil
		self._lastRequestAt[player] = nil
	end))

	for _, player in Players:GetPlayers() do
		self:_initializePlayer(player)
	end
end

function BuildService:RebuildBoardState()
	table.clear(self._boardState)

	for _, taggedInstance in CollectionService:GetTagged(GridConfig.BuildableHexTag) do
		self:_scanTaggedHex(taggedInstance)
	end
end

function BuildService:GetHexData(hexPart: BasePart): HexData?
	return self._boardState[hexPart]
end

function BuildService:BlockHexCenter(hexPart: BasePart, reason: string?, modelRef: Instance?): boolean
	local hexData = self:GetHexData(hexPart)
	if hexData == nil then
		return false
	end

	local socketState = hexData.Sockets.Center
	if socketState == nil or socketState.Building ~= nil then
		return false
	end

	socketState.Owner = nil
	socketState.Building = reason or "Blocked"
	socketState.BlockedReason = reason or "Blocked"
	socketState.HP = 0
	socketState.ModelRef = modelRef

	return true
end

function BuildService:RequestBuild(
	player: Player,
	request: BuildRequest
): { ok: boolean, reason: string?, resources: ResourceState? }
	local now = os.clock()
	local lastRequest = self._lastRequestAt[player]
	if lastRequest ~= nil and now - lastRequest < MIN_REQUEST_INTERVAL then
		return { ok = false, reason = "RateLimited", resources = cloneResourceState(self:_getResources(player)) }
	end
	self._lastRequestAt[player] = now

	local validation = self:_validateBuildRequest(player, request)
	if not validation.ok then
		return {
			ok = false,
			reason = validation.reason,
			resources = cloneResourceState(self:_getResources(player)),
		}
	end

	local definition = validation.definition
	local resources = self:_getResources(player)
	local buildingId = createBuildingId(player, validation.buildingType)

	resources.Gold -= definition.Gold
	resources.PopulationUsed += definition.Population
	resources.PopulationCap += definition.PopulationCapBonus or 0

	local model = validation.model
	preparePlacedModel(model, player, validation.buildingType, definition, buildingId)
	model:PivotTo(validation.placementCFrame)
	model.Parent = self._placedFolder

	local buildingTrove = Trove.new()
	buildingTrove:Add(model)
	self._trove:Add(buildingTrove)

	local healthBillboard = createHealthBillboard(model)
	if healthBillboard ~= nil then
		buildingTrove:Add(healthBillboard)
		local cleanupHealthBinding = bindHealthBillboard(model, healthBillboard)
		if cleanupHealthBinding ~= nil then
			buildingTrove:Add(cleanupHealthBinding)
		end
	end

	local socketState = validation.socketState
	socketState.Owner = player
	socketState.Building = validation.buildingType
	socketState.HP = definition.HP
	socketState.ModelRef = model
	socketState.Trove = buildingTrove

	self.Client.ResourcesChanged:Fire(player, cloneResourceState(resources))
	self.Client.BuildingPlaced:FireAll({
		BuildingId = buildingId,
		OwnerUserId = player.UserId,
		BuildingType = validation.buildingType,
		hexPart = validation.hexPart,
		socketName = validation.socketName,
		rotation = validation.rotation,
	})

	return { ok = true, resources = cloneResourceState(resources) }
end

function BuildService:_validateBuildRequest(player: Player, request: BuildRequest): any
	if type(request) ~= "table" then
		return { ok = false, reason = "InvalidRequest" }
	end

	if self._gameService ~= nil and self._gameService:GetPlayerState(player) ~= PlayerStates.Building then
		return { ok = false, reason = "NotBuilding" }
	end

	local hexPart = request.hexPart
	local socketName = request.socketName
	local buildingType = BuildingConfig.NormalizeBuildingType(request.buildingType)

	if typeof(hexPart) ~= "Instance" or not hexPart:IsA("BasePart") then
		return { ok = false, reason = "InvalidHex" }
	end

	if not isValidSocketName(socketName) then
		return { ok = false, reason = "InvalidSocket" }
	end

	if buildingType == nil then
		return { ok = false, reason = "InvalidBuilding" }
	end

	local definition = BuildingConfig.Buildings[buildingType]
	if definition == nil then
		return { ok = false, reason = "InvalidBuilding" }
	end

	local placementMode = definition.PlacementMode or BuildingConfig.PlacementModes.Center
	if not BuildingConfig.IsSocketValidForPlacementMode(placementMode, socketName) then
		return { ok = false, reason = "InvalidPlacementSocket" }
	end

	if not BuildingConfig.IsSocketAllowed(buildingType, socketName) then
		return { ok = false, reason = "SocketNotAllowed" }
	end

	local hexData = self:GetHexData(hexPart)
	if hexData == nil then
		return { ok = false, reason = "MissingHex" }
	end

	if hexData.HexPart.Parent == nil then
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

	local resources = self:_getResources(player)
	if resources.Gold < definition.Gold then
		return { ok = false, reason = "NotEnoughGold" }
	end

	if resources.PopulationUsed + definition.Population > resources.PopulationCap then
		return { ok = false, reason = "NotEnoughPopulation" }
	end

	local socketPosition = getSocketPosition(hexData, socketName)
	if socketPosition == nil then
		return { ok = false, reason = "InvalidSocket" }
	end

	local rotation = getPlacementRotation(hexData, socketName, request.rotation, definition)
	local placementCFrame = getPlacementCFrame(socketPosition, rotation, definition)
	local model = cloneBuildingModel(buildingType, definition)
	if model == nil then
		return { ok = false, reason = "MissingBuildingModel" }
	end

	model:PivotTo(placementCFrame)

	if self:_modelCollides(model, hexData.HexPart) then
		model:Destroy()
		return { ok = false, reason = "BlockedByCollision" }
	end

	return {
		ok = true,
		hexPart = hexData.HexPart,
		socketName = socketName,
		buildingType = buildingType,
		rotation = rotation,
		definition = definition,
		socketState = socketState,
		model = model,
		placementCFrame = placementCFrame,
	}
end

function BuildService:_modelCollides(model: Model, placementHex: BasePart): boolean
	local boxCFrame, boxSize = model:GetBoundingBox()
	if boxSize.Magnitude <= 0 then
		return false
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { model, placementHex }

	for _, part in Workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams) do
		if part:IsDescendantOf(model) or part == placementHex then
			continue
		end

		if CollectionService:HasTag(part, GridConfig.BuildableHexTag) then
			continue
		end

		if part.Transparency >= 1 and not part.CanCollide and not part.CanQuery then
			continue
		end

		return true
	end

	return false
end

function BuildService:_initializePlayer(player: Player)
	if self._resources[player] ~= nil then
		return
	end

	self._resources[player] = createResourceState()
	self.Client.ResourcesChanged:Fire(player, cloneResourceState(self._resources[player]))
end

function BuildService:_getResources(player: Player): ResourceState
	if self._resources[player] == nil then
		self:_initializePlayer(player)
	end

	return self._resources[player]
end

function BuildService:_scanTaggedHex(taggedInstance: Instance)
	if not taggedInstance:IsA("BasePart") then
		warn(("[BuildService] Ignoring tagged non-BasePart %s"):format(taggedInstance:GetFullName()))
		return
	end

	local hexPart = taggedInstance :: BasePart
	if self._boardState[hexPart] ~= nil then
		warn(("[BuildService] Ignoring duplicate tagged hex %s"):format(hexPart:GetFullName()))
		return
	end

	applyPartDefaults(hexPart)

	local socketPositions = HexUtils.getSocketPositionsFromPart(hexPart)
	local edgePositions = {}
	local edgeYawDegrees = {}

	for edgeIndex = 1, 6 do
		local socketName = HexUtils.getEdgeSocketName(edgeIndex)
		edgePositions[socketName] = socketPositions.Edge[edgeIndex]
		edgeYawDegrees[socketName] = HexUtils.getEdgeYawDegreesFromPart(hexPart, socketName)
	end

	self._boardState[hexPart] = {
		TerrainType = getTerrainType(hexPart),
		HexPart = hexPart,
		Center = socketPositions.Center,
		EdgePositions = edgePositions,
		EdgeYawDegrees = edgeYawDegrees,
		Sockets = createSockets(),
	}
end

function BuildService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
	table.clear(self._boardState)
	table.clear(self._resources)
	table.clear(self._lastRequestAt)
end

return BuildService
