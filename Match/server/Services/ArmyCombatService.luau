local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local WeaponConfig = require(Shared:WaitForChild("Constants"):WaitForChild("WeaponConfig"))
local ArmyUnitCombat = require(script.Parent.Parent:WaitForChild("Classes"):WaitForChild("ArmyUnitCombat"))

local ArmyCombatService = Knit.CreateService({
	Name = "ArmyCombatService",
	Client = {},
})

local COMBAT_STEP_SECONDS = 0.1
local MAX_HEARTBEAT_DELTA = 0.5
local ROOT_MUZZLE_SOURCE = "RootPart"
local TOOL_MUZZLE_SOURCE = "Tool"

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

local function getMuzzlePosition(muzzle: Instance): Vector3?
	if muzzle:IsA("Attachment") then
		return muzzle.WorldPosition
	end

	if muzzle:IsA("BasePart") then
		return muzzle.Position
	end

	return nil
end

local function getInstanceCFrame(instance: Instance): CFrame?
	if instance:IsA("Attachment") then
		return instance.WorldCFrame
	end

	if instance:IsA("BasePart") then
		return instance.CFrame
	end

	return nil
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

	local pivotPart = getWeaponPivotPart(weaponSource)
	return if pivotPart ~= nil then pivotPart.CFrame else nil
end

local function getWeaponMuzzle(weaponSource: Instance, muzzleName: string): Instance?
	if weaponSource:IsA("Tool") then
		local handle = weaponSource:FindFirstChild("Handle")
		if handle == nil or not handle:IsA("BasePart") then
			return nil
		end

		return handle:FindFirstChild(muzzleName)
	end

	return weaponSource:FindFirstChild(muzzleName, true)
end

local function resolveChildPath(root: Instance, path: any): Instance?
	if typeof(path) ~= "string" or path == "" then
		return nil
	end

	local current: Instance? = root
	for segment in string.gmatch(path, "[^/%.]+") do
		if current == nil then
			return nil
		end

		current = current:FindFirstChild(segment)
	end

	return current
end

local function getConfiguredWeaponMuzzle(weaponSource: Instance, weapon, muzzleName: string): Instance?
	local muzzlePath = if type(weapon) == "table" then weapon.MuzzlePath else nil
	local configuredMuzzle = resolveChildPath(weaponSource, muzzlePath)
	if configuredMuzzle ~= nil then
		return configuredMuzzle
	end

	return getWeaponMuzzle(weaponSource, muzzleName)
end

local function getConfiguredMuzzleName(combat, weapon): string?
	local weaponMuzzleName = if type(weapon) == "table" then weapon.MuzzleName else nil
	if typeof(weaponMuzzleName) == "string" and weaponMuzzleName ~= "" then
		return weaponMuzzleName
	end

	local combatMuzzleName = if type(combat) == "table" then combat.MuzzleName else nil
	return if typeof(combatMuzzleName) == "string" and combatMuzzleName ~= "" then combatMuzzleName else nil
end

local function getGripOffset(weapon): CFrame
	local gripOffset = if type(weapon) == "table" then weapon.GripOffset else nil
	return if typeof(gripOffset) == "CFrame" then gripOffset else CFrame.new()
end

function ArmyCombatService:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._combatByUnit = {}
	self._muzzleOffsetByUnitType = {}
	self._simulationAccumulator = 0
	self._manpowerService = nil
	self._projectileService = nil
	self._targetingService = nil
end

function ArmyCombatService:KnitStart()
	self._manpowerService = Knit.GetService("ManpowerService")
	self._projectileService = Knit.GetService("ProjectileService")
	self._targetingService = Knit.GetService("TargetingService")

	self._trove:Add(self._manpowerService.UnitSpawned:Connect(function(unit)
		self:_addUnit(unit)
	end))
	self._trove:Add(self._manpowerService.UnitDestroyed:Connect(function(unit)
		self:_removeUnit(unit)
	end))
	self._trove:Add(RunService.Heartbeat:Connect(function(deltaTime: number)
		self:_stepHeartbeat(deltaTime)
	end))

	for _, unit in self._manpowerService:GetCombatUnits() do
		self:_addUnit(unit)
	end
