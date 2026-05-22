local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))
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
	State: string?,
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

type MoveRequest = {
	buildingId: any,
	hexPart: any,
	socketName: any,
	rotation: any?,
}

type DestroyRequest = {
	buildingId: any,
}

local BuildService = Knit.CreateService({
	Name = "BuildService",

	Client = {
		BuildingPlaced = Knit.CreateSignal(),
		BuildingMoved = Knit.CreateSignal(),
		BuildingDestroyed = Knit.CreateSignal(),
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

local function getHexState(hexPart: BasePart): string?
	local state = hexPart:GetAttribute("State")
	return if typeof(state) == "string" and state ~= "" then state else nil
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
		local rotation = ((hexData.EdgeYawDegrees[socketName] or 0) + (definition.ModelYawOffset or 0)) % 360
		return rotation
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
	local pivotTopOffsetY = GridConfig.BuildingPivotTopOffsetY or 0

	return CFrame.new(socketPosition + Vector3.new(0, pivotTopOffsetY + offset.Y, 0))
		* CFrame.Angles(0, math.rad(rotation), 0)
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

local function clearSocketState(socketState: SocketState, destroyTrove: boolean)
	if destroyTrove and socketState.Trove ~= nil then
		socketState.Trove:Destroy()
	end

	socketState.Owner = nil
	socketState.Building = nil
	socketState.BlockedReason = nil
	socketState.HP = 0
	socketState.ModelRef = nil
	socketState.Trove = nil
end

function BuildService.Client:GetResources(player: Player): ResourceState
	return cloneResourceState(self.Server:_getResources(player))
end

function BuildService.Client:GetHexSnapshot(player: Player, hexPart: any): any
	if typeof(hexPart) ~= "Instance" or not hexPart:IsA("BasePart") then
		return nil
	end

	local hexData = self.Server:GetHexData(hexPart)
	if hexData == nil then
		return nil
	end

	local territoryAllowed, territoryReason = self.Server:_validateTerritory(player, hexData)

	return {
		hexPart = hexData.HexPart,
		TerrainType = hexData.TerrainType,
		State = hexData.State,
		TerritoryAllowed = territoryAllowed,
		TerritoryReason = territoryReason,
		Sockets = snapshotSockets(hexData.Sockets),
	}
end

function BuildService.Client:RequestBuild(
	player: Player,
	request: BuildRequest
): { ok: boolean, reason: string?, resources: ResourceState? }
	return self.Server:RequestBuild(player, request)
end

function BuildService.Client:RequestMove(player: Player, request: MoveRequest): { ok: boolean, reason: string? }
	return self.Server:RequestMove(player, request)
end

function BuildService.Client:RequestDestroy(player: Player, request: DestroyRequest): { ok: boolean, reason: string? }
	return self.Server:RequestDestroy(player, request)
end

function BuildService:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._boardState = {}
	self._buildingLocations = {}
	self._buildingCounts = {}
	self._lastRequestAt = {}
	self._gameService = nil
	self._nexoService = nil
	self._resourceService = nil
	self.BuildingDestroyed = Signal.new()
	self.BuildingPlaced = Signal.new()
	self.BuildingMoved = Signal.new()
	self.CenterPathingChanged = Signal.new()
	self._trove:Add(self.BuildingDestroyed)
	self._trove:Add(self.BuildingPlaced)
	self._trove:Add(self.BuildingMoved)
	self._trove:Add(self.CenterPathingChanged)

	self._placedFolder = Instance.new("Folder")
	self._placedFolder.Name = BuildingConfig.PlacedFolderName
	self._placedFolder.Parent = Workspace
	self._trove:Add(self._placedFolder)
end

function BuildService:KnitStart()
	self._gameService = Knit.GetService("GameService")
	self._nexoService = Knit.GetService("NexoService")
	self._resourceService = Knit.GetService("MatchResourceService")
	self:RebuildBoardState()

	self._trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self._buildingCounts[player] = nil
		self._lastRequestAt[player] = nil
	end))
	self._trove:Add(self._resourceService.ResourcesChanged:Connect(function(player: Player, resources: ResourceState)
		self.Client.ResourcesChanged:Fire(player, resources)
	end))
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

function BuildService:GetPlacedBuildingRecord(buildingId: any): any?
	if typeof(buildingId) ~= "string" then
		return nil
	end

	local location = self._buildingLocations[buildingId]
	if location == nil or location.SocketState == nil then
		return nil
	end

	local socketState = location.SocketState :: SocketState
	local model = socketState.ModelRef
	if socketState.Owner == nil or socketState.Building == nil or model == nil then
		return nil
	end

	return {
		BuildingId = buildingId,
		BuildingType = socketState.Building,
		Owner = socketState.Owner,
		Model = model,
		HexPart = location.HexData.HexPart,
		HexData = location.HexData,
		SocketName = location.SocketName,
	}
end

function BuildService:GetPlacedBuildingRecords(): { any }
	local records = {}

	for buildingId in self._buildingLocations do
		local record = self:GetPlacedBuildingRecord(buildingId)
		if record ~= nil then
			table.insert(records, record)
		end
	end

	return records
end

function BuildService:IsHexCenterBlocked(hexPart: BasePart): boolean
	local hexData = self:GetHexData(hexPart)
	if hexData == nil then
		return false
	end

	local centerState = hexData.Sockets.Center
	return centerState ~= nil and centerState.Building ~= nil
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
	self.CenterPathingChanged:Fire(hexPart)

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
	local buildingId = createBuildingId(player, validation.buildingType)

	self._resourceService:ApplyBuildingPlaced(
		player,
		definition.Gold or 0,
		definition.Population or 0,
		definition.PopulationCapBonus or 0
	)

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
	socketState.BlockedReason = nil
	socketState.HP = definition.HP
	socketState.ModelRef = model
	socketState.Trove = buildingTrove
	model:SetAttribute("HexSocketName", validation.socketName)
	model:SetAttribute("PlacementRotation", validation.rotation)
	self._buildingLocations[buildingId] = {
		HexData = validation.hexData,
		SocketName = validation.socketName,
		SocketState = socketState,
	}
	self:_incrementBuildingCount(player, validation.buildingType)
	self.BuildingPlaced:Fire(self:GetPlacedBuildingRecord(buildingId))

	self.Client.BuildingPlaced:FireAll({
		BuildingId = buildingId,
		OwnerUserId = player.UserId,
		BuildingType = validation.buildingType,
		hexPart = validation.hexPart,
		socketName = validation.socketName,
		rotation = validation.rotation,
	})
	if validation.socketName == "Center" then
		self.CenterPathingChanged:Fire(validation.hexPart)
	end

	return { ok = true, resources = self:_getResources(player) }
end

function BuildService:RequestMove(player: Player, request: MoveRequest): { ok: boolean, reason: string? }
	local now = os.clock()
	local lastRequest = self._lastRequestAt[player]
	if lastRequest ~= nil and now - lastRequest < MIN_REQUEST_INTERVAL then
		return { ok = false, reason = "RateLimited" }
	end
	self._lastRequestAt[player] = now

	local validation = self:_validateMoveRequest(player, request)
	if not validation.ok then
		return {
			ok = false,
			reason = validation.reason,
		}
	end

	local model = validation.model
	local currentSocketState = validation.currentSocketState
	local nextSocketState = validation.socketState
	local buildingTrove = currentSocketState.Trove

	if currentSocketState ~= nextSocketState then
		clearSocketState(currentSocketState, false)
	end

	model:PivotTo(validation.placementCFrame)
	model:SetAttribute("HexSocketName", validation.socketName)
	model:SetAttribute("PlacementRotation", validation.rotation)

	nextSocketState.Owner = player
	nextSocketState.Building = validation.buildingType
	nextSocketState.BlockedReason = nil
	nextSocketState.HP = validation.hp
	nextSocketState.ModelRef = model
	nextSocketState.Trove = buildingTrove

	self._buildingLocations[validation.buildingId] = {
		HexData = validation.hexData,
		SocketName = validation.socketName,
		SocketState = nextSocketState,
	}
	self.BuildingMoved:Fire(self:GetPlacedBuildingRecord(validation.buildingId))

	self.Client.BuildingMoved:FireAll({
		BuildingId = validation.buildingId,
		OwnerUserId = player.UserId,
		BuildingType = validation.buildingType,
		hexPart = validation.hexPart,
		socketName = validation.socketName,
		rotation = validation.rotation,
	})
	if validation.currentSocketName == "Center" then
		self.CenterPathingChanged:Fire(validation.currentHexPart)
	end
	if validation.socketName == "Center" then
		self.CenterPathingChanged:Fire(validation.hexPart)
	end

	return { ok = true }
end

function BuildService:RequestDestroy(player: Player, request: DestroyRequest): { ok: boolean, reason: string? }
	if type(request) ~= "table" or typeof(request.buildingId) ~= "string" then
		return { ok = false, reason = "InvalidRequest" }
	end

	local location = self._buildingLocations[request.buildingId]
	if location == nil or location.SocketState == nil then
		return { ok = false, reason = "MissingBuilding" }
	end

	local socketState = location.SocketState :: SocketState
	if socketState.Owner ~= player then
		return { ok = false, reason = "NotOwner" }
	end

	local buildingType = socketState.Building
	local definition = if buildingType ~= nil then BuildingConfig.Buildings[buildingType] else nil
	if buildingType == nil or definition == nil then
		return { ok = false, reason = "InvalidBuilding" }
	end

	self:_destroyBuilding(request.buildingId, location)

	return { ok = true }
end

function BuildService:DamageBuilding(target: any, damage: any): { ok: boolean, reason: string?, hp: number? }
	if not isFiniteNumber(damage) or damage <= 0 then
		return { ok = false, reason = "InvalidDamage" }
	end

	local buildingId = nil
	if typeof(target) == "string" then
		buildingId = target
	elseif typeof(target) == "Instance" then
		buildingId = target:GetAttribute("BuildingId")
	end

	if typeof(buildingId) ~= "string" then
		return { ok = false, reason = "InvalidBuilding" }
	end

	local location = self._buildingLocations[buildingId]
	if location == nil or location.SocketState == nil then
		return { ok = false, reason = "MissingBuilding" }
	end

	local socketState = location.SocketState :: SocketState
	socketState.HP = math.max(0, socketState.HP - damage)
	local model = socketState.ModelRef
	if model ~= nil then
		model:SetAttribute("HP", socketState.HP)
	end

	if socketState.HP <= 0 then
		self:_destroyBuilding(buildingId, location)
	end

	return { ok = true, hp = socketState.HP }
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

	local territoryOk, territoryReason = self:_validateTerritory(player, hexData)
	if not territoryOk then
		return { ok = false, reason = territoryReason }
	end

	local socketState = hexData.Sockets[socketName]
	if socketState == nil then
		return { ok = false, reason = "InvalidSocket" }
	end

	if socketState.Building ~= nil then
		return { ok = false, reason = "SocketOccupied" }
	end

	if typeof(definition.Limit) == "number" and self:_getBuildingCount(player, buildingType) >= definition.Limit then
		return { ok = false, reason = "BuildingLimitReached" }
	end

	local canAfford, resourceReason =
		self._resourceService:CanAffordBuilding(player, definition.Gold or 0, definition.Population or 0)
	if not canAfford then
		return { ok = false, reason = resourceReason }
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
		hexData = hexData,
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

function BuildService:_validateMoveRequest(player: Player, request: MoveRequest): any
	if type(request) ~= "table" then
		return { ok = false, reason = "InvalidRequest" }
	end

	if self._gameService ~= nil and self._gameService:GetPlayerState(player) ~= PlayerStates.Building then
		return { ok = false, reason = "NotBuilding" }
	end

	if typeof(request.buildingId) ~= "string" then
		return { ok = false, reason = "InvalidBuilding" }
	end

	local currentLocation = self._buildingLocations[request.buildingId]
	if currentLocation == nil or currentLocation.SocketState == nil then
		return { ok = false, reason = "MissingBuilding" }
	end

	local currentSocketState = currentLocation.SocketState :: SocketState
	if currentSocketState.Owner ~= player then
		return { ok = false, reason = "NotOwner" }
	end

	local model = currentSocketState.ModelRef
	if typeof(model) ~= "Instance" or not model:IsA("Model") or model.Parent == nil then
		return { ok = false, reason = "MissingBuildingModel" }
	end

	local buildingType = currentSocketState.Building
	local definition = if buildingType ~= nil then BuildingConfig.Buildings[buildingType] else nil
	if buildingType == nil or definition == nil then
		return { ok = false, reason = "InvalidBuilding" }
	end

	local hexPart = request.hexPart
	local socketName = request.socketName
	if typeof(hexPart) ~= "Instance" or not hexPart:IsA("BasePart") then
		return { ok = false, reason = "InvalidHex" }
	end

	if not isValidSocketName(socketName) then
		return { ok = false, reason = "InvalidSocket" }
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

	local territoryOk, territoryReason = self:_validateTerritory(player, hexData)
	if not territoryOk then
		return { ok = false, reason = territoryReason }
	end

	local socketState = hexData.Sockets[socketName]
	if socketState == nil then
		return { ok = false, reason = "InvalidSocket" }
	end

	if socketState.Building ~= nil and socketState ~= currentSocketState then
		return { ok = false, reason = "SocketOccupied" }
	end

	local socketPosition = getSocketPosition(hexData, socketName)
	if socketPosition == nil then
		return { ok = false, reason = "InvalidSocket" }
	end

	local rotation = getPlacementRotation(hexData, socketName, request.rotation, definition)
	local placementCFrame = getPlacementCFrame(socketPosition, rotation, definition)
	local testModel = cloneBuildingModel(buildingType, definition)
	if testModel == nil then
		return { ok = false, reason = "MissingBuildingModel" }
	end

	testModel:PivotTo(placementCFrame)
	if self:_modelCollides(testModel, hexData.HexPart, model) then
		testModel:Destroy()
		return { ok = false, reason = "BlockedByCollision" }
	end
	testModel:Destroy()

	return {
		ok = true,
		buildingId = request.buildingId,
		buildingType = buildingType,
		model = model,
		hp = currentSocketState.HP,
		currentSocketState = currentSocketState,
		currentSocketName = currentLocation.SocketName,
		currentHexPart = currentLocation.HexData.HexPart,
		hexData = hexData,
		hexPart = hexData.HexPart,
		socketName = socketName,
		socketState = socketState,
		rotation = rotation,
		placementCFrame = placementCFrame,
	}
end

function BuildService:_modelCollides(model: Model, placementHex: BasePart, ignoredInstance: Instance?): boolean
	local boxCFrame, boxSize = model:GetBoundingBox()
	if boxSize.Magnitude <= 0 then
		return false
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = if ignoredInstance ~= nil
		then { model, placementHex, ignoredInstance }
		else { model, placementHex }

	for _, part in Workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams) do
		if part:IsDescendantOf(model) or part == placementHex then
			continue
		end

		if self._placedFolder ~= nil and part:IsDescendantOf(self._placedFolder) then
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

