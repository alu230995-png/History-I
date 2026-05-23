local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelectionConfig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("SelectionConfig"))

local AreaSelector = {}
AreaSelector.__index = AreaSelector

local function getRect(startPosition: Vector2, currentPosition: Vector2)
	local minX = math.min(startPosition.X, currentPosition.X)
	local minY = math.min(startPosition.Y, currentPosition.Y)
	local maxX = math.max(startPosition.X, currentPosition.X)
	local maxY = math.max(startPosition.Y, currentPosition.Y)

	return {
		Min = Vector2.new(minX, minY),
		Max = Vector2.new(maxX, maxY),
		Size = Vector2.new(maxX - minX, maxY - minY),
	}
end

function AreaSelector.new()
	local self = setmetatable({}, AreaSelector)
	self._armedTouch = false
	self._active = false
	self._dragging = false
	self._inputType = nil
	self._inputObject = nil
	self._startPosition = nil
	self._currentPosition = nil
	return self
end

function AreaSelector:ArmTouch()
	self._armedTouch = true
end

function AreaSelector:IsTouchArmed(): boolean
	return self._armedTouch
end

function AreaSelector:CanBegin(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton3
		or (input.UserInputType == Enum.UserInputType.Touch and self._armedTouch)
end

function AreaSelector:Begin(input: InputObject, pointerPosition: Vector2)
	if not self:CanBegin(input) then
		return false
	end

	self._active = true
	self._dragging = false
	self._inputType = input.UserInputType
	self._inputObject = input
	self._startPosition = pointerPosition
	self._currentPosition = pointerPosition
	if input.UserInputType == Enum.UserInputType.Touch then
		self._armedTouch = false
	end
	return true
end

function AreaSelector:Update(pointerPosition: Vector2)
	if not self._active or self._startPosition == nil then
		return false
	end

	self._currentPosition = pointerPosition
	if (pointerPosition - self._startPosition).Magnitude >= SelectionConfig.AreaDragThresholdPixels then
		self._dragging = true
	end
	return self._dragging
end

function AreaSelector:MatchesInput(input: InputObject): boolean
	if not self._active then
		return false
	end

	return self._inputObject == input
end

function AreaSelector:Finish()
	local rect = self:GetRect()
	local wasDragging = self._dragging
	self:Cancel()
	return if wasDragging then rect else nil
end

function AreaSelector:Cancel()
	self._active = false
	self._dragging = false
	self._inputType = nil
	self._inputObject = nil
	self._startPosition = nil
	self._currentPosition = nil
end

function AreaSelector:IsActive(): boolean
	return self._active
end

function AreaSelector:IsDragging(): boolean
	return self._dragging
end

function AreaSelector:GetRect()
	if self._startPosition == nil or self._currentPosition == nil then
		return nil
	end

	return getRect(self._startPosition, self._currentPosition)
end

function AreaSelector:Destroy()
	self:Cancel()
	self._armedTouch = false
end

return AreaSelector
