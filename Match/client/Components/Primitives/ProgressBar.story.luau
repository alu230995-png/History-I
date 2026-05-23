local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local ProgressBar = require(script.Parent:WaitForChild("ProgressBar"))

local colors = UITheme.Colors
local sizes = UITheme.Sizes

local controls = {
	progress = 0.65,
	ready = false,
}

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = controls,
	story = function(props)
		return React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(UITheme.sp(sizes.PanelWidth), UITheme.sp(sizes.HealthTrack)),
			BackgroundTransparency = UITheme.Transparency.Clear,
		}, {
			Bar = React.createElement(ProgressBar, {
				Size = UDim2.fromScale(1, 1),
				progress = props.controls.progress,
				fillColor = if props.controls.ready then colors.Green else colors.Amber,
			}),
		})
	end,
}