end

function ArmyCombatService:_addUnit(unit)
	if self._combatByUnit[unit] ~= nil then
		return
	end

	local definition = unit.Definition
	local combat = definition.Combat
	local weapon = if type(combat) == "table" then WeaponConfig.GetWeapon(combat.WeaponId) else nil
	if weapon == nil then
		warn(("[ArmyCombatService] Unit %s has no valid Combat.WeaponId"):format(unit.UnitType))
		return
	end

	local muzzleOffset = self:_getMuzzleOffset(unit.UnitType, definition, weapon)
	if muzzleOffset == nil then
		return
	end

	self._combatByUnit[unit] = ArmyUnitCombat.new(
		unit,
		weapon,
		muzzleOffset,
		self._manpowerService,
		self._targetingService,
		self._projectileService
	)
end

function ArmyCombatService:_removeUnit(unit)
	local combat = self._combatByUnit[unit]
	if combat == nil then
		return
	end

	self._combatByUnit[unit] = nil
	combat:Destroy()
end

function ArmyCombatService:_getMuzzleOffset(unitType: string, definition, weapon): Vector3?
	local cacheKey = `{unitType}:{weapon.Id or ""}`
	local cached = self._muzzleOffsetByUnitType[cacheKey]
	if cached ~= nil then
		return if typeof(cached) == "Vector3" then cached else nil
	end

	local offset = self:_resolveMuzzleOffset(unitType, definition, weapon)
	self._muzzleOffsetByUnitType[cacheKey] = offset or false
	return offset
end

function ArmyCombatService:_resolveWeaponMuzzleOffset(
	unitType: string,
	source: Model,
	rootPart: BasePart,
	definition,
	weapon
): Vector3?
	local weaponSource = getWeaponSource(weapon)
	if weaponSource == nil then
		return nil
	end

	local combat = definition.Combat
	local muzzleName = getConfiguredMuzzleName(combat, weapon)
	if muzzleName == nil then
		return nil
	end

	local muzzle = getConfiguredWeaponMuzzle(weaponSource, weapon, muzzleName)
	local muzzleCFrame = if muzzle ~= nil then getInstanceCFrame(muzzle) else nil
	if muzzleCFrame == nil then
		warn(
			("[ArmyCombatService] Weapon %s has no valid Handle.%s muzzle"):format(
				tostring(weapon.Id),
				tostring(muzzleName)
			)
		)
		return nil
	end

	local attachTo = if typeof(weapon.AttachTo) == "string" and weapon.AttachTo ~= ""
		then weapon.AttachTo
		else "RightHand"
	local unitAttachPart = source:FindFirstChild(attachTo, true)
	if unitAttachPart == nil or not unitAttachPart:IsA("BasePart") then
		warn(("[ArmyCombatService] Unit %s has no weapon attach part %s"):format(unitType, attachTo))
		return nil
	end

	local unitAttachmentName = weapon.UnitAttachmentName
	local unitAttachment = if typeof(unitAttachmentName) == "string" and unitAttachmentName ~= ""
		then unitAttachPart:FindFirstChild(unitAttachmentName, true)
		else nil
	local gripCFrame = if unitAttachment ~= nil then getInstanceCFrame(unitAttachment) else unitAttachPart.CFrame
	if gripCFrame == nil then
		return nil
	end
	gripCFrame *= getGripOffset(weapon)

	local weaponPivot = getWeaponPivotCFrame(weaponSource)
	if weaponPivot == nil then
		warn(("[ArmyCombatService] Weapon %s has no valid pivot part"):format(tostring(weapon.Id)))
		return nil
	end
	local weaponAttachmentName = weapon.WeaponAttachmentName
	local weaponAttachment = if typeof(weaponAttachmentName) == "string" and weaponAttachmentName ~= ""
		then weaponSource:FindFirstChild(weaponAttachmentName, true)
		else nil
	local weaponPivotCFrame = nil
	local weaponAttachmentCFrame = if weaponAttachment ~= nil then getInstanceCFrame(weaponAttachment) else nil
	if weaponAttachmentCFrame ~= nil then
		weaponPivotCFrame = gripCFrame * weaponPivot:ToObjectSpace(weaponAttachmentCFrame):Inverse()
	else
		local pivotPart = getWeaponPivotPart(weaponSource)
		if pivotPart ~= nil then
			weaponPivotCFrame = gripCFrame * weaponPivot:ToObjectSpace(pivotPart.CFrame):Inverse()
		else
			weaponPivotCFrame = gripCFrame
		end
	end

	local muzzleRelativeToPivot = weaponPivot:ToObjectSpace(muzzleCFrame)
	local muzzleWorldCFrame = weaponPivotCFrame * muzzleRelativeToPivot
	return rootPart.CFrame:PointToObjectSpace(muzzleWorldCFrame.Position)
