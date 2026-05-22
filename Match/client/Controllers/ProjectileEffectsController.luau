local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local ProjectileEffectsController = Knit.CreateController({
	Name = "ProjectileEffectsController",
})

local EFFECTS_FOLDER_NAME = "ProjectileEffects"
local SHELL_SIZE = Vector3.new(0.8, 0.8, 0.8)
local SHELL_COLOR = Color3.fromRGB(255, 177, 68)
local MIN_DIRECTION_MAGNITUDE = 0.001

function ProjectileEffectsController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._projectileService = nil
	self._effectsFolder = nil
	self._shells = {}
end

function ProjectileEffectsController:KnitStart()
	self._projectileService = Knit.GetService("ProjectileService")
	self:_mountEffectsFolder()

	self._trove:Add(self._projectileService.ProjectileSpawned:Connect(function(payload)
		self:_spawnProjectile(payload)
	end))
	self._trove:Add(self._projectileService.ProjectileImpacted:Connect(function(payload)
		self:_impactProjectile(payload)
	end))
	self._trove:Add(RunService.Heartbeat:Connect(function()
		self:_updateProjectiles(os.clock())
	end))
end

function ProjectileEffectsController:_mountEffectsFolder()
	local folder = Instance.new("Folder")
	folder.Name = EFFECTS_FOLDER_NAME
	folder.Parent = Workspace
	self._effectsFolder = folder
	self._trove:Add(folder)
end

function ProjectileEffectsController:_spawnProjectile(payload)
	if
		type(payload) ~= "table"
		or payload.VisualKind ~= "ExplosiveShell"
		or typeof(payload.Id) ~= "number"
		or typeof(payload.Position) ~= "Vector3"
		or typeof(payload.Direction) ~= "Vector3"
		or payload.Direction.Magnitude <= MIN_DIRECTION_MAGNITUDE
		or typeof(payload.Speed) ~= "number"
		or payload.Speed <= 0
		or typeof(payload.Lifetime) ~= "number"
		or payload.Lifetime <= 0
	then
		return
	end

	self:_destroyShell(payload.Id)

	local shell = Instance.new("Part")
	shell.Name = "ExplosiveShell"
	shell.Shape = Enum.PartType.Ball
	shell.Material = Enum.Material.Neon
	shell.Color = SHELL_COLOR
	shell.Size = SHELL_SIZE
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CastShadow = false
	shell.Position = payload.Position
	shell.Parent = self._effectsFolder

	self._shells[payload.Id] = {
		Part = shell,
		Position = payload.Position,
		Velocity = payload.Direction.Unit * payload.Speed,
		StartedAt = os.clock(),
		ExpiresAt = os.clock() + payload.Lifetime,
	}
end

function ProjectileEffectsController:_impactProjectile(payload)
	if type(payload) ~= "table" or typeof(payload.Id) ~= "number" or typeof(payload.Position) ~= "Vector3" then
		return
	end

	self:_destroyShell(payload.Id)

	if payload.VisualKind ~= "ExplosiveShell" then
		return
	end

	local explosion = Instance.new("Explosion")
	explosion.Position = payload.Position
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.BlastRadius = if typeof(payload.ExplosionRadius) == "number" then payload.ExplosionRadius else 8
	explosion.Parent = Workspace
	Debris:AddItem(explosion, 2)
end

function ProjectileEffectsController:_updateProjectiles(now: number)
	for projectileId, shell in self._shells do
		if now >= shell.ExpiresAt or shell.Part.Parent == nil then
			self:_destroyShell(projectileId)
			continue
		end

		shell.Part.Position = shell.Position + (shell.Velocity * (now - shell.StartedAt))
	end
end

function ProjectileEffectsController:_destroyShell(projectileId: number)
	local shell = self._shells[projectileId]
	if shell == nil then
		return
	end

	self._shells[projectileId] = nil
	shell.Part:Destroy()
end

function ProjectileEffectsController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	for projectileId in self._shells do
		self:_destroyShell(projectileId)
	end
	self._trove:Destroy()
end

return ProjectileEffectsController
