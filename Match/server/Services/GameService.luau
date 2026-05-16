local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local GameConstants = require(Shared:WaitForChild("Constants"):WaitForChild("GameConstants"))
local MatchStates = require(Shared:WaitForChild("Constants"):WaitForChild("MatchStates"))
local PlayerStates = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStates"))
local StateMachine = require(Shared:WaitForChild("Classes"):WaitForChild("StateMachine"))

local GameService = Knit.CreateService({
	Name = "GameService",

	Client = {
		DroneAssigned = Knit.CreateSignal(),
		PlayerStateChanged = Knit.CreateSignal(),
		MatchStateChanged = Knit.CreateSignal(),
		DroneVelocityRequested = Knit.CreateUnreliableSignal(),
	},
})

local ZERO_VECTOR = Vector3.zero

local function clampNumber(value: number, minValue: number, maxValue: number): number
	return math.clamp(value, minValue, maxValue)
end

local function clampPosition(position: Vector3): Vector3
	local bounds = GameConstants.MapBounds

	return Vector3.new(
		clampNumber(position.X, bounds.Min.X, bounds.Max.X),
		clampNumber(position.Y, bounds.Min.Y, bounds.Max.Y),
		clampNumber(position.Z, bounds.Min.Z, bounds.Max.Z)
	)
end

local function isFiniteVector3(value: Vector3): boolean
	return value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < math.huge
		and math.abs(value.Y) < math.huge
		and math.abs(value.Z) < math.huge
end

local function limitVelocity(velocity: Vector3): Vector3
	local maxSpeed = GameConstants.Drone.MaxSpeed
	local magnitude = velocity.Magnitude

	if magnitude <= maxSpeed then
		return velocity
	end

	return velocity.Unit * maxSpeed
end

function GameService.Client:GetAssignedDrone(player: Player): BasePart?
	local runtime = self.Server._drones[player]

	return if runtime ~= nil then runtime.Part else nil
end

function GameService.Client:GetAssignedDroneSnapshot(player: Player): { Name: string, Position: Vector3 }?
	local runtime = self.Server._drones[player]
	if runtime == nil then
		return nil
	end

	return {
		Name = runtime.Part.Name,
		Position = runtime.Part.Position,
	}
end

function GameService.Client:GetPlayerState(player: Player): string?
	local machine = self.Server._playerMachines[player]

	return if machine ~= nil then machine:GetState() else nil
end

function GameService.Client:GetMatchState(_player: Player): string
	return self.Server._matchMachine:GetState()
end

function GameService:KnitInit()
	Players.CharacterAutoLoads = false
	StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Thumbstick

	self._destroyed = false
	self._trove = Trove.new()
	self._playerMachines = {}
	self._playerTroves = {}
	self._drones = {}
	self._lastVelocityRequest = {}

	self._droneFolder = Instance.new("Folder")
	self._droneFolder.Name = GameConstants.Drone.FolderName
	self._droneFolder.Parent = Workspace
	self._trove:Add(self._droneFolder)

	self._controlRigFolder = Instance.new("Folder")
	self._controlRigFolder.Name = GameConstants.ControlRig.FolderName
	self._controlRigFolder.Parent = Workspace
	self._trove:Add(self._controlRigFolder)

	self._matchMachine = StateMachine.new(MatchStates.Booting, MatchStates.AllowedTransitions)
	self._trove:Add(self._matchMachine)
	self._trove:Add(self._matchMachine:OnTransition(function(transition)
		print(("[FSM] Match: %s -> %s"):format(transition.OldState, transition.NewState))
		self.Client.MatchStateChanged:FireAll(transition.OldState, transition.NewState, transition.Context)
	end))
	self._matchMachine:TransitionTo(MatchStates.WaitingForPlayers)

	self._trove:Add(self.Client.DroneVelocityRequested:Connect(function(player: Player, velocity: any)
		self:_handleDroneVelocityRequest(player, velocity)
	end))

	self._trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self:_handlePlayerRemoving(player)
	end))

	self._trove:Add(RunService.Heartbeat:Connect(function()
		self:_clampDrones()
	end))
end

function GameService:KnitStart()
	self._trove:Add(Players.PlayerAdded:Connect(function(player: Player)
		self:_handlePlayerAdded(player)
	end))

	task.defer(function()
		if self._destroyed then
			return
		end

		for _, player in Players:GetPlayers() do
			self:_handlePlayerAdded(player)
		end
	end)
end

function GameService:_handlePlayerAdded(player: Player)
	if self._playerTroves[player] ~= nil then
		return
	end

	pcall(function()
		player.DevTouchMovementMode = Enum.DevTouchMovementMode.Thumbstick
	end)

	if player.Character ~= nil then
		player.Character:Destroy()
	end

	local playerTrove = Trove.new()
	self._playerTroves[player] = playerTrove

	local machine = StateMachine.new(PlayerStates.Connecting, PlayerStates.AllowedTransitions)
	self._playerMachines[player] = machine
	playerTrove:Add(machine)

	playerTrove:Add(machine:OnTransition(function(transition)
		print(("[FSM] %s: %s -> %s"):format(player.Name, transition.OldState, transition.NewState))
		self.Client.PlayerStateChanged:Fire(player, transition.OldState, transition.NewState, transition.Context)
	end))

	self:_createControlRigForPlayer(player, playerTrove)
	self:_createDroneForPlayer(player, playerTrove)
	machine:TransitionTo(PlayerStates.Lobby)