end

function ArmyCombatService:_resolveLegacyMuzzleOffset(
	unitType: string,
	source: Model,
	rootPart: BasePart,
	definition
): Vector3?
	local combat = definition.Combat
	local muzzleName = combat.MuzzleName
	local muzzle = nil
	if combat.MuzzleSource == TOOL_MUZZLE_SOURCE then
		local tool = source:FindFirstChildWhichIsA("Tool", true)
		if tool == nil then
			return nil
		end

		muzzle = tool:FindFirstChild(muzzleName, true)
	elseif combat.MuzzleSource == ROOT_MUZZLE_SOURCE then
		muzzle = rootPart:FindFirstChild(muzzleName, true)
	else
		warn(("[ArmyCombatService] Unit %s has invalid Combat.MuzzleSource"):format(unitType))
		return nil
	end

	if muzzle == nil then
		return nil
	end

	local muzzlePosition = getMuzzlePosition(muzzle)
	if muzzlePosition == nil then
		warn(
			("[ArmyCombatService] Unit %s muzzle %s must be an Attachment or BasePart"):format(
				unitType,
				muzzle:GetFullName()
			)
		)
		return nil
	end

	return rootPart.CFrame:PointToObjectSpace(muzzlePosition)
end

function ArmyCombatService:_resolveMuzzleOffset(unitType: string, definition, weapon): Vector3?
	local source = resolvePath(definition.Path)
	if source == nil or not source:IsA("Model") then
		warn(
			("[ArmyCombatService] Missing model path for %s combat muzzle: %s"):format(
				unitType,
				tostring(definition.Path)
			)
		)
		return nil
	end

	local rootPart = source:FindFirstChild(definition.RootPartName or "RootPart", true)
	if rootPart == nil or not rootPart:IsA("BasePart") then
		warn(
			("[ArmyCombatService] Unit %s combat root %s is not a BasePart"):format(
				unitType,
				tostring(definition.RootPartName)
			)
		)
		return nil
	end

	local weaponOffset = self:_resolveWeaponMuzzleOffset(unitType, source, rootPart, definition, weapon)
	if weaponOffset ~= nil then
		return weaponOffset
	end

	local legacyOffset = self:_resolveLegacyMuzzleOffset(unitType, source, rootPart, definition)
	if legacyOffset ~= nil then
		return legacyOffset
	end

	warn(("[ArmyCombatService] Unit %s has no weapon or legacy muzzle; using root origin"):format(unitType))
	return Vector3.zero
end

function ArmyCombatService:_stepHeartbeat(deltaTime: number)
	if self._destroyed then
		return
	end

	self._simulationAccumulator += math.min(deltaTime, MAX_HEARTBEAT_DELTA)
	while self._simulationAccumulator >= COMBAT_STEP_SECONDS do
		self._simulationAccumulator -= COMBAT_STEP_SECONDS
		self:_stepCombat(os.clock())
	end
end

function ArmyCombatService:_stepCombat(now: number)
	for unit, combat in self._combatByUnit do
		if self._manpowerService:IsCombatUnitActive(unit) then
			combat:Step(now)
		else
			self:_removeUnit(unit)
		end
	end
end

function ArmyCombatService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	for unit, combat in self._combatByUnit do
		self._combatByUnit[unit] = nil
		combat:Destroy()
	end
	self._trove:Destroy()
	table.clear(self._muzzleOffsetByUnitType)
end

return ArmyCombatService
