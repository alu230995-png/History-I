local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local Panel = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Panel"))
local Text = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Text"))

local px = UITheme.sp
local colors = UITheme.Colors
local sizes = UITheme.Sizes
local spacing = UITheme.Spacing
local textSizes = UITheme.TextSizes
local transparency = UITheme.Transparency

local function NexoTimerUI(props)
	local visible = props.visible == true
	local hasMessage = typeof(props.assignmentMessage) == "string" and props.assignmentMessage ~= ""

	if not visible and not hasMessage then
		return nil
	end

	local seconds = if typeof(props.segundosRestantes) == "number"
		then math.max(0, math.floor(props.segundosRestantes))
		else 0

	return React.createElement(Panel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, px(spacing.Sm)),
		AutomaticSize = Enum.AutomaticSize.XY,
		backgroundTransparency = 1,
		stroke = false,
		gradient = false,
		padding = {
			Y = spacing.Sm,
			X = spacing.Sm,
		},
		layout = Enum.FillDirection.Vertical,
		gap = spacing.Xs,
		Active = false,
		children = {
			Title = React.createElement(Text, {
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				variant = "Title",
				Text = if visible then "SELECCION DE NEXO" else "NEXO ASIGNADO",
				TextSize = textSizes.Button,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.4,
			}),
			Timer = React.createElement(Text, {
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				variant = "Value",
				Text = if visible then `00:{string.format("%02d", seconds)}` else props.assignmentMessage,
				TextColor3 = if visible then colors.Amber else colors.Green,
				TextSize = if visible then textSizes.Timer else textSizes.Body,
				TextWrapped = true,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.4,
			}, {
				Width = React.createElement("UISizeConstraint", {
					MaxSize = Vector2.new(px(sizes.NexoBuildCompactMaxWidth + spacing.Bottom), px(sizes.ButtonHeight)),
				}),
			}),
		},
	})
end

return NexoTimerUI
