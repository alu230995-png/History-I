local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local GameConstants = require(Shared:WaitForChild("Constants"):WaitForChild("GameConstants"))

local CameraController = Knit.CreateController({
	Name = "CameraController",
})

local MOVEMENT_KEYS = {
	[Enum.KeyCode.W] = "Forward",
	[Enum.KeyCode.S] = "Backward",
	[Enum.KeyCode.A] = "Left",
	[Enum.KeyCode.D] = "Right",
}

local ZERO_VECTOR = Vector3.zero
local LOCAL_PLAYER = Players.LocalPlayer
local TOP_DOWN_ROTATION = CFrame.Angles(math.rad(-90), 0, 0)
local MAX_DELTA_TIME = 1 / 15

local function vectorsClose(a: Vector3, b: Vector3): boolean
	return (a - b).Magnitude <= GameConstants.Camera.VelocityEpsilon
end

local function getFallbackFocus(): Vector3
	return GameConstants.Drone.SpawnPosition
end

local function getTopDownCameraCFrame(focusPosition: Vector3, cameraHeight: number): CFrame
	local cameraPosition = focusPosition + Vector3.new(0, cameraHeight, 0)

	return CFrame.new(cameraPosition) * TOP_DOWN_ROTATION
end

local function clampFocusPosition(position: Vector3): Vector3
	local bounds = GameConstants.MapBounds

	return Vector3.new(
		math.clamp(position.X, bounds.Min.X, bounds.Max.X),
		math.clamp(position.Y, bounds.Min.Y, bounds.Max.Y),
		math.clamp(position.Z, bounds.Min.Z, bounds.Max.Z)
	)
end

local function smoothDampNumber(
	current: number,
	target: number,
	currentVelocity: number,
	smoothTime: number,
	maxSpeed: number,
	deltaTime: number
): (number, number)
	smoothTime = math.max(0.0001, smoothTime)

	local omega = 2 / smoothTime
	local x = omega * deltaTime
	local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
	local change = current - target
	local originalTarget = target
	local maxChange = maxSpeed * smoothTime

	change = math.clamp(change, -maxChange, maxChange)
	target = current - change

	local temp = (currentVelocity + omega * change) * deltaTime
	local nextVelocity = (currentVelocity - omega * temp) * exp
	local nextValue = target + (change + temp) * exp

	if (originalTarget - current > 0) == (nextValue > originalTarget) then
		nextValue = originalTarget
		nextVelocity = 0
	end

	return nextValue, nextVelocity
end

local function smoothDampVector3(
	current: Vector3,
	target: Vector3,
	currentVelocity: Vector3,
	smoothTime: number,
	maxSpeed: number,
	deltaTime: number
): (Vector3, Vector3)
	local x, vx = smoothDampNumber(current.X, target.X, currentVelocity.X, smoothTime, maxSpeed, deltaTime)
	local y, vy = smoothDampNumber(current.Y, target.Y, currentVelocity.Y, smoothTime, maxSpeed, deltaTime)
	local z, vz = smoothDampNumber(current.Z, target.Z, currentVelocity.Z, smoothTime, maxSpeed, deltaTime)

	return Vector3.new(x, y, z), Vector3.new(vx, vy, vz)
end

function CameraController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._drone = nil
	self._camera = Workspace.CurrentCamera
	self._controls = nil
	self._touchGui = nil
	self._cameraHeight = GameConstants.Camera.Height
	self._targetCameraHeight = GameConstants.Camera.Height
	self._focusPosition = getFallbackFocus()
	self._renderPosition = self._focusPosition
	self._renderVelocity = ZERO_VECTOR
	self._zoomVelocity = 0
	self._trackedTouches = {}
	self._trackedTouchCount = 0
	self._lastPinchDistance = nil
	self._lastSentVelocity = ZERO_VECTOR
	self._lastSendTime = 0
	self._lastStepTime = os.clock()
	self._resolveVersion = 0
	self._moveState = {
		Forward = false,
		Backward = false,
		Left = false,
		Right = false,
	}

	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
	end))
end

function CameraController:KnitStart()
	self._gameService = Knit.GetService("GameService")

	self._trove:Add(self._gameService.DroneAssigned:Connect(function(drone: BasePart?, position: Vector3?, _droneName: string?)
		if typeof(position) == "Vector3" then
			self._focusPosition = position
		end

		self:_setDrone(drone)
	end))

	self._trove:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType == Enum.UserInputType.Touch then
			self:_trackTouch(input)
			return
		end

		self:_setInput(input.KeyCode, true)
	end))

	self._trove:Add(UserInputService.InputChanged:Connect(function(input: InputObject, _gameProcessedEvent: boolean)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self:_applyZoomDelta(-input.Position.Z * GameConstants.Camera.ZoomStep)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			self:_updateTouch(input)
		end
	end))

	self._trove:Add(UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:_untrackTouch(input)
			return
		end

		self:_setInput(input.KeyCode, false)
	end))

	self._trove:Add(RunService.RenderStepped:Connect(function()
		self:_step()
	end))

	local assignedDrone = self._gameService:GetAssignedDrone()
	if assignedDrone ~= nil then
		self:_setDrone(assignedDrone)
	end

	local assignedSnapshot = self._gameService:GetAssignedDroneSnapshot()
	if assignedSnapshot ~= nil and typeof(assignedSnapshot.Position) == "Vector3" then
		self._focusPosition = assignedSnapshot.Position
	end

	self:_bindNativeControls()
	self:_resolveDroneFromWorkspace()
