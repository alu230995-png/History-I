local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("Constants"):WaitForChild("WeaponConfig"))

local DamageService = Knit.CreateService({
	Name = "DamageService",
	Client = {},
})

local TARGET_KIND = WeaponConfig.TargetKinds

function DamageService:KnitInit()
	self._buildService = nil
	self._manpowerService = nil
	self._nexoService = nil
	self._targetingService = nil
	self._diplomacyService = nil
	self._explosionTargets = {}
end

function DamageService:KnitStart()
	self._buildService = Knit.GetService("BuildService")
	self._manpowerService = Knit.GetService("ManpowerService")
	self._nexoService = Knit.GetService("NexoService")
	self._targetingService = Knit.GetService("TargetingService")
	self._diplomacyService = Knit.GetService("DiplomacyService")
end

function DamageService:ApplyProjectileHit(projectile, target, hitPosition: Vector3): any
	local explosionRadius = projectile.Weapon.ExplosionRadius
	if projectile.Weapon.Explosive == true and typeof(explosionRadius) == "number" and explosionRadius > 0 then
		return self:_applyExplosion(projectile, hitPosition, explosionRadius)
	end

	return self:_damageTarget(projectile, target)
end

function DamageService:_applyExplosion(projectile, hitPosition: Vector3, radius: number): any
	local explosionTargets = self._explosionTargets
	table.clear(explosionTargets)
	self._targetingService:CollectProjectileTargetsInRadius(
		projectile,
		hitPosition,
		radius,
		os.clock(),
		explosionTargets
	)

	local damaged = 0
	for index = 1, #explosionTargets do
		local result = self:_damageTarget(projectile, explosionTargets[index])
		if result.ok then
			damaged += 1
		end
	end

	table.clear(explosionTargets)
	return { ok = damaged > 0, damaged = damaged }
end

function DamageService:_damageTarget(projectile, target): any
	if target.OwnerUserId == projectile.OwnerUserId then
		return { ok = false, reason = "FriendlyTarget" }
	end

	if
		self._diplomacyService ~= nil
		and not self._diplomacyService:AreHostile(projectile.OwnerUserId, target.OwnerUserId)
	then
		return { ok = false, reason = "FriendlyTarget" }
	end

	local weapon = projectile.Weapon
	local damageKind = if target.Kind == TARGET_KIND.Unit then TARGET_KIND.Unit else TARGET_KIND.Structure
	local damage = weapon.Damage[damageKind]
	if typeof(damage) ~= "number" or damage <= 0 then
		return { ok = false, reason = "InvalidDamage" }
	end

	if target.Kind == TARGET_KIND.Unit then
		return self._manpowerService:DamageUnit(target.DamageTarget, damage)
	end

	if target.TargetType == "Building" then
		return self._buildService:DamageBuilding(target.DamageTarget, damage)
	end

	if target.TargetType == "Nexo" then
		return self._nexoService:DamageNexo(target.DamageTarget, damage, projectile.OwnerUserId)
	end

	return { ok = false, reason = "InvalidTarget" }
end

function DamageService:Destroy()
	table.clear(self._explosionTargets)
end

return DamageService
