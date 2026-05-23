local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local Panel = require(script.Parent:WaitForChild("Panel"))
local Text = require(script.Parent:WaitForChild("Text"))

local colors = UITheme.Colors
local sizes = UITheme.Sizes
local spacing = UITheme.Spacing
local textSizes = UITheme.TextSizes

local controls = {
	accented = true,
}

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = controls,
	story = function(props)
		return React.createElement(Panel, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(UITheme.sp(sizes.PanelWidth), UITheme.sp(sizes.ButtonMediumWidth)),
			strokeColor = if props.controls.accented then colors.Amber else colors.Stroke,
			padding = spacing.Wide,
			layout = Enum.FillDirection.Vertical,
			gap = spacing.Lg,
			children = {
				Title = React.createElement(Text, {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, UITheme.sp(textSizes.Heading)),
					variant = "Title",
					Text = "PANEL TACTICO",
				}),
				Body = React.createElement(Text, {
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, UITheme.sp(textSizes.Timer)),
					variant = "Body",
					Text = "Tokens centralizados para color, padding, borde y texto.",
					TextWrapped = true,
				}),
			},
		})
	end,
}
