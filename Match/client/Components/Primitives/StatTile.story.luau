local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local StatTile = require(script.Parent:WaitForChild("StatTile"))

local colors = UITheme.Colors
local spacing = UITheme.Spacing

local controls = {
	compact = false,
	value = "1200",
}

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = controls,
	story = function(props)
		return React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = UITheme.Transparency.Clear,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, UITheme.sp(spacing.Lg)),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Money = React.createElement(StatTile, {
				LayoutOrder = 1,
				label = "DINERO",
				value = props.controls.value,
				accent = colors.Amber,
				compact = props.controls.compact,
			}),
			Population = React.createElement(StatTile, {
				LayoutOrder = 2,
				label = "POBLACION",
				value = "12 / 30",
				accent = colors.Green,
				compact = props.controls.compact,
			}),
		})
	end,
}
