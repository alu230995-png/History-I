local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))
local Trove = require(Packages:WaitForChild("Trove"))

local GridConfig = require(Shared:WaitForChild("Constants"):WaitForChild("GridConfig"))
local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local PlayerStates = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStates"))
local StateMachine = require(Shared:WaitForChild("Classes"):WaitForChild("StateMachine"))
local HexUtils = require(Shared:WaitForChild("Utils"):WaitForChild("HexUtils"))

local UnitSelectionBar =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("UnitSelectionBar"):WaitForChild("index"))
local WorldInput = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("WorldInput"))

local ManpowerController = Knit.CreateController({
	Name = "ManpowerController",
})

local LOCAL_PLAYER = Players.LocalPlayer
local MAX_RAY_DISTANCE = 500
local MIN_FACING_MAGNITUDE = 0.001
local ZERO_VECTOR = Vector3.zero
local DEFAULT_VISUAL_MOTION = ManpowerConfig.VisualMotion
local MOTION_COLLISION_GROUP = "ManpowerMotion"
local motionCollisionGroupReady = false

local function findUnitModel(instance: Instance?, unitFolder: Folder?): Model?
	local current = instance

	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("UnitId") ~= nil then
			if unitFolder == nil or current:IsDescendantOf(unitFolder) then
				return current
			end
		end

		current = current.Parent
	end

	return nil
end

local function findHexPart(instance: Instance?): BasePart?
	local current = instance

	while current ~= nil and current ~= Workspace do
		if current:IsA("BasePart") and CollectionService:HasTag(current, GridConfig.BuildableHexTag) then
			return current
		end

		current = current.Parent
	end

	return nil
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

local function getUnitSource(unitType: string): Model?
	local definition = ManpowerConfig.GetUnit(unitType)
	if definition == nil then
		return nil
	end

	local source = resolvePath(definition.Path)
	return if source ~= nil and source:IsA("Model") then source else nil
end

local function getRootPart(model: Model, unitType: string): BasePart?
	local definition = ManpowerConfig.GetUnit(unitType)
	if definition ~= nil then
		local root = model:FindFirstChild(definition.RootPartName or "RootPart", true)
		if root ~= nil and root:IsA("BasePart") then
			return root
		end
	end

	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function configureLinearVelocityForce(linearVelocity: LinearVelocity, maxAxesForce: Vector3)
	local configuredForceLimits = pcall(function()
		linearVelocity.ForceLimitsEnabled = true
		linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		linearVelocity.MaxAxesForce = maxAxesForce
	end)

	if not configuredForceLimits then
		pcall(function()
			linearVelocity.MaxForce = math.max(maxAxesForce.X, maxAxesForce.Y, maxAxesForce.Z)
		end)
	end
end

local function configureMotionCollisionGroup(proxy: BasePart)
	if not motionCollisionGroupReady then
		motionCollisionGroupReady = true
		pcall(function()
			PhysicsService:RegisterCollisionGroup(MOTION_COLLISION_GROUP)
		end)
		pcall(function()
			PhysicsService:CollisionGroupSetCollidable(MOTION_COLLISION_GROUP, MOTION_COLLISION_GROUP, false)
		end)
	end

	pcall(function()
		proxy.CollisionGroup = MOTION_COLLISION_GROUP
	end)
end