end

function CameraController:_setDrone(drone: BasePart?)
	if typeof(drone) ~= "Instance" or not drone:IsA("BasePart") then
		return
	end

	self._drone = drone
	self._focusPosition = drone.Position
	self._renderPosition = self._focusPosition
	self._renderVelocity = ZERO_VECTOR
end

function CameraController:_resolveDroneFromWorkspace()
	self._resolveVersion += 1
	local resolveVersion = self._resolveVersion
	local droneName = GameConstants.Drone.NamePrefix .. tostring(LOCAL_PLAYER.UserId)

	task.spawn(function()
		local droneFolder = Workspace:WaitForChild(GameConstants.Drone.FolderName, 10)
		if self._destroyed or self._resolveVersion ~= resolveVersion then
			return
		end

		if droneFolder == nil then
			warn(("[CameraController] Missing workspace drone folder %s"):format(GameConstants.Drone.FolderName))
			return
		end

		local drone = droneFolder:FindFirstChild(droneName)
		if self._destroyed or self._resolveVersion ~= resolveVersion then
			return
		end

		if drone ~= nil then
			self:_setDrone(drone :: BasePart)
			return
		end

		self._trove:Add(droneFolder.ChildAdded:Connect(function(child: Instance)
			if self._destroyed or self._resolveVersion ~= resolveVersion then
				return
			end

			if child.Name == droneName and child:IsA("BasePart") then
				self:_setDrone(child)
			end
		end))
	end)
end

function CameraController:_bindNativeControls()
	task.spawn(function()
		local playerScripts = LOCAL_PLAYER:WaitForChild("PlayerScripts", 10)
		if self._destroyed or playerScripts == nil then
			return
		end

		local playerModule = playerScripts:WaitForChild("PlayerModule", 10)
		if self._destroyed or playerModule == nil then
			return
		end

		local ok, module = pcall(require, playerModule)
		if not ok or type(module) ~= "table" or type(module.GetControls) ~= "function" then
			warn("[CameraController] Native PlayerModule controls unavailable")
			return
		end

		self._controls = module:GetControls()
		if self._controls ~= nil and type(self._controls.Enable) == "function" then
			self._controls:Enable(true)
		end

		self:_watchNativeTouchGui()
	end)
end

function CameraController:_watchNativeTouchGui()
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return
	end

	local function bindTouchGui(touchGui: Instance)
		if self._touchGui ~= nil or not touchGui:IsA("ScreenGui") then
			return
		end

		self._touchGui = touchGui
		self._touchGui.Enabled = true

		self._trove:Add(self._touchGui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if self._touchGui ~= nil and not self._touchGui.Enabled then
				self._touchGui.Enabled = true
			end
		end))
	end

	local touchGui = playerGui:FindFirstChild("TouchGui")
	if touchGui ~= nil then
		bindTouchGui(touchGui)
	end

	self._trove:Add(playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == "TouchGui" then
			bindTouchGui(child)
		end
	end))
end

function CameraController:_setInput(keyCode: Enum.KeyCode, isDown: boolean)
	local moveKey = MOVEMENT_KEYS[keyCode]
	if moveKey == nil then
		return
	end

	self._moveState[moveKey] = isDown
end

function CameraController:_trackTouch(input: InputObject)
	if self._trackedTouches[input] ~= nil then
		return
	end

	self._trackedTouches[input] = Vector2.new(input.Position.X, input.Position.Y)
	self._trackedTouchCount += 1
	self:_refreshPinchDistance()
end

function CameraController:_updateTouch(input: InputObject)
	if self._trackedTouches[input] == nil then
		return
	end

	self._trackedTouches[input] = Vector2.new(input.Position.X, input.Position.Y)

	local pinchDistance = self:_getPinchDistance()
	if pinchDistance == nil then
		return
	end

	if self._lastPinchDistance ~= nil then
		local delta = pinchDistance - self._lastPinchDistance
		self:_applyZoomDelta(delta * GameConstants.Camera.PinchZoomStudsPerPixel)
	end

	self._lastPinchDistance = pinchDistance
end

