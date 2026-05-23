local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local WeaponConfig = require(Shared:WaitForChild("Constants"):WaitForChild("WeaponConfig"))

local ProjectileEffectsController = Knit.CreateController({
	Name = "ProjectileEffectsController",
})

local EFFECTS_FOLDER_NAME = "ProjectileEffects"
local DEFAULT_POOL_SIZE = WeaponConfig.DefaultProjectilePoolSize or 8
local BULLET_SIZE = Vector3.new(0.22, 0.22, 1.2)
local SHELL_SIZE = Vector3.new(0.8, 0.8, 0.8)
local BLAST_COLOR = Color3.fromRGB(255, 138, 50)
local BULLET_COLOR = Color3.fromRGB(255, 238, 152)
local SHELL_COLOR = Color3.fromRGB(255, 177, 68)
local BLAST_DURATION = 0.22
local MIN_DIRECTION_MAGNITUDE = 0.001
local HIDDEN_CFRAME = CFrame.new(0, -10000, 0)

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

local function getRootPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end

	local handle = instance:FindFirstChild("Handle", true)
	if handle ~= nil and handle:IsA("BasePart") then
		return handle
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function configureProjectileInstance(instance: Instance)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.LocalTransparencyModifier = 1
		end
	end

	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanQuery = false
		instance.CanTouch = false
		instance.CastShadow = false
		instance.LocalTransparencyModifier = 1
	end
end

local function setProjectileVisible(instance: Instance, visible: boolean)
	local transparency = if visible then 0 else 1

	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = transparency
		end
	end

	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = transparency
	end
end

local function pivotProjectile(instance: Instance, root: BasePart, cframe: CFrame)
	if instance:IsA("Model") then
		instance:PivotTo(cframe)
		return
	end

	if instance:IsA("BasePart") then
		instance.CFrame = cframe
		return
	end

	local delta = cframe * root.CFrame:Inverse()
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame = delta * descendant.CFrame
		end
	end
end

local function createFallbackProjectile(visualKind: string): BasePart
	local part = Instance.new("Part")
	part.Name = visualKind
	part.Material = Enum.Material.Neon
	part.Color = if visualKind == "Bullet" then BULLET_COLOR else SHELL_COLOR
	part.Size = if visualKind == "Bullet" then BULLET_SIZE else SHELL_SIZE
	part.Shape = if visualKind == "Bullet" then Enum.PartType.Block else Enum.PartType.Ball
	return part
end

function ProjectileEffectsController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._projectileService = nil
	self._effectsFolder = nil
	self._projectilePools = {}
	self._activeProjectiles = {}
	self._blastPool = {}
	self._activeBlasts = {}
end

function ProjectileEffectsController:KnitStart()
	self._projectileService = Knit.GetService("ProjectileService")
	self:_mountEffectsFolder()
	self:_prewarmProjectilePools()
	self:_prewarmBlastPool(DEFAULT_POOL_SIZE)

	self._trove:Add(self._projectileService.ProjectileSpawned:Connect(function(payload)
		self:_spawnProjectile(payload)
	end))
	self._trove:Add(self._projectileService.ProjectileImpacted:Connect(function(payload)
		self:_impactProjectile(payload)
	end))
	self._trove:Add(RunService.Heartbeat:Connect(function()
		self:_updateEffects(os.clock())
	end))
end

function ProjectileEffectsController:_mountEffectsFolder()
	local folder = Instance.new("Folder")
	folder.Name = EFFECTS_FOLDER_NAME
	folder.Parent = Workspace
	self._effectsFolder = folder
	self._trove:Add(folder)
end

function ProjectileEffectsController:_prewarmProjectilePools()
	for weaponId, weapon in WeaponConfig.Weapons do
		if type(weapon) == "table" and weapon.VisualKind ~= nil then
			local poolSize = if typeof(weapon.ProjectilePoolSize) == "number"
				then math.max(1, weapon.ProjectilePoolSize)
				else DEFAULT_POOL_SIZE
			self:_ensureProjectilePool(weaponId, weapon, poolSize)
		end
	end
end

function ProjectileEffectsController:_ensureProjectilePool(key: string, weapon, poolSize: number)
	if self._projectilePools[key] ~= nil then
		return
	end

	local pool = table.create(poolSize)
	self._projectilePools[key] = pool

	for _index = 1, poolSize do
		table.insert(pool, self:_createProjectilePoolItem(key, weapon))
	end
end

function ProjectileEffectsController:_createProjectilePoolItem(key: string, weapon)
	local visualKind = if type(weapon) == "table" and typeof(weapon.VisualKind) == "string"
		then weapon.VisualKind
		else key
	local source = if type(weapon) == "table" then resolvePath(weapon.ProjectilePath) else nil
	local instance = if source ~= nil then source:Clone() else createFallbackProjectile(visualKind)
	instance.Name = `{key}_Projectile`
	configureProjectileInstance(instance)

	local root = getRootPart(instance)
	if root == nil then
		instance:Destroy()
		instance = createFallbackProjectile(visualKind)
		instance.Name = `{key}_Projectile`
		configureProjectileInstance(instance)
		root = instance
	end

	pivotProjectile(instance, root, HIDDEN_CFRAME)
	instance.Parent = self._effectsFolder

	return {
		Instance = instance,
		Root = root,
		InUse = false,
		BasePosition = Vector3.zero,
		Velocity = Vector3.zero,
		Direction = Vector3.zAxis,
		StartedAt = 0,
		ExpiresAt = 0,
	}