local function getVisualMotionSettings(unitType: string)
	local definition = ManpowerConfig.GetUnit(unitType)
	local overrides = if definition ~= nil and type(definition.VisualMotion) == "table"
		then definition.VisualMotion
		else nil

	return {
		ProxySize = if overrides ~= nil and typeof(overrides.ProxySize) == "Vector3"
			then overrides.ProxySize
			else DEFAULT_VISUAL_MOTION.ProxySize,
		ProxyOffset = Vector3.new(
			0,
			if overrides ~= nil and typeof(overrides.ProxyGroundClearance) == "number"
				then overrides.ProxyGroundClearance
				else DEFAULT_VISUAL_MOTION.ProxyGroundClearance,
			0
		),
		ProxyFriction = DEFAULT_VISUAL_MOTION.ProxyFriction,
		MaxAxesForce = DEFAULT_VISUAL_MOTION.MaxAxesForce,
		MaxTorque = DEFAULT_VISUAL_MOTION.MaxTorque,
		ArrivalRadius = DEFAULT_VISUAL_MOTION.ArrivalRadius,
		SnapDistance = DEFAULT_VISUAL_MOTION.SnapDistance,
		MinCatchupSpeed = DEFAULT_VISUAL_MOTION.MinCatchupSpeed,
		PositionGain = if overrides ~= nil and typeof(overrides.PositionGain) == "number"
			then overrides.PositionGain
			else DEFAULT_VISUAL_MOTION.PositionGain,
		MaxSpeedScale = if overrides ~= nil and typeof(overrides.MaxSpeedScale) == "number"
			then overrides.MaxSpeedScale
			else DEFAULT_VISUAL_MOTION.MaxSpeedScale,
		TurnResponsiveness = if overrides ~= nil and typeof(overrides.TurnResponsiveness) == "number"
			then overrides.TurnResponsiveness
			else DEFAULT_VISUAL_MOTION.TurnResponsiveness,
		MaxAngularVelocity = if overrides ~= nil and typeof(overrides.MaxAngularVelocity) == "number"
			then overrides.MaxAngularVelocity
			else DEFAULT_VISUAL_MOTION.MaxAngularVelocity,
	}
end

local function moveCFrameToPosition(cframe: CFrame, position: Vector3): CFrame
	return cframe - cframe.Position + position
end

local function getMovementCFrame(position: Vector3, facing: Vector3): CFrame
	if facing.Magnitude > MIN_FACING_MAGNITUDE then
		return CFrame.lookAt(position, position + facing)
	end

	return CFrame.new(position)
end

local function createVisualMovement(fromPosition: Vector3, toPosition: Vector3, duration: number, startedAt: number)
	local delta = toPosition - fromPosition
	local facing = Vector3.new(delta.X, 0, delta.Z)

	return {
		From = fromPosition,
		To = toPosition,
		StartedAt = startedAt,
		Duration = duration,
		Velocity = delta / duration,
		Speed = delta.Magnitude / duration,
		Facing = facing,
	}
end

function ManpowerController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._camera = Workspace.CurrentCamera
	self._unitFolder = nil
	self._manpowerService = nil
	self._gameService = nil
	self._isBuildingMode = false
	self._selectedById = {}
	self._selectionOrder = {}
	self._highlights = {}
	self._visualById = {}
	self._visualByNetId = {}
	self._gridByPart = {}
	self._gridByKey = {}
	self._root = nil
	self._screenGui = nil

	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
	end))
end