function CameraController:_untrackTouch(input: InputObject)
	if self._trackedTouches[input] == nil then
		return
	end

	self._trackedTouches[input] = nil
	self._trackedTouchCount -= 1
	self:_refreshPinchDistance()
end

function CameraController:_getPinchDistance(): number?
	if self._trackedTouchCount < 2 then
		return nil
	end

	local firstPosition = nil
	local secondPosition = nil

	for _, position in self._trackedTouches do
		if firstPosition == nil then
			firstPosition = position
		else
			secondPosition = position
			break
		end
	end

	if firstPosition == nil or secondPosition == nil then
		return nil
	end

	return (firstPosition - secondPosition).Magnitude
end

function CameraController:_refreshPinchDistance()
	self._lastPinchDistance = self:_getPinchDistance()
end

function CameraController:_applyZoomDelta(deltaHeight: number)
	self._targetCameraHeight = math.clamp(
		self._targetCameraHeight + deltaHeight,
		GameConstants.Camera.ZoomMinHeight,
		GameConstants.Camera.ZoomMaxHeight
	)
end

function CameraController:_getDesiredVelocity(): Vector3
	if self._controls ~= nil then
		local moveVector = self._controls:GetMoveVector()
		local joystickDirection = Vector3.new(moveVector.X, 0, moveVector.Z)

		if joystickDirection.Magnitude > GameConstants.Camera.MovementDeadzone then
			return joystickDirection.Unit * GameConstants.Camera.Speed
		end
	end

	local x = 0
	local z = 0

	if self._moveState.Forward then
		z -= 1
	end

	if self._moveState.Backward then
		z += 1
	end

	if self._moveState.Left then
		x -= 1
	end

	if self._moveState.Right then
		x += 1
	end

	local direction = Vector3.new(x, 0, z)
	if direction.Magnitude <= 0 then
		return ZERO_VECTOR
	end

	return direction.Unit * GameConstants.Camera.Speed
end

function CameraController:_smoothVelocity(targetVelocity: Vector3, deltaTime: number): Vector3
	if targetVelocity.Magnitude <= GameConstants.Camera.MovementDeadzone then
		return ZERO_VECTOR
	end

	return targetVelocity
end

function CameraController:_sendVelocityIfNeeded(velocity: Vector3)
	local now = os.clock()
	local elapsed = now - self._lastSendTime
	local isStopRequest = velocity.Magnitude <= GameConstants.Camera.MovementDeadzone
	local wasMoving = self._lastSentVelocity.Magnitude > GameConstants.Camera.MovementDeadzone

	if vectorsClose(velocity, self._lastSentVelocity) and elapsed < GameConstants.Camera.VelocitySendInterval then
		return
	end

	if not (isStopRequest and wasMoving) and elapsed < GameConstants.Camera.VelocitySendInterval then
		return
	end

	self._lastSentVelocity = if isStopRequest then ZERO_VECTOR else velocity
	self._lastSendTime = now
	self._gameService.DroneVelocityRequested:Fire(self._lastSentVelocity)
end

function CameraController:_updateFocusPosition(velocity: Vector3, deltaTime: number)
	self._focusPosition = clampFocusPosition(self._focusPosition + velocity * deltaTime)

	if (self._renderPosition - self._focusPosition).Magnitude <= GameConstants.Camera.RenderSnapDistance then
		self._renderPosition = self._focusPosition
		self._renderVelocity = ZERO_VECTOR
		return
	end

	self._renderPosition, self._renderVelocity = smoothDampVector3(
		self._renderPosition,
		self._focusPosition,
		self._renderVelocity,
		GameConstants.Camera.RenderSmoothTime,
		GameConstants.Camera.RenderMaxSpeed,
		deltaTime
	)
end

function CameraController:_updateCamera(deltaTime: number)
	if self._camera == nil then
		return
	end

	self._cameraHeight, self._zoomVelocity = smoothDampNumber(
		self._cameraHeight,
		self._targetCameraHeight,
		self._zoomVelocity,
		GameConstants.Camera.ZoomSmoothTime,
		GameConstants.Camera.ZoomMaxSpeed,
		deltaTime
	)

	self._camera.CameraType = Enum.CameraType.Scriptable
	self._camera.CFrame = getTopDownCameraCFrame(self._renderPosition, self._cameraHeight)
end

function CameraController:_step()
	if self._destroyed then
		return
	end

	local now = os.clock()
	local deltaTime = math.clamp(now - self._lastStepTime, 0, MAX_DELTA_TIME)
	self._lastStepTime = now

	local desiredVelocity = self:_getDesiredVelocity()
	local smoothedVelocity = self:_smoothVelocity(desiredVelocity, deltaTime)

	self:_updateFocusPosition(smoothedVelocity, deltaTime)
	self:_sendVelocityIfNeeded(smoothedVelocity)
	self:_updateCamera(deltaTime)
end

function CameraController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
end

return CameraController
