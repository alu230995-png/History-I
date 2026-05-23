local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local GridConfig = require(Shared:WaitForChild("Constants"):WaitForChild("GridConfig"))
local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local WeaponConfig = require(Shared:WaitForChild("Constants"):WaitForChild("WeaponConfig"))
local StateMachine = require(Shared:WaitForChild("Classes"):WaitForChild("StateMachine"))
local HexUtils = require(Shared:WaitForChild("Utils"):WaitForChild("HexUtils"))
local TropaCollisionGroups = require(Shared:WaitForChild("Utils"):WaitForChild("TropaCollisionGroups"))

local ManpowerController = Knit.CreateController({
	Name = "ManpowerController",
})

local MIN_FACING_MAGNITUDE = 0.001
local ZERO_VECTOR = Vector3.zero
local DEFAULT_VISUAL_MOTION = ManpowerConfig.VisualMotion

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
	if source == nil and definition.ModelFallbackPath ~= nil then
		source = resolvePath(definition.ModelFallbackPath)
	end
	return if source ~= nil and source:IsA("Model") then source else nil
end

local function getWeaponSource(weapon): Instance?
	local path = if type(weapon) == "table" then weapon.Path else nil
	if typeof(path) ~= "string" or path == "" then
		return nil
	end

	local source = resolvePath(path)
	return if source ~= nil and (source:IsA("Model") or source:IsA("Tool")) then source else nil
end

local function getWeaponPivotPart(weaponSource: Instance): BasePart?
	if weaponSource:IsA("Model") and weaponSource.PrimaryPart ~= nil then
		return weaponSource.PrimaryPart
	end

	local handle = weaponSource:FindFirstChild("Handle", true)
	if handle ~= nil and handle:IsA("BasePart") then
		return handle
	end

	return weaponSource:FindFirstChildWhichIsA("BasePart", true)
end

local function getWeaponPivotCFrame(weaponSource: Instance): CFrame?
	if weaponSource:IsA("Model") then
		return weaponSource:GetPivot()
	end

	local primaryPart = getWeaponPivotPart(weaponSource)
	if primaryPart ~= nil then
		return primaryPart.CFrame
	end

	return nil
end

local function pivotWeaponSource(weaponSource: Instance, targetPivot: CFrame)
	if weaponSource:IsA("Model") then
		weaponSource:PivotTo(targetPivot)
		return
	end

	local currentPivot = getWeaponPivotCFrame(weaponSource)
	if currentPivot == nil then
		return
	end

	local delta = targetPivot * currentPivot:Inverse()
	for _, descendant in weaponSource:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame = delta * descendant.CFrame
		end
	end
end

local function getAttachmentCFrame(instance: Instance?): CFrame?
	if instance == nil then
		return nil
	end

	if instance:IsA("Attachment") then
		return instance.WorldCFrame
	end

	if instance:IsA("BasePart") then
		return instance.CFrame
	end

	return nil
end

local function getGripOffset(weapon): CFrame
	local gripOffset = if type(weapon) == "table" then weapon.GripOffset else nil
	return if typeof(gripOffset) == "CFrame" then gripOffset else CFrame.new()
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
		CFrameLerpGain = if overrides ~= nil and typeof(overrides.CFrameLerpGain) == "number"
			then overrides.CFrameLerpGain
			else DEFAULT_VISUAL_MOTION.CFrameLerpGain,
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
	self._visualById = {}
	self._visualByNetId = {}
	self._gridByPart = {}
	self._gridByKey = {}

	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
	end))
end