function ManpowerController:KnitStart()
	self._manpowerService = Knit.GetService("ManpowerService")
	self._gameService = Knit.GetService("GameService")
	self:_mountUnitFolder()
	self:_rebuildHexCache()
	self:_mountUi()

	self._trove:Add(CollectionService:GetInstanceAddedSignal(GridConfig.BuildableHexTag):Connect(function(instance)
		self:_scanHex(instance)
	end))
	self._trove:Add(CollectionService:GetInstanceRemovedSignal(GridConfig.BuildableHexTag):Connect(function(instance)
		self:_removeHex(instance)
	end))
	self._trove:Add(self._gameService.PlayerStateChanged:Connect(function(_oldState: string, newState: string)
		self._isBuildingMode = newState == PlayerStates.Building
	end))
	self._trove:Add(self._manpowerService.UnitSpawned:Connect(function(payload)
		self:_spawnVisual(payload)
	end))
	self._trove:Add(self._manpowerService.BatchWaypoints:Connect(function(batch)
		self:_applyWaypointBatch(batch)
	end))
	self._trove:Add(self._manpowerService.UnitDestroyed:Connect(function(payload)
		if type(payload) == "table" and typeof(payload.UnitId) == "string" then
			self:_destroyVisual(payload.UnitId)
		end
	end))
	self._trove:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent or self._isBuildingMode then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_activateAtPointer(UserInputService:GetMouseLocation())
		elseif input.UserInputType == Enum.UserInputType.Touch then
			self:_activateAtPointer(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.KeyCode == Enum.KeyCode.Escape then
			self:_clearSelection()
		end
	end))
	self._trove:Add(RunService.Heartbeat:Connect(function()
		self:_updateVisuals(os.clock())
	end))

	local snapshot = self._manpowerService:GetUnitsSnapshot()
	if type(snapshot) == "table" and type(snapshot.Units) == "table" then
		for index = 1, #snapshot.Units do
			self:_spawnVisual(snapshot.Units[index])
		end
	end

	local state = self._gameService:GetPlayerState()
	self._isBuildingMode = state == PlayerStates.Building
end

function ManpowerController:_mountUnitFolder()
	local unitFolder = Instance.new("Folder")
	unitFolder.Name = ManpowerConfig.UnitFolderName
	unitFolder.Parent = Workspace
	self._unitFolder = unitFolder
	self._trove:Add(unitFolder)
	self._trove:Add(unitFolder.ChildRemoved:Connect(function(child)
		local unitId = child:GetAttribute("UnitId")
		if typeof(unitId) == "string" then
			self:_deselectUnit(unitId)
		end
	end))
end

function ManpowerController:_mountUi()
	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "UnitSelectionGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 34
	screenGui.Parent = playerGui
	self._screenGui = screenGui
	self._trove:Add(screenGui)

	local root = ReactRoblox.createRoot(screenGui)
	self._root = root
	self._trove:Add(function()
		root:unmount()
	end)

	self:_render()
end

function ManpowerController:_rebuildHexCache()
	table.clear(self._gridByPart)
	table.clear(self._gridByKey)

	for _, taggedInstance in CollectionService:GetTagged(GridConfig.BuildableHexTag) do
		self:_scanHex(taggedInstance)
	end
end

