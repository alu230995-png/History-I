local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local SelectionConfig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("SelectionConfig"))
local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local strokes = UITheme.Strokes
local visuals = SelectionConfig.Visuals

local function SelectionAreaOverlay(props)
	local rect = props.rect
	if rect == nil then
		return nil
	end

	return React.createElement("Frame", {
		Position = UDim2.fromOffset(math.floor(rect.Min.X), math.floor(rect.Min.Y)),
		Size = UDim2.fromOffset(math.floor(rect.Size.X), math.floor(rect.Size.Y)),
		BackgroundColor3 = visuals.AreaColor,
		BackgroundTransparency = visuals.AreaFillTransparency,
		BorderSizePixel = 0,
		Active = false,
	}, {
		Stroke = React.createElement("UIStroke", {
			Color = visuals.AreaColor,
			Thickness = px(strokes.Thin),
			Transparency = visuals.AreaStrokeTransparency,
		}),
	})
end

return SelectionAreaOverlay
