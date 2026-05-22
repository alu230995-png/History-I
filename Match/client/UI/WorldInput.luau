local WorldInput = {}

WorldInput.BehaviorAttribute = "WorldInputBehavior"

WorldInput.Behaviors = table.freeze({
	Block = "Block",
	PassThrough = "PassThrough",
})

local function getBehavior(instance: Instance?): string?
	local current = instance

	while current ~= nil do
		local behavior = current:GetAttribute(WorldInput.BehaviorAttribute)
		if behavior == WorldInput.Behaviors.Block or behavior == WorldInput.Behaviors.PassThrough then
			return behavior
		end

		if current:IsA("ScreenGui") then
			return nil
		end

		current = current.Parent
	end

	return nil
end

local function blocksWorldInput(guiObject: GuiObject): boolean
	local behavior = getBehavior(guiObject)
	if behavior == WorldInput.Behaviors.PassThrough then
		return false
	end

	if behavior == WorldInput.Behaviors.Block then
		return true
	end

	return guiObject:IsA("GuiButton") or guiObject:IsA("TextBox") or guiObject.Active
end

function WorldInput.IsPointerBlocked(playerGui: PlayerGui?, pointerPosition: Vector2): boolean
	if playerGui == nil then
		return false
	end

	for _, guiObject in playerGui:GetGuiObjectsAtPosition(pointerPosition.X, pointerPosition.Y) do
		if blocksWorldInput(guiObject) then
			return true
		end
	end

	return false
end

return WorldInput