function BuildService:_getResources(player: Player): ResourceState
	if self._resourceService == nil then
		return createResourceState()
	end

	return self._resourceService:GetSnapshot(player)
end

function BuildService:_getBuildingCount(player: Player, buildingType: string): number
	local counts = self._buildingCounts[player]
	return if counts ~= nil then counts[buildingType] or 0 else 0
end

function BuildService:_incrementBuildingCount(player: Player, buildingType: string)
	local counts = self._buildingCounts[player]
	if counts == nil then
		counts = {}
		self._buildingCounts[player] = counts
	end

	counts[buildingType] = (counts[buildingType] or 0) + 1
end

function BuildService:_decrementBuildingCount(player: Player, buildingType: string)
	local counts = self._buildingCounts[player]
	if counts == nil then
		return
	end

	counts[buildingType] = math.max(0, (counts[buildingType] or 0) - 1)
end

function BuildService:_validateTerritory(player: Player, hexData: HexData): (boolean, string?)
	if self._nexoService == nil then
		return false, "NoActiveNexo"
	end

	local nexoState, nexoReason = self._nexoService:GetActiveTerritoryState(player)
	if nexoState == nil then
		return false, nexoReason or "NoActiveNexo"
	end

	if hexData.State == nil then
		return false, "MissingHexState"
	end

	if hexData.State ~= nexoState then
		return false, "OutOfNexoState"
	end

	return true, nil
