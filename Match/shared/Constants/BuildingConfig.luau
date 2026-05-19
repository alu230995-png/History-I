local BuildingConfig = {}

BuildingConfig.StartingResources = table.freeze({
	Gold = 500,
	PopulationUsed = 0,
	PopulationCap = 10,
})

BuildingConfig.PlacedFolderName = "PlacedBuildings"
BuildingConfig.PreviewFolderName = "BuildPreviews"
BuildingConfig.PlacementModes = table.freeze({
	Center = "Center",
	Edge = "Edge",
})
BuildingConfig.HealthBillboardName = "BuildingHealthBillboard"

BuildingConfig.Shadow = table.freeze({
	ValidColor = Color3.fromRGB(63, 176, 92),
	InvalidColor = Color3.fromRGB(188, 61, 58),
	Transparency = 0.45,
	VerticalOffset = 0.08,
})

BuildingConfig.Buildings = table.freeze({
	Casa = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Casa",
		DisplayName = "CASA",
		PlacementMode = "Center",
		Gold = 50,
		Population = 0,
		PopulationCapBonus = 4,
		HP = 150,
		Interactable = false,
		BuildTime = 8,
		AllowedSockets = table.freeze({
			Center = true,
		}),
		RotationLocked = false,
		Footprint = Vector3.new(5, 5, 5),
		PivotOffset = Vector3.new(0, 2.5, 0),
	}),

	Aserradero = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Aserradero",
		DisplayName = "ASERRADERO",
		PlacementMode = "Center",
		Gold = 75,
		Population = 2,
		PopulationCapBonus = 0,
		HP = 100,
		Interactable = false,
		BuildTime = 10,
		AllowedSockets = table.freeze({
			Center = true,
		}),
		RotationLocked = false,
		Footprint = Vector3.new(5, 5, 5),
		PivotOffset = Vector3.new(0, 2.5, 0),
	}),

	Cuartel = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Cuartel",
		DisplayName = "CUARTEL",
		PlacementMode = "Center",
		Gold = 120,
		Population = 3,
		PopulationCapBonus = 0,
		HP = 200,
		Interactable = false,
		BuildTime = 15,
		AllowedSockets = table.freeze({
			Center = true,
		}),
		RotationLocked = false,
		Footprint = Vector3.new(6, 6, 6),
		PivotOffset = Vector3.new(0, 3, 0),
	}),

	Artilleria = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Artilleria",
		DisplayName = "ARTILLERIA",
		PlacementMode = "Edge",
		Gold = 200,
		Population = 5,
		PopulationCapBonus = 0,
		HP = 80,
		Interactable = false,
		BuildTime = 20,
		AllowedSockets = table.freeze({
			Edge1 = true,
			Edge2 = true,
			Edge3 = true,
			Edge4 = true,
			Edge5 = true,
			Edge6 = true,
		}),
		RotationLocked = false,
		ModelYawOffset = 0,
		Footprint = Vector3.new(4, 4, 4),
		PivotOffset = Vector3.new(0, 2, 0),
	}),

	Pared = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Pared",
		DisplayName = "PARED",
		PlacementMode = "Edge",
		Gold = 25,
		Population = 0,
		PopulationCapBonus = 0,
		HP = 180,
		Interactable = false,
		BuildTime = 4,
		AllowedSockets = table.freeze({
			Edge1 = true,
			Edge2 = true,
			Edge3 = true,
			Edge4 = true,
			Edge5 = true,
			Edge6 = true,
		}),
		RotationLocked = false,
		ModelYawOffset = 0,
		Footprint = Vector3.new(5, 4, 1),
		PivotOffset = Vector3.new(0, 2, 0),
	}),
})

BuildingConfig.Aliases = table.freeze({
	House = "Casa",
	Sawmill = "Aserradero",
	Barracks = "Cuartel",
	Artillery = "Artilleria",
	Wall = "Pared",
})

function BuildingConfig.NormalizeBuildingType(buildingType: any): string?
	if typeof(buildingType) ~= "string" or buildingType == "" then
		return nil
	end

	if BuildingConfig.Buildings[buildingType] ~= nil then
		return buildingType
	end

	return BuildingConfig.Aliases[buildingType]
end

function BuildingConfig.GetBuilding(buildingType: any): any?
	local normalized = BuildingConfig.NormalizeBuildingType(buildingType)
	if normalized == nil then
		return nil
	end

	return BuildingConfig.Buildings[normalized]
end

function BuildingConfig.GetPlacementMode(buildingType: any): string?
	local definition = BuildingConfig.GetBuilding(buildingType)
	if definition == nil then
		return nil
	end

	return definition.PlacementMode or BuildingConfig.PlacementModes.Center
end

function BuildingConfig.IsEdgeSocket(socketName: any): boolean
	return typeof(socketName) == "string" and string.match(socketName, "^Edge[1-6]$") ~= nil
end

function BuildingConfig.IsSocketValidForPlacementMode(placementMode: string, socketName: string): boolean
	if placementMode == BuildingConfig.PlacementModes.Edge then
		return BuildingConfig.IsEdgeSocket(socketName)
	end

	return socketName == "Center"
end

function BuildingConfig.IsSocketAllowed(buildingType: any, socketName: string): boolean
	local definition = BuildingConfig.GetBuilding(buildingType)
	if definition == nil then
		return false
	end

	local placementMode = definition.PlacementMode or BuildingConfig.PlacementModes.Center
	if not BuildingConfig.IsSocketValidForPlacementMode(placementMode, socketName) then
		return false
	end

	return definition.AllowedSockets[socketName] == true
end

function BuildingConfig.CanRotate(buildingType: any): boolean
	local definition = BuildingConfig.GetBuilding(buildingType)
	return definition ~= nil and definition.RotationLocked ~= true
end

return table.freeze(BuildingConfig)
