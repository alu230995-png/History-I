local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local NexoBuildMenu = require(script.Parent:WaitForChild("index"))

local sizes = UITheme.Sizes

local controls = {
	mobile = false,
	gold = 650,
}

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = controls,
	story = function(props)
		local viewportSize = if props.controls.mobile
			then Vector2.new(sizes.NexoBuildCompactMaxWidth, sizes.NexoBuildCompactMaxHeight + sizes.ButtonWideWidth)
			else Vector2.new(1280, 720)

		return React.createElement(NexoBuildMenu, {
			visible = true,
			resources = {
				Gold = props.controls.gold,
			},
			viewportSize = viewportSize,
			isMobile = props.controls.mobile,
			onClose = function() end,
			onSelectBuilding = function() end,
		})
	end,
}