function ManpowerController:KnitStart()
	self._manpowerService = Knit.GetService("ManpowerService")
	self:_mountUnitFolder()
	self:_rebuildHexCache()

	self._trove:Add(CollectionService:GetInstanceAddedSignal(GridConfig.BuildableHexTag):Connect(function(instance)
		self:_scanHex(instance)
	end))
	self._trove:Add(CollectionService:GetInstanceRemovedSignal(GridConfig.BuildableHexTag):Connect(function(instance)
		self:_removeHex(instance)
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
	self._trove:Add(RunService.Heartbeat:Connect(function()
		self:_updateVisuals(os.clock())
	end))

	local snapshot = self._manpowerService:GetUnitsSnapshot()
	if type(snapshot) == "table" and type(snapshot.Units) == "table" then
		for index = 1, #snapshot.Units do
			self:_spawnVisual(snapshot.Units[index])
		end
	end
end

function ManpowerController:_mountUnitFolder()
	local unitFolder = Instance.new("Folder")
	unitFolder.Name = ManpowerConfig.UnitFolderName
	unitFolder.Parent = Workspace
	self._unitFolder = unitFolder
	self._trove:Add(unitFolder)
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
	self:_attachWeaponVisual(model, payload.UnitType)
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
		LastVisualUpdateAt = os.clock(),
	}
	visual.Motion = self:_createVisualMotion(visual.UnitId, model:GetPivot(), getVisualMotionSettings(visual.UnitType))
	model:SetAttribute("UnitState", stateMachine:GetState())
	self._visualById[visual.UnitId] = visual
	self._visualByNetId[visual.NetId] = visual

	if payload.Segment ~= nil then
		self:_applySegmentSnapshot(visual, payload.Segment)
	end
end

function ManpowerController:_attachWeaponVisual(model: Model, unitType: string)
	local definition = ManpowerConfig.GetUnit(unitType)
	local combat = if definition ~= nil then definition.Combat else nil
	local weapon = if type(combat) == "table" then WeaponConfig.GetWeapon(combat.WeaponId) else nil
	local weaponSource = if weapon ~= nil then getWeaponSource(weapon) else nil
	if weapon == nil or weaponSource == nil then
		return
	end

	local attachTo = if typeof(weapon.AttachTo) == "string" and weapon.AttachTo ~= ""
		then weapon.AttachTo
		else "RightHand"
	local unitPart = model:FindFirstChild(attachTo, true)
	if unitPart == nil or not unitPart:IsA("BasePart") then
		warn(("[ManpowerController] Unit %s has no weapon attach part %s"):format(unitType, attachTo))
		return
	end

	local weaponModel = weaponSource:Clone()
	weaponModel.Name = `{weapon.Id}_Visual`
	for _, descendant in weaponModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = true
		end
	end
	TropaCollisionGroups.ApplyToModel(weaponModel)

	local unitAttachmentName = weapon.UnitAttachmentName
	local unitAttachment = if typeof(unitAttachmentName) == "string" and unitAttachmentName ~= ""
		then unitPart:FindFirstChild(unitAttachmentName, true)
		else nil
	local targetGripCFrame = (getAttachmentCFrame(unitAttachment) or unitPart.CFrame) * getGripOffset(weapon)
	local sourcePivot = getWeaponPivotCFrame(weaponModel)
	if sourcePivot == nil then
		weaponModel:Destroy()
		return
	end
	local weaponAttachmentName = weapon.WeaponAttachmentName
	local weaponAttachment = if typeof(weaponAttachmentName) == "string" and weaponAttachmentName ~= ""
		then weaponModel:FindFirstChild(weaponAttachmentName, true)
		else nil
	local attachmentCFrame = getAttachmentCFrame(weaponAttachment)
	local targetPivot = nil
	if attachmentCFrame ~= nil then
		targetPivot = targetGripCFrame * sourcePivot:ToObjectSpace(attachmentCFrame):Inverse()
	else
		local pivotPart = getWeaponPivotPart(weaponModel)
		targetPivot = if pivotPart ~= nil
			then targetGripCFrame * sourcePivot:ToObjectSpace(pivotPart.CFrame):Inverse()
			else targetGripCFrame
	end

	pivotWeaponSource(weaponModel, targetPivot)
	weaponModel.Parent = model
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

	TropaCollisionGroups.ApplyToModel(model)
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
	TropaCollisionGroups.ApplyToPart(proxy)

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
	return visual.Model:GetPivot()
end

function ManpowerController:_getVisualPosition(visual): Vector3
	return self:_getVisualCFrame(visual).Position
end

function ManpowerController:_followVisualMotion(visual, movement, expectedPosition: Vector3, deltaTime: number)
	local targetCFrame = getMovementCFrame(expectedPosition, movement.Facing)
	local motion = visual.Motion
	if motion == nil then
		visual.Model:PivotTo(targetCFrame)
		return
	end

	local proxy = motion.Proxy
	local settings = motion.Settings
	local proxyPosition = proxy.Position
	local expectedProxyPosition = expectedPosition + settings.ProxyOffset
	local positionError = expectedProxyPosition - proxyPosition
	if positionError.Magnitude >= settings.SnapDistance then
		self:_snapVisualMotion(visual, targetCFrame)
		proxyPosition = expectedProxyPosition
		positionError = ZERO_VECTOR
	end

	local desiredVelocity = positionError * settings.PositionGain + movement.Velocity

	local desiredSpeed = desiredVelocity.Magnitude
	local maxSpeed = math.max(movement.Speed * settings.MaxSpeedScale, settings.MinCatchupSpeed)
	if desiredSpeed > maxSpeed then
		desiredVelocity = desiredVelocity.Unit * maxSpeed
	end

	motion.LinearVelocity.VectorVelocity = desiredVelocity
	motion.AlignOrientation.CFrame = getMovementCFrame(proxyPosition, movement.Facing)

	local cframeAlpha = 1 - math.exp(-settings.CFrameLerpGain * math.max(deltaTime, 0))
	visual.Model:PivotTo(visual.Model:GetPivot():Lerp(targetCFrame, math.clamp(cframeAlpha, 0, 1)))
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
	local now = os.clock()
	visual.LastVisualUpdateAt = now
	visual.Movement = createVisualMovement(fromPosition, toPosition, duration, now - elapsed)
	self:_setVisualState(visual, ManpowerConfig.UnitStates.Moving, "SegmentSnapshot")
	self:_updateVisual(visual, now)
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
		local now = os.clock()
		movement.StartedAt = now
		visual.LastVisualUpdateAt = now
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

	local deltaTime = math.clamp(now - (visual.LastVisualUpdateAt or now), 0, 0.1)
	visual.LastVisualUpdateAt = now

	while movement ~= nil do
		local alpha = math.clamp((now - movement.StartedAt) / movement.Duration, 0, 1)
		local position = movement.From:Lerp(movement.To, alpha)
		local nextMovement = visual.MovementQueue[1]
		self:_followVisualMotion(visual, movement, position, deltaTime)

		if alpha < 1 then
			return
		end

		if nextMovement == nil then
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

	self._visualById[unitId] = nil
	self._visualByNetId[visual.NetId] = nil
	if visual.Motion ~= nil then
		visual.Motion.Proxy:Destroy()
	end
	visual.StateMachine:Destroy()
	visual.Model:Destroy()
end

function ManpowerController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
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
