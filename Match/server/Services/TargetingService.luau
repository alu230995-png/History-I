local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local WeaponConfig = require(Shared:WaitForChild("Constants"):WaitForChild("WeaponConfig"))

local TargetingService = Knit.CreateService({
	Name = "TargetingService",
	Client = {},
})

local TARGET_KIND = WeaponConfig.TargetKinds
local MIN_TARGET_RADIUS = 1

local function getPriorityRank(targetKind: string, targetPriority: { string }?): number
	if targetPriority == nil then
		return 1
	end

	for index = 1, #targetPriority do
		if targetPriority[index] == targetKind then
			return index
		end
	end

	return math.huge
end

local function getModelRootPart(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getModelHitRadius(model: Model): number
	local _boxCFrame, size = model:GetBoundingBox()
	return math.max(size.Magnitude * 0.5, MIN_TARGET_RADIUS)
end

function TargetingService:KnitInit()
	self._trove = Trove.new()
	self._destroyed = false
	self._targets = {}
	self._targetsById = {}
	self._buildService = nil
	self._manpowerService = nil
	self._nexoService = nil
	self._diplomacyService = nil
end

function TargetingService:KnitStart()
	self._buildService = Knit.GetService("BuildService")
	self._manpowerService = Knit.GetService("ManpowerService")
	self._nexoService = Knit.GetService("NexoService")
	self._diplomacyService = Knit.GetService("DiplomacyService")

	self._trove:Add(self._manpowerService.UnitSpawned:Connect(function(unit)
		self:RegisterUnit(unit)
	end))
	self._trove:Add(self._manpowerService.UnitDestroyed:Connect(function(unit)
		self:RemoveTarget(self:_getUnitTargetId(unit.Id))
	end))

	self._trove:Add(self._buildService.BuildingPlaced:Connect(function(record)
		self:RegisterBuilding(record)
	end))
	self._trove:Add(self._buildService.BuildingMoved:Connect(function(record)
		self:RegisterBuilding(record)
	end))
	self._trove:Add(self._buildService.BuildingDestroyed:Connect(function(payload)
		self:RemoveTarget(self:_getBuildingTargetId(payload.BuildingId))
	end))

	self._trove:Add(self._nexoService.CombatTargetChanged:Connect(function(record, enabled: boolean)
		if enabled then
			self:RegisterNexo(record)
		else
			self:RemoveTarget(self:_getNexoTargetId(record.Id))
		end
	end))

	for _, unit in self._manpowerService:GetCombatUnits() do
		self:RegisterUnit(unit)
	end
	for _, record in self._buildService:GetPlacedBuildingRecords() do
		self:RegisterBuilding(record)
	end
	for _, record in self._nexoService:GetActiveCombatNexos() do
		self:RegisterNexo(record)
	end
end

function TargetingService:_getUnitTargetId(unitId: string): string
	return `Unit:{unitId}`
end

function TargetingService:_getBuildingTargetId(buildingId: string): string
	return `Building:{buildingId}`
end

function TargetingService:_getNexoTargetId(nexoId: string): string
	return `Nexo:{nexoId}`
end

function TargetingService:RegisterUnit(unit)
	if type(unit) ~= "table" then
		return
	end

	local definition = unit.Definition
	local combat = definition.Combat
	local hitRadius = if type(combat) == "table" then combat.HitRadius else nil
	if typeof(hitRadius) ~= "number" or hitRadius <= 0 then
		warn(("[TargetingService] Unit %s has no valid Combat.HitRadius"):format(unit.UnitType))
		return
	end

	self:_upsertTarget({
		Id = self:_getUnitTargetId(unit.Id),
		Kind = TARGET_KIND.Unit,
		TargetType = "Unit",
		OwnerUserId = unit.Owner.UserId,
		SourceUnitId = unit.Id,
		Unit = unit,
		DamageTarget = unit.Id,
		HitRadius = hitRadius,
	})
end

function TargetingService:RegisterBuilding(record)
	if type(record) ~= "table" then
		return
	end

	local model = record.Model
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end

	local rootPart = getModelRootPart(model)
	if rootPart == nil then
		warn(("[TargetingService] Building %s has no root BasePart"):format(record.BuildingId))
		return
	end

	self:_upsertTarget({
		Id = self:_getBuildingTargetId(record.BuildingId),
		Kind = TARGET_KIND.Structure,
		TargetType = "Building",
		OwnerUserId = record.Owner.UserId,
		RootPart = rootPart,
		Model = model,
		DamageTarget = record.BuildingId,
		HitRadius = getModelHitRadius(model),
	})
end

function TargetingService:RegisterNexo(record)
	if type(record) ~= "table" then
		return
	end

	local rootPart = record.RootPart
	if typeof(rootPart) ~= "Instance" or not rootPart:IsA("BasePart") then
		return
	end

	local hitRadius = math.max(rootPart.Size.Magnitude * 0.5, MIN_TARGET_RADIUS)
	self:_upsertTarget({
		Id = self:_getNexoTargetId(record.Id),
		Kind = TARGET_KIND.Structure,
		TargetType = "Nexo",
		OwnerUserId = record.TakenByUserId,
		RootPart = rootPart,
		Model = record.Instance,
		DamageTarget = record.Id,
		HitRadius = hitRadius,
	})
end

function TargetingService:RemoveTarget(targetId: string)
	local target = self._targetsById[targetId]
	if target == nil then
		return
	end

	local targets = self._targets
	local index = target.Index
	local lastIndex = #targets
	local lastTarget = targets[lastIndex]

	targets[index] = lastTarget
	targets[lastIndex] = nil
	if lastTarget ~= nil and lastTarget ~= target then
		lastTarget.Index = index
	end

	target.Index = nil
	self._targetsById[targetId] = nil
end

function TargetingService:GetTargets(): { any }
	return self._targets
end

function TargetingService:AcquireTarget(
	attackerUserId: number,
	sourceUnitId: string,
	sourcePosition: Vector3,
	range: number,
	now: number,
	targetPriority: { string }?
): (any?, Vector3?)
	local closestTarget = nil
	local closestPosition = nil
	local closestDistanceSquared = math.huge
	local closestPriorityRank = math.huge
	local rangeSquared = range * range
	local targets = self._targets

	for index = 1, #targets do
		local target = targets[index]
		local priorityRank = getPriorityRank(target.Kind, targetPriority)
		if priorityRank == math.huge then
			continue
		end

		local position = self:_getValidTargetPosition(target, attackerUserId, sourceUnitId, now)
		if position == nil then
			continue
		end

		local offset = position - sourcePosition
		local distanceSquared = offset:Dot(offset)
		if
			distanceSquared <= rangeSquared
			and (
				priorityRank < closestPriorityRank
				or (priorityRank == closestPriorityRank and distanceSquared < closestDistanceSquared)
			)
		then
			closestTarget = target
			closestPosition = position
			closestDistanceSquared = distanceSquared
			closestPriorityRank = priorityRank
		end
	end

	return closestTarget, closestPosition
end

function TargetingService:ValidateTarget(
	target,
	attackerUserId: number,
	sourceUnitId: string,
	sourcePosition: Vector3,
	range: number,
	now: number
): Vector3?
	local position = self:_getValidTargetPosition(target, attackerUserId, sourceUnitId, now)
	if position == nil then
		return nil
	end

	local offset = position - sourcePosition
	return if offset:Dot(offset) <= range * range then position else nil
end

function TargetingService:GetProjectileTargetPosition(target, projectile, now: number): Vector3?
	return self:_getValidTargetPosition(target, projectile.OwnerUserId, projectile.SourceId, now)
end

function TargetingService:CollectProjectileTargetsInRadius(
	projectile,
	center: Vector3,
	radius: number,
	now: number,
	output: { any }
)
	local radiusSquared = radius * radius
	local targets = self._targets

	for index = 1, #targets do
		local target = targets[index]
		local position = self:GetProjectileTargetPosition(target, projectile, now)
		if position == nil then
			continue
		end

		local offset = position - center
		local hitRadius = target.HitRadius
		local reach = radius + hitRadius
		if offset:Dot(offset) <= math.max(radiusSquared, reach * reach) then
			table.insert(output, target)
		end
	end
end

function TargetingService:_upsertTarget(target)
	local current = self._targetsById[target.Id]
	if current ~= nil then
		target.Index = current.Index
		self._targets[target.Index] = target
		self._targetsById[target.Id] = target
		return
	end

	target.Index = #self._targets + 1
	self._targets[target.Index] = target
	self._targetsById[target.Id] = target
end

function TargetingService:_getValidTargetPosition(
	target,
	attackerUserId: number,
	sourceUnitId: string,
	now: number
): Vector3?
	if
		target == nil
		or target.OwnerUserId == nil
		or target.OwnerUserId == attackerUserId
		or target.SourceUnitId == sourceUnitId
	then
		return nil
	end

	if self._diplomacyService ~= nil and not self._diplomacyService:AreHostile(attackerUserId, target.OwnerUserId) then
		return nil
	end

	if target.TargetType == "Unit" then
		if not self._manpowerService:IsCombatUnitActive(target.Unit) then
			return nil
		end

		return self._manpowerService:GetUnitCombatPosition(target.Unit, now)
	end

	local rootPart = target.RootPart
	local model = target.Model
	local hp = if model ~= nil then model:GetAttribute("HP") else nil
	if
		rootPart == nil
		or rootPart.Parent == nil
		or model == nil
		or model.Parent == nil
		or typeof(hp) ~= "number"
		or hp <= 0
	then
		return nil
	end

	if target.TargetType == "Nexo" and model:GetAttribute("NexoActive") ~= true then
		return nil
	end

	return rootPart.Position
end

function TargetingService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
	table.clear(self._targets)
	table.clear(self._targetsById)
end

return TargetingService
