local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local TacticalButton = require(script.Parent:WaitForChild("TacticalButton"))

local colors = UITheme.Colors
local sizes = UITheme.Sizes
local spacing = UITheme.Spacing
local transparency = UITheme.Transparency

local controls = {
	label = "CONFIRMAR",
	enabled = true,
	wide = true,
}

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = controls,
	story = function(props)
		return React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = colors.Panel,
			BackgroundTransparency = transparency.Clear,
			BorderSizePixel = 0,
		}, {
			Button = React.createElement(TacticalButton, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				width = if props.controls.wide then sizes.ButtonBuildWidth else sizes.ButtonWideWidth,
				height = sizes.ButtonLargeHeight,
				label = props.controls.label,
				accent = colors.Green,
				enabled = props.controls.enabled,
				paddingX = spacing.Loose,
			}),
		})
	end,
}