end

function BuildService:_destroyBuilding(buildingId: string, location)
	local socketState = location.SocketState :: SocketState
	local player = socketState.Owner
	local buildingType = socketState.Building
	local definition = if buildingType ~= nil then BuildingConfig.Buildings[buildingType] else nil
	if player == nil or buildingType == nil or definition == nil then
		self._buildingLocations[buildingId] = nil
		clearSocketState(socketState, true)
		return
	end

	self._buildingLocations[buildingId] = nil
	clearSocketState(socketState, true)
	self:_decrementBuildingCount(player, buildingType)
	self._resourceService:ApplyBuildingRemoved(player, definition.Population or 0, definition.PopulationCapBonus or 0)
	self.Client.BuildingDestroyed:FireAll({
		BuildingId = buildingId,
		OwnerUserId = player.UserId,
		BuildingType = buildingType,
	})
	self.BuildingDestroyed:Fire({
		BuildingId = buildingId,
		Owner = player,
		OwnerUserId = player.UserId,
		BuildingType = buildingType,
	})
	if location.SocketName == "Center" then
		self.CenterPathingChanged:Fire(location.HexData.HexPart)
	end
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
		State = getHexState(hexPart),
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
	table.clear(self._buildingLocations)
	table.clear(self._buildingCounts)
	table.clear(self._lastRequestAt)
end

return BuildService
