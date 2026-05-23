local ArmyUnitCombat = {}
ArmyUnitCombat.__index = ArmyUnitCombat

local MIN_AIM_DISTANCE = 0.001

local function getTargetPriorityRank(weapon, target): number
	local priority = if type(weapon) == "table" then weapon.TargetPriority else nil
	if type(priority) ~= "table" or target == nil then
		return 1
	end

	for index = 1, #priority do
		if priority[index] == target.Kind then
			return index
		end
	end

	return math.huge
end

function ArmyUnitCombat.new(unit, weapon, muzzleOffset: Vector3, manpowerService, targetingService, projectileService)
	local self = setmetatable({}, ArmyUnitCombat)

	self._unit = unit
	self._weapon = weapon
	self._muzzleOffset = muzzleOffset
	self._manpowerService = manpowerService
	self._targetingService = targetingService
	self._projectileService = projectileService
	self._target = nil
	self._nextScanAt = 0
	self._nextShotAt = 0

	local combat = unit.Definition.Combat
	self._scanInterval = if type(combat) == "table" and typeof(combat.TargetScanIntervalSeconds) == "number"
		then math.max(combat.TargetScanIntervalSeconds, 0.05)
		else 0.25

	return self
end

function ArmyUnitCombat:Step(now: number)
	local unit = self._unit
	local position = self._manpowerService:GetUnitCombatPosition(unit, now)
	if position == nil then
		self._target = nil
		return
	end

	local target = self._target
	local targetPosition = nil
	if target ~= nil then
		targetPosition =
			self._targetingService:ValidateTarget(target, unit.Owner.UserId, unit.Id, position, self._weapon.Range, now)
		if targetPosition == nil then
			target = nil
			self._target = nil
		end
	end

	if now >= self._nextScanAt then
		self._nextScanAt = now + self._scanInterval
		local acquiredTarget, acquiredPosition = self._targetingService:AcquireTarget(
			unit.Owner.UserId,
			unit.Id,
			position,
			self._weapon.Range,
			now,
			self._weapon.TargetPriority
		)
		if acquiredTarget ~= nil then
			local currentRank = getTargetPriorityRank(self._weapon, target)
			local acquiredRank = getTargetPriorityRank(self._weapon, acquiredTarget)
			if target == nil or acquiredRank <= currentRank then
				target = acquiredTarget
				targetPosition = acquiredPosition
				self._target = acquiredTarget
			end
		end
	end

	if target == nil or targetPosition == nil or now < self._nextShotAt then
		return
	end

	local aimDelta = targetPosition - position
	if aimDelta.Magnitude <= MIN_AIM_DISTANCE then
		return
	end

	local aimCFrame = CFrame.lookAt(position, targetPosition)
	local origin = aimCFrame:PointToWorldSpace(self._muzzleOffset)
	local shotDelta = targetPosition - origin
	if shotDelta.Magnitude <= MIN_AIM_DISTANCE then
		return
	end

	self._nextShotAt = now + self._weapon.FireInterval
	self._projectileService:SpawnProjectile({
		OwnerUserId = unit.Owner.UserId,
		SourceId = unit.Id,
		Position = origin,
		Direction = shotDelta.Unit,
		Weapon = self._weapon,
	})
end

function ArmyUnitCombat:Destroy()
	self._target = nil
end

return ArmyUnitCombat
