local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local GridConfig = require(Shared:WaitForChild("Constants"):WaitForChild("GridConfig"))
local HexUtils = require(Shared:WaitForChild("Utils"):WaitForChild("HexUtils"))

type BuildTarget = {
	q: number,
	r: number,
	socketName: string,
	socketPosition: Vector3,
	hexPart: BasePart,
}

local BuildController = Knit.CreateController({
	Name = "BuildController",
})

local MAX_RAY_DISTANCE = 500

local function findTaggedHexPart(instance: Instance?): BasePart?
	local current = instance

	while current ~= nil and current ~= Workspace do
		if CollectionService:HasTag(current, GridConfig.BuildableHexTag) then
			return if current:IsA("BasePart") then current else nil
		end

		current = current.Parent
	end

	return nil
end

local function getSocketPosition(socketPositions, socketName: string): Vector3
	if socketName == "Center" then
		return socketPositions.Center
	end

	local edgeIndex = tonumber(string.match(socketName, "^Edge([1-6])$"))
	if edgeIndex == nil then
		return socketPositions.Center
	end

	return socketPositions.Edge[edgeIndex]
end

function BuildController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._camera = Workspace.CurrentCamera
	self._buildService = nil
	self._selectedBuildingType = nil
	self._rotation = 0
	self._target = nil

	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
	end))
end

function BuildController:KnitStart()
	self._buildService = Knit.GetService("BuildService")

	self._trove:Add(RunService.RenderStepped:Connect(function()
		self:_updateTarget()
	end))

	self._trove:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:RequestBuildAtCurrentTarget()
		end
	end))
end

function BuildController:SetSelectedBuildingType(buildingType: string?)
	self._selectedBuildingType = buildingType
end

function BuildController:SetRotation(rotation: number)
	if typeof(rotation) ~= "number" or rotation ~= rotation or math.abs(rotation) == math.huge then
		return
	end

	self._rotation = rotation
end

function BuildController:GetCurrentTarget(): BuildTarget?
	return self._target
end

function BuildController:RequestBuildAtCurrentTarget(): { ok: boolean, reason: string? }
	if self._selectedBuildingType == nil or self._target == nil or self._buildService == nil then
		return { ok = false, reason = "NoTarget" }
	end

	local target = self._target :: BuildTarget

	return self._buildService:RequestBuild({
		q = target.q,
		r = target.r,
		socketName = target.socketName,
		buildingType = self._selectedBuildingType,
		rotation = self._rotation,
	})
end

function BuildController:_getPointerPosition(): Vector2?
	local mouseLocation = UserInputService:GetMouseLocation()
	if mouseLocation.X >= 0 and mouseLocation.Y >= 0 then
		return mouseLocation
	end

	local touches = UserInputService:GetTouches()
	local firstTouch = touches[1]
	if firstTouch == nil then
		return nil
	end

	return Vector2.new(firstTouch.Position.X, firstTouch.Position.Y)
end

function BuildController:_updateTarget()
	if self._camera == nil then
		self._target = nil
		return
	end

	local pointerPosition = self:_getPointerPosition()
	if pointerPosition == nil then
		self._target = nil
		return
	end

	local ray = self._camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE)
	if result == nil then
		self._target = nil
		return
	end

	local hexPart = findTaggedHexPart(result.Instance)
	if hexPart == nil then
		self._target = nil
		return
	end

	local coord = HexUtils.getHexCoordFromPart(hexPart, GridConfig)
	local hexY = HexUtils.getHexSurfaceY(hexPart)
	local socketName = HexUtils.getNearestSocket(result.Position, coord.q, coord.r, hexY, GridConfig)
	local socketPositions = HexUtils.getSocketPositions(coord.q, coord.r, hexY, GridConfig)

	self._target = {
		q = coord.q,
		r = coord.r,
		socketName = socketName,
		socketPosition = getSocketPosition(socketPositions, socketName),
		hexPart = hexPart,
	}
end

function BuildController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
end

return BuildController