end

function ProjectileEffectsController:_prewarmBlastPool(poolSize: number)
	for _index = 1, poolSize do
		local blast = Instance.new("Part")
		blast.Name = "PooledProjectileBlast"
		blast.Shape = Enum.PartType.Ball
		blast.Material = Enum.Material.Neon
		blast.Color = BLAST_COLOR
		blast.Anchored = true
		blast.CanCollide = false
		blast.CanQuery = false
		blast.CanTouch = false
		blast.CastShadow = false
		blast.Transparency = 1
		blast.Size = Vector3.one
		blast.CFrame = HIDDEN_CFRAME
		blast.Parent = self._effectsFolder
		table.insert(self._blastPool, {
			Part = blast,
			InUse = false,
			StartedAt = 0,
			Radius = 0,
		})
	end
end

function ProjectileEffectsController:_acquireProjectile(key: string)
	local pool = self._projectilePools[key]
	if pool == nil then
		return nil
	end

	for index = 1, #pool do
		local item = pool[index]
		if not item.InUse then
			item.InUse = true
			return item
		end
	end

	return nil
end

function ProjectileEffectsController:_releaseProjectile(projectileId: number)
	local item = self._activeProjectiles[projectileId]
	if item == nil then
		return
	end

	self._activeProjectiles[projectileId] = nil
	item.InUse = false
	setProjectileVisible(item.Instance, false)
	pivotProjectile(item.Instance, item.Root, HIDDEN_CFRAME)
end

function ProjectileEffectsController:_spawnProjectile(payload)
	if
		type(payload) ~= "table"
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

	self:_releaseProjectile(payload.Id)

	local key = if typeof(payload.WeaponId) == "string" and payload.WeaponId ~= ""
		then payload.WeaponId
		else tostring(payload.VisualKind)
	local item = self:_acquireProjectile(key)
	if item == nil then
		return
	end

	local direction = payload.Direction.Unit
	local now = os.clock()
	item.BasePosition = payload.Position
	item.Direction = direction
	item.Velocity = direction * payload.Speed
	item.StartedAt = now
	item.ExpiresAt = now + payload.Lifetime
	self._activeProjectiles[payload.Id] = item

	setProjectileVisible(item.Instance, true)
	pivotProjectile(item.Instance, item.Root, CFrame.lookAt(payload.Position, payload.Position + direction))
end

function ProjectileEffectsController:_impactProjectile(payload)
	if type(payload) ~= "table" or typeof(payload.Id) ~= "number" or typeof(payload.Position) ~= "Vector3" then
		return
	end

	self:_releaseProjectile(payload.Id)

	if payload.Explosive == true then
		local radius = if typeof(payload.ExplosionRadius) == "number" then payload.ExplosionRadius else 8
		self:_spawnBlast(payload.Position, radius)
	end
end

function ProjectileEffectsController:_spawnBlast(position: Vector3, radius: number)
	for index = 1, #self._blastPool do
		local blast = self._blastPool[index]
		if not blast.InUse then
			blast.InUse = true
			blast.StartedAt = os.clock()
			blast.Radius = radius
			blast.Part.Transparency = 0.35
			blast.Part.Size = Vector3.one
			blast.Part.CFrame = CFrame.new(position)
			table.insert(self._activeBlasts, blast)
			return
		end
	end
end

function ProjectileEffectsController:_updateEffects(now: number)
	for projectileId, item in self._activeProjectiles do
		if now >= item.ExpiresAt or item.Instance.Parent == nil then
			self:_releaseProjectile(projectileId)
			continue
		end

		local position = item.BasePosition + (item.Velocity * (now - item.StartedAt))
		pivotProjectile(item.Instance, item.Root, CFrame.lookAt(position, position + item.Direction))
	end

	for index = #self._activeBlasts, 1, -1 do
		local blast = self._activeBlasts[index]
		local alpha = math.clamp((now - blast.StartedAt) / BLAST_DURATION, 0, 1)
		local size = math.max(blast.Radius * alpha * 2, 0.001)
		blast.Part.Size = Vector3.new(size, size, size)
		blast.Part.Transparency = 0.35 + alpha * 0.65

		if alpha >= 1 then
			blast.InUse = false
			blast.Part.Transparency = 1
			blast.Part.CFrame = HIDDEN_CFRAME
			table.remove(self._activeBlasts, index)
		end
	end
end

function ProjectileEffectsController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	for projectileId in self._activeProjectiles do
		self:_releaseProjectile(projectileId)
	end
	for index = #self._activeBlasts, 1, -1 do
		local blast = self._activeBlasts[index]
		blast.InUse = false
		blast.Part.Transparency = 1
		blast.Part.CFrame = HIDDEN_CFRAME
		table.remove(self._activeBlasts, index)
	end
	self._trove:Destroy()
	table.clear(self._projectilePools)
	table.clear(self._activeProjectiles)
	table.clear(self._blastPool)
end

return ProjectileEffectsController
