local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local Panel = require(script.Parent:WaitForChild("Panel"))
local Text = require(script.Parent:WaitForChild("Text"))

local colors = UITheme.Colors
local spacing = UITheme.Spacing
local textSizes = UITheme.TextSizes
local transparency = UITheme.Transparency

local function StatTile(props)
	local compact = props.compact == true

	return React.createElement(Panel, {
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = Enum.AutomaticSize.XY,
		backgroundColor = colors.PanelRaised,
		backgroundTransparency = transparency.PanelSoft,
		strokeColor = props.accent or colors.Stroke,
		strokeTransparency = transparency.StrokeSoft,
		radius = UITheme.Radii.Control,
		padding = {
			Y = if compact then spacing.Sm else spacing.Lg,
			X = if compact then spacing.Xl else spacing.Xs + spacing.Lg,
		},
		layout = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		gap = spacing.Xxs,
		children = {
			Label = React.createElement(Text, {
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				variant = "Label",
				Text = props.label or "",
				TextSize = if compact then textSizes.Tiny else textSizes.Small,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Value = React.createElement(Text, {
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				variant = "Value",
				Text = props.value or "",
				TextSize = if compact then textSizes.Button else textSizes.Value,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
end

return StatTile
