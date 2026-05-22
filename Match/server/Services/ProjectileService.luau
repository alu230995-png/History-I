local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local ProjectileService = Knit.CreateService({
	Name = "ProjectileService",
	Client = {
		ProjectileSpawned = Knit.CreateUnreliableSignal(),
		ProjectileImpacted = Knit.CreateUnreliableSignal(),
	},
})

local PROJECTILE_STEP_SECONDS = 0.05
local MAX_HEARTBEAT_DELTA = 0.5
local MIN_DIRECTION_MAGNITUDE = 0.001

local function isFiniteVector3(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < math.huge
		and math.abs(value.Y) < math.huge
		and math.abs(value.Z) < math.huge
end

function ProjectileService:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._projectiles = {}
	self._simulationAccumulator = 0
	self._nextProjectileId = 0
	self._collisionService = nil
	self._damageService = nil
end

function ProjectileService:KnitStart()
	self._collisionService = Knit.GetService("CollisionService")
	self._damageService = Knit.GetService("DamageService")
	self._trove:Add(RunService.Heartbeat:Connect(function(deltaTime: number)
		self:_stepHeartbeat(deltaTime)
	end))
end

function ProjectileService:SpawnProjectile(request): boolean
	if
		type(request) ~= "table"
		or not isFiniteVector3(request.Position)
		or not isFiniteVector3(request.Direction)
		or request.Direction.Magnitude <= MIN_DIRECTION_MAGNITUDE
	then
		return false
	end

	local weapon = request.Weapon
	if
		type(weapon) ~= "table"
		or typeof(weapon.ProjectileSpeed) ~= "number"
		or weapon.ProjectileSpeed <= 0
		or typeof(weapon.Lifetime) ~= "number"
		or weapon.Lifetime <= 0
	then
		return false
	end

	local now = os.clock()
	self._nextProjectileId += 1
	local projectile = {
		Id = self._nextProjectileId,
		OwnerUserId = request.OwnerUserId,
		SourceId = request.SourceId,
		Position = request.Position,
		Direction = request.Direction.Unit,
		Speed = weapon.ProjectileSpeed,
		ExpiresAt = now + weapon.Lifetime,
		Weapon = weapon,
	}
	table.insert(self._projectiles, projectile)
	self:_broadcastSpawn(projectile)

	return true
end

function ProjectileService:_stepHeartbeat(deltaTime: number)
	if self._destroyed then
		return
	end

	self._simulationAccumulator += math.min(deltaTime, MAX_HEARTBEAT_DELTA)
	while self._simulationAccumulator >= PROJECTILE_STEP_SECONDS do
		self._simulationAccumulator -= PROJECTILE_STEP_SECONDS
		self:_stepProjectiles(os.clock())
	end
end

function ProjectileService:_stepProjectiles(now: number)
	local projectiles = self._projectiles
	local index = #projectiles
	while index >= 1 do
		local projectile = projectiles[index]
		if projectile.ExpiresAt <= now then
			self:_removeProjectile(index)
			index -= 1
			continue
		end

		local fromPosition = projectile.Position
		local toPosition = fromPosition + (projectile.Direction * projectile.Speed * PROJECTILE_STEP_SECONDS)
		local target, hitPosition = self._collisionService:SweepProjectile(projectile, fromPosition, toPosition, now)
		if target ~= nil then
			self._damageService:ApplyProjectileHit(projectile, target, hitPosition or toPosition)
			self:_broadcastImpact(projectile, hitPosition or toPosition)
			self:_removeProjectile(index)
		else
			projectile.Position = toPosition
		end

		index -= 1
	end
end

function ProjectileService:_broadcastSpawn(projectile)
	local weapon = projectile.Weapon
	if weapon.VisualKind == nil then
		return
	end

	self.Client.ProjectileSpawned:FireAll({
		Id = projectile.Id,
		Position = projectile.Position,
		Direction = projectile.Direction,
		Speed = projectile.Speed,
		Lifetime = weapon.Lifetime,
		VisualKind = weapon.VisualKind,
	})
end

function ProjectileService:_broadcastImpact(projectile, position: Vector3)
	local weapon = projectile.Weapon
	if weapon.VisualKind == nil then
		return
	end

	self.Client.ProjectileImpacted:FireAll({
		Id = projectile.Id,
		Position = position,
		VisualKind = weapon.VisualKind,
		ExplosionRadius = weapon.ExplosionRadius,
	})
end

function ProjectileService:_removeProjectile(index: number)
	local projectiles = self._projectiles
	local lastIndex = #projectiles
	projectiles[index] = projectiles[lastIndex]
	projectiles[lastIndex] = nil
end

function ProjectileService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
	table.clear(self._projectiles)
end

return ProjectileService