function ManpowerController:_scanHex(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	local coord = HexUtils.getHexCoordFromPart(instance, GridConfig)
	local key = HexUtils.toKey(coord.q, coord.r)
	local record = {
		Key = key,
		Part = instance,
		Center = HexUtils.getHexTopCenterFromPart(instance),
	}
	self._gridByPart[instance] = record
	self._gridByKey[key] = record
end

function ManpowerController:_removeHex(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	local record = self._gridByPart[instance]
	if record == nil then
		return
	end

	self._gridByPart[instance] = nil
	if self._gridByKey[record.Key] == record then
		self._gridByKey[record.Key] = nil
	end
end

function ManpowerController:_spawnVisual(payload)
	if
		type(payload) ~= "table"
		or typeof(payload.UnitId) ~= "string"
		or typeof(payload.NetId) ~= "number"
		or typeof(payload.UnitType) ~= "string"
		or typeof(payload.OwnerUserId) ~= "number"
		or typeof(payload.HexKey) ~= "string"
	then
		return
	end

	local existing = self._visualById[payload.UnitId]
	if existing ~= nil then
		if payload.Segment ~= nil then
			self:_applySegmentSnapshot(existing, payload.Segment)
		end
		return
	end

	local source = getUnitSource(payload.UnitType)
	if source == nil then
		warn(("[ManpowerController] Missing visual source for %s"):format(payload.UnitType))
		return
	end

	local model = source:Clone()
	local root = getRootPart(model, payload.UnitType)
	if root == nil then
		warn(("[ManpowerController] Unit visual %s has no root BasePart"):format(payload.UnitType))
		model:Destroy()
		return
	end

	self:_prepareVisualModel(model, root, payload)
	local slotIndex = if typeof(payload.SlotIndex) == "number" then payload.SlotIndex else 1
	local position = self:_getHexSlotPosition(payload.HexKey, slotIndex)
	if position == nil then
		model:Destroy()
		return
	end

	model:PivotTo(CFrame.new(position))
	model.Parent = self._unitFolder

	local initialState = if typeof(payload.State) == "string" then payload.State else ManpowerConfig.UnitStates.Idle
	local stateMachine = StateMachine.new(initialState, ManpowerConfig.UnitStateTransitions)
	local visual = {
		NetId = payload.NetId,
		UnitId = payload.UnitId,
		UnitType = payload.UnitType,
		OwnerUserId = payload.OwnerUserId,
		Model = model,
		Root = root,
		Movement = nil,
		MovementQueue = {},
		StateMachine = stateMachine,
		SlotIndex = slotIndex,
	}
	visual.Motion = self:_createVisualMotion(visual.UnitId, model:GetPivot(), getVisualMotionSettings(visual.UnitType))
	model:SetAttribute("UnitState", stateMachine:GetState())
	self._visualById[visual.UnitId] = visual
	self._visualByNetId[visual.NetId] = visual

	if payload.Segment ~= nil then
		self:_applySegmentSnapshot(visual, payload.Segment)
	end
end

function ManpowerController:_prepareVisualModel(model: Model, root: BasePart, payload)
	model.Name = payload.UnitId
	model:SetAttribute("UnitId", payload.UnitId)
	model:SetAttribute("UnitType", payload.UnitType)
	model:SetAttribute("OwnerUserId", payload.OwnerUserId)
	model:SetAttribute("UnitNetId", payload.NetId)
	model.PrimaryPart = root

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = true
		elseif descendant:IsA("Humanoid") then
			descendant.AutoRotate = false
			descendant:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			descendant:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
			descendant:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			descendant:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		end
	end
end

function ManpowerController:_createVisualMotion(unitId: string, visualCFrame: CFrame, settings)
	local proxy = Instance.new("Part")
	proxy.Name = `{unitId}_MotionProxy`
	proxy.Shape = Enum.PartType.Ball
	proxy.Size = settings.ProxySize
	proxy.CFrame = visualCFrame + settings.ProxyOffset
	proxy.Transparency = 1
	proxy.Anchored = false
	proxy.Massless = false
	proxy.CanCollide = true
	proxy.CanTouch = false
	proxy.CanQuery = false
	proxy.CustomPhysicalProperties = PhysicalProperties.new(1, settings.ProxyFriction, 0, 1, 1)
	configureMotionCollisionGroup(proxy)

	local attachment = Instance.new("Attachment")
	attachment.Name = "MotionAttachment"
	attachment.Parent = proxy

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "MotionLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VectorVelocity = ZERO_VECTOR
	configureLinearVelocityForce(linearVelocity, settings.MaxAxesForce)
	linearVelocity.Parent = proxy

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "MotionAlignOrientation"
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.CFrame = visualCFrame
	alignOrientation.MaxTorque = settings.MaxTorque
	alignOrientation.MaxAngularVelocity = settings.MaxAngularVelocity
	alignOrientation.Responsiveness = settings.TurnResponsiveness
	alignOrientation.Parent = proxy

	proxy.Parent = self._unitFolder

	return {
		Proxy = proxy,
		LinearVelocity = linearVelocity,
		AlignOrientation = alignOrientation,
		Settings = settings,
	}
end

function ManpowerController:_snapVisualMotion(visual, targetCFrame: CFrame)
	local motion = visual.Motion
	if motion ~= nil then
		motion.Proxy.CFrame = targetCFrame + motion.Settings.ProxyOffset
		motion.Proxy.AssemblyLinearVelocity = ZERO_VECTOR
		motion.Proxy.AssemblyAngularVelocity = ZERO_VECTOR
		motion.LinearVelocity.VectorVelocity = ZERO_VECTOR
		motion.AlignOrientation.CFrame = targetCFrame
	end

	visual.Model:PivotTo(targetCFrame)
end

function ManpowerController:_getVisualCFrame(visual): CFrame
	local motion = visual.Motion
	if motion ~= nil then
		return motion.Proxy.CFrame - motion.Settings.ProxyOffset
	end

	return visual.Model:GetPivot()
end

function ManpowerController:_getVisualPosition(visual): Vector3
	return self:_getVisualCFrame(visual).Position
end

function ManpowerController:_followVisualMotion(visual, movement, expectedPosition: Vector3, settling: boolean)
	local motion = visual.Motion
	if motion == nil then
		visual.Model:PivotTo(getMovementCFrame(expectedPosition, movement.Facing))
		return
	end

	local proxy = motion.Proxy
	local settings = motion.Settings
	local proxyPosition = proxy.Position
	local expectedProxyPosition = expectedPosition + settings.ProxyOffset
	local positionError = expectedProxyPosition - proxyPosition
	if positionError.Magnitude >= settings.SnapDistance then
		self:_snapVisualMotion(visual, getMovementCFrame(expectedPosition, movement.Facing))
		proxyPosition = expectedProxyPosition
		positionError = ZERO_VECTOR
	end

	local desiredVelocity = positionError * settings.PositionGain
	if not settling then
		desiredVelocity += movement.Velocity
	end

	local desiredSpeed = desiredVelocity.Magnitude
	local maxSpeed = math.max(movement.Speed * settings.MaxSpeedScale, settings.MinCatchupSpeed)
	if desiredSpeed > maxSpeed then
		desiredVelocity = desiredVelocity.Unit * maxSpeed
	end

	motion.LinearVelocity.VectorVelocity = desiredVelocity
	motion.AlignOrientation.CFrame = getMovementCFrame(proxyPosition, movement.Facing)
	visual.Model:PivotTo(self:_getVisualCFrame(visual))
end

function ManpowerController:_applyWaypointBatch(batch)
	if type(batch) ~= "table" then
		return
	end

	for index = 1, #batch do
		local waypoint = batch[index]
		if type(waypoint) ~= "table" then
			continue
		end

		local netId = waypoint[1]
		local visual = if typeof(netId) == "number" then self._visualByNetId[netId] else nil
		if visual ~= nil then
			self:_applyWaypoint(visual, waypoint)
		end
	end
end

function ManpowerController:_applySegmentSnapshot(visual, segment)
	if
		type(segment) ~= "table"
		or typeof(segment[1]) ~= "string"
		or typeof(segment[2]) ~= "string"
		or typeof(segment[3]) ~= "number"
		or typeof(segment[4]) ~= "number"
	then
		return
	end

	local duration = math.max(segment[4], 0.001)
	local elapsed = if typeof(segment[5]) == "number" then math.clamp(segment[5], 0, duration) else 0
	local fromPosition = self:_getHexSlotPosition(segment[1], visual.SlotIndex)
	local toPosition = self:_getHexSlotPosition(segment[2], segment[3])
	if fromPosition == nil or toPosition == nil then
		return
	end

	visual.SlotIndex = segment[3]
	table.clear(visual.MovementQueue)
	visual.Movement = createVisualMovement(fromPosition, toPosition, duration, os.clock() - elapsed)
	self:_setVisualState(visual, ManpowerConfig.UnitStates.Moving, "SegmentSnapshot")
	self:_updateVisual(visual, os.clock())
end

function ManpowerController:_applyWaypoint(visual, waypoint)
	if
		typeof(waypoint[2]) ~= "string"
		or typeof(waypoint[3]) ~= "string"
		or typeof(waypoint[4]) ~= "number"
		or typeof(waypoint[5]) ~= "number"
	then
		return
	end

	local currentPosition = self:_getVisualPosition(visual)
	local toPosition = self:_getHexSlotPosition(waypoint[3], waypoint[4])
	if toPosition == nil then
		return
	end

	if waypoint[2] == waypoint[3] then
		table.clear(visual.MovementQueue)
		visual.Movement = nil
		self:_snapVisualMotion(visual, moveCFrameToPosition(self:_getVisualCFrame(visual), toPosition))
		self:_setVisualState(visual, ManpowerConfig.UnitStates.Idle, "WaypointCorrection")
		return
	end

	local fromPosition = currentPosition
	local lastQueued = visual.MovementQueue[#visual.MovementQueue]
	if lastQueued ~= nil then
		fromPosition = lastQueued.To
	elseif visual.Movement ~= nil then
		fromPosition = visual.Movement.To
	end

	visual.SlotIndex = waypoint[4]
	local movement = createVisualMovement(fromPosition, toPosition, math.max(waypoint[5], 0.001), 0)
	if visual.Movement == nil then
		movement.StartedAt = os.clock()
		visual.Movement = movement
	else
		table.insert(visual.MovementQueue, movement)
	end

	self:_setVisualState(visual, ManpowerConfig.UnitStates.Moving, "Waypoint")
end

function ManpowerController:_updateVisuals(now: number)
	for _, visual in self._visualById do
		if visual.Movement ~= nil then
			self:_updateVisual(visual, now)
		end
	end
end

function ManpowerController:_updateVisual(visual, now: number)
	local movement = visual.Movement
	if movement == nil then
		return
	end

	while movement ~= nil do
		local alpha = math.clamp((now - movement.StartedAt) / movement.Duration, 0, 1)
		local position = movement.From:Lerp(movement.To, alpha)
		local nextMovement = visual.MovementQueue[1]
		local isSettling = alpha >= 1 and nextMovement == nil
		self:_followVisualMotion(visual, movement, position, isSettling)

		if alpha < 1 then
			return
		end

		if nextMovement == nil then
			local motion = visual.Motion
			if motion ~= nil and (motion.Proxy.Position - movement.To).Magnitude > motion.Settings.ArrivalRadius then
				return
			end

			self:_snapVisualMotion(visual, getMovementCFrame(movement.To, movement.Facing))
			visual.Movement = nil
			self:_setVisualState(visual, ManpowerConfig.UnitStates.Idle, "RouteFinished")
			return
		end

		table.remove(visual.MovementQueue, 1)
		local overflowSeconds = math.max(0, now - (movement.StartedAt + movement.Duration))
		nextMovement.StartedAt = now - math.min(overflowSeconds, nextMovement.Duration)
		visual.Movement = nextMovement
		movement = nextMovement
	end
end

function ManpowerController:_setVisualState(visual, nextState: string, reason: string)
	local ok = visual.StateMachine:TransitionTo(nextState, {
		Reason = reason,
	})
	if ok then
		visual.Model:SetAttribute("UnitState", visual.StateMachine:GetState())
	end
end

function ManpowerController:_getHexSlotPosition(hexKey: string, slotIndex: number): Vector3?
	local hexRecord = self._gridByKey[hexKey]
	if hexRecord == nil then
		return nil
	end

	return hexRecord.Center + self:_getSlotOffset(slotIndex)
end

function ManpowerController:_getSlotOffset(slotIndex: number): Vector3
	local configuredOffset = ManpowerConfig.VisualSlotOffsets[slotIndex]
	if configuredOffset ~= nil then
		return configuredOffset
	end

	local angle = math.rad(((slotIndex - 1) % 6) * 60)
	return Vector3.new(math.cos(angle) * 1.35, 0, math.sin(angle) * 1.35)
end

function ManpowerController:_destroyVisual(unitId: string)
	local visual = self._visualById[unitId]
	if visual == nil then
		return
	end

	self:_deselectUnit(unitId)
	self._visualById[unitId] = nil
	self._visualByNetId[visual.NetId] = nil
	if visual.Motion ~= nil then
		visual.Motion.Proxy:Destroy()
	end
	visual.StateMachine:Destroy()
	visual.Model:Destroy()
end

function ManpowerController:_activateAtPointer(pointerPosition: Vector2)
	if self._camera == nil or self:_isPointerOverUi(pointerPosition) then
		return
	end

	local ray = self._camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE)
	if result == nil then
		return
	end

	local unitModel = findUnitModel(result.Instance, self._unitFolder)
	if unitModel ~= nil then
		self:_toggleUnit(unitModel)
		return
	end

	if #self._selectionOrder <= 0 then
		return
	end

	local hexPart = findHexPart(result.Instance)
	if hexPart ~= nil then
		self:_requestMove(hexPart)
	end
end

function ManpowerController:_isPointerOverUi(pointerPosition: Vector2): boolean
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		return false
	end

	return WorldInput.IsPointerBlocked(playerGui, pointerPosition)
end

function ManpowerController:_toggleUnit(model: Model)
	if model:GetAttribute("OwnerUserId") ~= LOCAL_PLAYER.UserId then
		return
	end

	local unitId = model:GetAttribute("UnitId")
	if typeof(unitId) ~= "string" then
		return
	end

	if self._selectedById[unitId] ~= nil then
		self:_deselectUnit(unitId)
		return
	end

	self._selectedById[unitId] = model
	table.insert(self._selectionOrder, unitId)
	self:_ensureHighlight(unitId, model)
	self:_render()
end

function ManpowerController:_ensureHighlight(unitId: string, model: Model)
	if self._highlights[unitId] ~= nil then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = `SelectedUnit_{unitId}`
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.78
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0.02
	highlight.Parent = Workspace
	self._highlights[unitId] = highlight
	self._trove:Add(highlight)
end

function ManpowerController:_deselectUnit(unitId: string)
	if self._selectedById[unitId] == nil then
		return
	end

	self._selectedById[unitId] = nil
	for index = #self._selectionOrder, 1, -1 do
		if self._selectionOrder[index] == unitId then
			table.remove(self._selectionOrder, index)
			break
		end
	end

	local highlight = self._highlights[unitId]
	if highlight ~= nil then
		highlight:Destroy()
	end
	self._highlights[unitId] = nil
	self:_render()
end

function ManpowerController:_clearSelection()
	for index = #self._selectionOrder, 1, -1 do
		self:_deselectUnit(self._selectionOrder[index])
	end
end

function ManpowerController:_requestMove(hexPart: BasePart)
	if self._manpowerService == nil then
		return
	end

	local unitIds = table.create(#self._selectionOrder)
	for index = 1, #self._selectionOrder do
		unitIds[index] = self._selectionOrder[index]
	end

	self._manpowerService:RequestMoveUnits({
		unitIds = unitIds,
		destinationHex = hexPart,
	})
end

function ManpowerController:_render()
	if self._root == nil then
		return
	end

	local units = table.create(#self._selectionOrder)
	for index = 1, #self._selectionOrder do
		local unitId = self._selectionOrder[index]
		local visual = self._visualById[unitId]
		if visual ~= nil then
			units[index] = {
				UnitId = unitId,
				UnitType = visual.UnitType,
			}
		end
	end

	self._root:render(React.createElement(UnitSelectionBar, {
		units = units,
		onDeselect = function(unitId: string)
			self:_deselectUnit(unitId)
		end,
	}))
end

function ManpowerController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self:_clearSelection()
	for unitId in self._visualById do
		self:_destroyVisual(unitId)
	end
	self._trove:Destroy()
	table.clear(self._gridByPart)
	table.clear(self._gridByKey)
	table.clear(self._visualById)
	table.clear(self._visualByNetId)
end

return ManpowerController
