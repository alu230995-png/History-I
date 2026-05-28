local PointerTracker = {}
PointerTracker.__index = PointerTracker

function PointerTracker.new(userInputService)
	local self = setmetatable({}, PointerTracker)
	self._userInputService = userInputService
	self._activeTouch = nil
	self._lastPointerPosition = nil
	return self
end

local function getInputPosition(input: InputObject): Vector2
	local position = Vector2.new(input.Position.X, input.Position.Y)
	return position
end

function PointerTracker:_getMousePosition(): Vector2?
	local mouseLocation = self._userInputService:GetMouseLocation()
	if mouseLocation.X >= 0 and mouseLocation.Y >= 0 then
		return mouseLocation
	end

	return nil
end

function PointerTracker:_getPreciseTouchPosition(input: InputObject): Vector2
	local mousePosition = self:_getMousePosition()
	return mousePosition or getInputPosition(input)
end

function PointerTracker:BeginInput(input: InputObject): Vector2?
	if input.UserInputType == Enum.UserInputType.Touch then
		if self._activeTouch ~= nil and self._activeTouch ~= input then
			return nil
		end

		self._activeTouch = input
		local position = self:_getPreciseTouchPosition(input)
		self._lastPointerPosition = position
		return position
	end

	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton3
	then
		local position = self:_getMousePosition()
		if position == nil then
			return nil
		end
		self._lastPointerPosition = position
		return position
	end

	return nil
end

function PointerTracker:UpdateInput(input: InputObject): Vector2?
	if input.UserInputType == Enum.UserInputType.Touch then
		if self._activeTouch ~= input then
			return nil
		end

		local position = self:_getPreciseTouchPosition(input)
		self._lastPointerPosition = position
		return position
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local position = self:_getMousePosition()
		if position == nil then
			return nil
		end
		self._lastPointerPosition = position
		return position
	end

	return nil
end

function PointerTracker:ClearTouch(input: InputObject?)
	if input == nil or input == self._activeTouch then
		self._activeTouch = nil
	end
end

function PointerTracker:GetPosition(): Vector2?
	if self._lastPointerPosition ~= nil then
		return self._lastPointerPosition
	end

	return self:_getMousePosition()
end

function PointerTracker:Destroy()
	self._userInputService = nil
	self._activeTouch = nil
	self._lastPointerPosition = nil
end

return PointerTracker
