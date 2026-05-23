local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))

local SelectionActionPanel = require(script.Parent:WaitForChild("index"))

local controls = {
	mobile = false,
	selectedBuilding = true,
	editable = true,
	queueFull = false,
	units = true,
}

local function mockUnits()
	return {
		{ UnitId = "u1", UnitType = "InfanteriaLigera" },
		{ UnitId = "u2", UnitType = "Tanque" },
		{ UnitId = "u3", UnitType = "InfanteriaLigera" },
		{ UnitId = "u4", UnitType = "Tanque" },
		{ UnitId = "u5", UnitType = "InfanteriaLigera" },
		{ UnitId = "u6", UnitType = "Tanque" },
		{ UnitId = "u7", UnitType = "InfanteriaLigera" },
	}
end

local function mockQueue(full: boolean)
	return {
		Count = if full then 4 else 2,
		Capacity = 4,
		Entries = {
			{ UnitType = "InfanteriaLigera", Progress = 0.7, Ready = false },
			{ UnitType = "Tanque", Progress = if full then 1 else 0.25, Ready = full },
			if full then { UnitType = "InfanteriaLigera", Progress = 0.4, Ready = false } else nil,
			if full then { UnitType = "Tanque", Progress = 0.1, Ready = false } else nil,
		},
	}
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = controls,
	story = function(props)
		return React.createElement(SelectionActionPanel, {
			visible = true,
			units = if props.controls.units then mockUnits() else {},
			building = if props.controls.selectedBuilding
				then {
					BuildingId = "story_barracks",
					BuildingType = "Cuartel",
					HP = 640,
					MaxHP = 900,
					CanEdit = props.controls.editable,
				}
				else nil,
			queue = mockQueue(props.controls.queueFull),
			canOpenNexoBuild = true,
			areaModeArmed = false,
			viewportSize = if props.controls.mobile then Vector2.new(390, 720) else Vector2.new(1280, 720),
			isMobile = props.controls.mobile,
			onArmArea = function() end,
			onOpenNexoBuild = function() end,
			onClear = function() end,
			onDeselectUnit = function() end,
			onMoveBuilding = function() end,
			onDestroyBuilding = function() end,
			onQueueUnit = function() end,
		})
	end,
}
