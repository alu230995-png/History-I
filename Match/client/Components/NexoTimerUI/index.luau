local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local colors = UITheme.Colors

local function NexoTimerUI(props)
	local visible = props.visible == true
	local hasMessage = typeof(props.assignmentMessage) == "string" and props.assignmentMessage ~= ""

	if not visible and not hasMessage then
		return nil
	end

	local seconds = if typeof(props.segundosRestantes) == "number"
		then math.max(0, math.floor(props.segundosRestantes))
		else 0

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, px(18)),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(4)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if visible then colors.Amber else colors.Green,
			Thickness = px(1),
			Transparency = 0.1,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(8)),
			PaddingBottom = UDim.new(0, px(8)),
			PaddingLeft = UDim.new(0, px(14)),
			PaddingRight = UDim.new(0, px(14)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(3)),
		}),
		Title = React.createElement("TextLabel", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = if visible then "SELECCION DE NEXO" else "NEXO ASIGNADO",
			TextColor3 = colors.Text,
			TextSize = px(12),
		}),
		Timer = React.createElement("TextLabel", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = if visible then `00:{string.format("%02d", seconds)}` else props.assignmentMessage,
			TextColor3 = if visible then colors.Amber else colors.Green,
			TextSize = if visible then px(20) else px(14),
			TextWrapped = true,
		}, {
			Width = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(px(360), px(44)),
			}),
		}),
	})
end

return NexoTimerUI