end

function GameService:_createControlRigForPlayer(player: Player, playerTrove)
	local spawnPosition = clampPosition(GameConstants.Drone.SpawnPosition)

	local rig = Instance.new("Model")
	rig.Name = player.Name
	rig:SetAttribute("OwnerUserId", player.UserId)
	rig:SetAttribute("CommandControlRig", true)
	rig.Parent = self._controlRigFolder
	playerTrove:Add(rig)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = GameConstants.ControlRig.RootSize
	root.CFrame = CFrame.new(spawnPosition)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = rig

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = GameConstants.ControlRig.HeadSize
	head.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 2, 0))
	head.Transparency = 1
	head.Anchored = true
	head.CanCollide = false
	head.CanQuery = false
	head.CanTouch = false
	head.Massless = true
	head.Parent = rig

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 0
	humanoid.Parent = rig

	rig.PrimaryPart = root
	player.Character = rig
end

function GameService:_createDroneForPlayer(player: Player, playerTrove)
	local drone = Instance.new("Part")
	drone.Name = GameConstants.Drone.NamePrefix .. tostring(player.UserId)
	drone.Size = GameConstants.Drone.Size
	drone.CFrame = CFrame.new(clampPosition(GameConstants.Drone.SpawnPosition))
	drone.Transparency = 1
	drone.Anchored = false
	drone.Massless = true
	drone.CanCollide = false
	drone.CanQuery = false
	drone.CanTouch = false
	drone:SetAttribute("OwnerUserId", player.UserId)
	drone.Parent = self._droneFolder
	playerTrove:Add(drone)

	pcall(function()
		drone:SetNetworkOwner(nil)
	end)

	pcall(function()
		player.ReplicationFocus = drone
	end)

	playerTrove:Add(function()
		if player.Parent ~= nil and player.ReplicationFocus == drone then
			player.ReplicationFocus = nil
		end
	end)

	local attachment = Instance.new("Attachment")
	attachment.Name = "DroneVelocityAttachment"
	attachment.Parent = drone

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "DroneLinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VectorVelocity = ZERO_VECTOR
	linearVelocity.Parent = drone

	local configuredForceLimits = pcall(function()
		linearVelocity.ForceLimitsEnabled = true
		linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		linearVelocity.MaxAxesForce = GameConstants.Drone.MaxForce
	end)

	if not configuredForceLimits then
		pcall(function()
			linearVelocity.MaxForce = math.max(
				GameConstants.Drone.MaxForce.X,
				GameConstants.Drone.MaxForce.Y,
				GameConstants.Drone.MaxForce.Z
			)
		end)
	end

	self._drones[player] = {
		Part = drone,
		Attachment = attachment,
		LinearVelocity = linearVelocity,
	}

	self.Client.DroneAssigned:Fire(player, drone, drone.Position, drone.Name)
end

function GameService:_handleDroneVelocityRequest(player: Player, velocity: any)
	local runtime = self._drones[player]
	if runtime == nil then
		return
	end

	if typeof(velocity) ~= "Vector3" or not isFiniteVector3(velocity) then
		warn(("[Drone] Rejected invalid velocity from %s"):format(player.Name))
		return
	end

	local now = os.clock()
	local lastRequest = self._lastVelocityRequest[player]
	local minInterval = 1 / GameConstants.Drone.MaxVelocityRequestsPerSecond
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local isStopRequest = horizontalVelocity.Magnitude <= GameConstants.Camera.MovementDeadzone

	if not isStopRequest and lastRequest ~= nil and now - lastRequest < minInterval then
		return
	end
	self._lastVelocityRequest[player] = now

	runtime.LinearVelocity.VectorVelocity = if isStopRequest then ZERO_VECTOR else limitVelocity(horizontalVelocity)
end

function GameService:_clampDrones()
	for player, runtime in self._drones do
		local drone = runtime.Part
		if drone.Parent == nil then
			self._drones[player] = nil
			continue
		end

		local clamped = clampPosition(drone.Position)
		if clamped ~= drone.Position then
			drone.CFrame = CFrame.new(clamped)
			drone.AssemblyLinearVelocity = ZERO_VECTOR
			runtime.LinearVelocity.VectorVelocity = ZERO_VECTOR
		end
	end
end

function GameService:_handlePlayerRemoving(player: Player)
	local playerTrove = self._playerTroves[player]
	if playerTrove ~= nil then
		playerTrove:Destroy()
	end

	self._playerTroves[player] = nil
	self._playerMachines[player] = nil
	self._drones[player] = nil
	self._lastVelocityRequest[player] = nil
end

function GameService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true

	for player in self._playerTroves do
		self:_handlePlayerRemoving(player)
	end

	self._trove:Destroy()
end

return GameService
