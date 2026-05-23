local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local MatchHud = require(script.Parent:WaitForChild("index"))

local colors = UITheme.Colors

local controls = {
	mobile = false,
	gold = 1200,
	nexoHp = 640,
}

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = controls,
	story = function(props)
		local localUserId = 101

		return React.createElement(MatchHud, {
			resources = {
				Gold = props.controls.gold,
				PopulationUsed = 18,
				PopulationCap = 40,
			},
			clock = {
				day = 14,
				month = 6,
				year = 1908,
			},
			nexoSnapshot = {
				nexos = {
					{
						takenByUserId = localUserId,
						displayName = "Nexo Norte",
						hp = props.controls.nexoHp,
						maxHp = 1000,
					},
				},
			},
			diplomacySnapshot = {
				colors = {
					colors.Green,
					colors.Amber,
					colors.Red,
				},
				alliances = {
					{
						colorIndex = 1,
						members = { localUserId },
					},
				},
			},
			playerCards = {
				{ userId = localUserId, name = "Player", thumbnail = UITheme.Assets.PlaceholderIcon },
				{ userId = 202, name = "Ally", thumbnail = UITheme.Assets.PlaceholderIcon },
				{ userId = 303, name = "Enemy", thumbnail = UITheme.Assets.PlaceholderIcon },
			},
			localUserId = localUserId,
			viewportSize = if props.controls.mobile then Vector2.new(390, 720) else Vector2.new(1280, 720),
		})
	end,
}
