local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local WeaponConfig = require(Shared:WaitForChild("Constants"):WaitForChild("WeaponConfig"))
local ArmyUnitCombat =
	require(script.Parent.Parent:WaitForChild("Classes"):WaitForChild("ArmyUnitCombat"))

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

	local muzzleOffset = self:_getMuzzleOffset(unit.UnitType, definition)
	if muzzleOffset == nil then
		return
	end

	self._combatByUnit[unit] =
		ArmyUnitCombat.new(unit, weapon, muzzleOffset, self._manpowerService, self._targetingService, self._projectileService)
end

function ArmyCombatService:_removeUnit(unit)
	local combat = self._combatByUnit[unit]
	if combat == nil then
		return
	end

	self._combatByUnit[unit] = nil
	combat:Destroy()
end

function ArmyCombatService:_getMuzzleOffset(unitType: string, definition): Vector3?
	local cached = self._muzzleOffsetByUnitType[unitType]
	if cached ~= nil then
		return if typeof(cached) == "Vector3" then cached else nil
	end

	local offset = self:_resolveMuzzleOffset(unitType, definition)
	self._muzzleOffsetByUnitType[unitType] = offset or false
	return offset
end

function ArmyCombatService:_resolveMuzzleOffset(unitType: string, definition): Vector3?
	local source = resolvePath(definition.Path)
	if source == nil or not source:IsA("Model") then
		warn(("[ArmyCombatService] Missing model path for %s combat muzzle: %s"):format(unitType, tostring(definition.Path)))
		return nil
	end

	local rootPart = source:FindFirstChild(definition.RootPartName or "RootPart", true)
	if rootPart == nil or not rootPart:IsA("BasePart") then
		warn(("[ArmyCombatService] Unit %s combat root %s is not a BasePart"):format(
			unitType,
			tostring(definition.RootPartName)
		))
		return nil
	end

	local combat = definition.Combat
	local muzzleName = combat.MuzzleName
	local muzzle = nil
	if combat.MuzzleSource == TOOL_MUZZLE_SOURCE then
		local tool = source:FindFirstChildWhichIsA("Tool", true)
		if tool == nil then
			warn(("[ArmyCombatService] Unit %s combat source has no Tool"):format(unitType))
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
		warn(("[ArmyCombatService] Unit %s combat source has no %s"):format(unitType, tostring(muzzleName)))
		return nil
	end

	local muzzlePosition = getMuzzlePosition(muzzle)
	if muzzlePosition == nil then
		warn(("[ArmyCombatService] Unit %s muzzle %s must be an Attachment or BasePart"):format(
			unitType,
			muzzle:GetFullName()
		))
		return nil
	end

	return rootPart.CFrame:PointToObjectSpace(muzzlePosition)
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
