local SelectionConfig = {}

SelectionConfig.EntityTypes = table.freeze({
	Unit = "Unit",
	Building = "Building",
	Nexo = "Nexo",
	Hex = "Hex",
})

SelectionConfig.InteractionStates = table.freeze({
	Idle = "Idle",
	Hovering = "Hovering",
	AreaSelecting = "AreaSelecting",
	BuildingSelected = "BuildingSelected",
	NexoBuildMenuOpen = "NexoBuildMenuOpen",
	BuildPlacement = "BuildPlacement",
})

SelectionConfig.AllowedTransitions = table.freeze({
	Idle = table.freeze({
		Hovering = true,
		AreaSelecting = true,
		BuildingSelected = true,
		NexoBuildMenuOpen = true,
		BuildPlacement = true,
	}),
	Hovering = table.freeze({
		Idle = true,
		AreaSelecting = true,
		BuildingSelected = true,
		NexoBuildMenuOpen = true,
		BuildPlacement = true,
	}),
	AreaSelecting = table.freeze({
		Idle = true,
		Hovering = true,
	}),
	BuildingSelected = table.freeze({
		Idle = true,
		Hovering = true,
		NexoBuildMenuOpen = true,
		BuildPlacement = true,
	}),
	NexoBuildMenuOpen = table.freeze({
		Idle = true,
		Hovering = true,
		BuildPlacement = true,
	}),
	BuildPlacement = table.freeze({
		Idle = true,
		Hovering = true,
		NexoBuildMenuOpen = true,
	}),
})

SelectionConfig.MaxSelectedUnits = 64
SelectionConfig.AreaDragThresholdPixels = 6
SelectionConfig.SelectionRayDistance = 500
SelectionConfig.ProjectedNexoPickRadiusPixels = 48
SelectionConfig.MobileAreaModeLabel = "AREA"

SelectionConfig.Panel = table.freeze({
	Width = 352,
	BottomOffset = 28,
	RightOffset = 36,
	MobileRightOffset = 18,
	MinTouchSize = 44,
})

SelectionConfig.Visuals = table.freeze({
	HoverFillTransparency = 1,
	HoverOutlineTransparency = 0.2,
	SelectedFillTransparency = 0.82,
	SelectedOutlineTransparency = 0.02,
	InvalidFillTransparency = 0.92,
	InvalidOutlineTransparency = 0.18,
	AreaFillTransparency = 0.86,
	AreaStrokeTransparency = 0.05,
	UnitColor = Color3.fromRGB(232, 235, 228),
	BuildingColor = Color3.fromRGB(205, 159, 68),
	NexoColor = Color3.fromRGB(63, 176, 92),
	EnemyColor = Color3.fromRGB(188, 61, 58),
	AreaColor = Color3.fromRGB(205, 159, 68),
})

SelectionConfig.AssignedNexoColors = table.freeze({
	Color3.fromRGB(63, 176, 92),
	Color3.fromRGB(205, 159, 68),
	Color3.fromRGB(86, 151, 215),
	Color3.fromRGB(205, 86, 126),
	Color3.fromRGB(118, 198, 180),
	Color3.fromRGB(214, 104, 65),
})

return table.freeze(SelectionConfig)
