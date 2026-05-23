local BuildingConfig = {}

local MatchEconomyConfig = require(script.Parent:WaitForChild("MatchEconomyConfig"))

BuildingConfig.StartingResources = MatchEconomyConfig.StartingResources

BuildingConfig.PlacedFolderName = "PlacedBuildings"
BuildingConfig.PreviewFolderName = "BuildPreviews"
BuildingConfig.PlacementModes = table.freeze({
	Center = "Center",
	Edge = "Edge",
})
BuildingConfig.Categories = table.freeze({
	Production = "Production",
	Military = "Military",
	Defense = "Defense",
})
BuildingConfig.HexTags = table.freeze({
	General = "GeneralBuildingHex",
	Special = "SpecialBuildingHex",
})
BuildingConfig.ConstructionStates = table.freeze({
	Pending = "Pending",
	Building = "Building",
	Complete = "Complete",
})
BuildingConfig.HealthBillboardName = "BuildingHealthBillboard"
BuildingConfig.ConstructionBillboardName = "ConstructionBillboard"
BuildingConfig.MenuOrder = table.freeze({
	"Casa",
	"Aserradero",
	"Cuartel",
	"Fabrica",
	"Pared",
})

BuildingConfig.Shadow = table.freeze({
	ValidColor = Color3.fromRGB(63, 176, 92),
	InvalidColor = Color3.fromRGB(188, 61, 58),
	ConstructionColor = Color3.fromRGB(64, 150, 255),
	Transparency = 0.45,
	ConstructionTransparency = 0.35,
	VerticalOffset = 0.08,
})

local CENTER_SOCKET = table.freeze({
	Center = true,
})

local EDGE_SOCKETS = table.freeze({
	Edge1 = true,
	Edge2 = true,
	Edge3 = true,
	Edge4 = true,
	Edge5 = true,
	Edge6 = true,
})

BuildingConfig.Buildings = table.freeze({
	Casa = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Casa",
		DisplayName = "CASA",
		Category = BuildingConfig.Categories.Defense,
		Enabled = true,
		RequiresBuilder = true,
		PlacementMode = "Center",
		Gold = 65,
		Limit = 4,
		Population = 0,
		PopulationCapBonus = 4,
		HP = 150,
		Interactable = false,
		BuildTime = 10,
		AllowedSockets = CENTER_SOCKET,
		RotationLocked = false,
		Footprint = Vector3.new(5, 5, 5),
		PivotOffset = Vector3.new(0, 2.5, 0),
		RequiredHexTag = BuildingConfig.HexTags.General,
	}),

	Aserradero = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Aserradero",
		ModelFallbackPath = "ReplicatedStorage/Assets/Buildings/Casa",
		DisplayName = "ASERRADERO",
		Category = BuildingConfig.Categories.Production,
		Enabled = true,
		RequiresBuilder = true,
		PlacementMode = "Center",
		Gold = 100,
		Limit = 2,
		Population = 3,
		PopulationCapBonus = 0,
		HP = 100,
		Interactable = false,
		BuildTime = 13,
		AllowedSockets = CENTER_SOCKET,
		RotationLocked = false,
		Footprint = Vector3.new(5, 5, 5),
		PivotOffset = Vector3.new(0, 2.5, 0),
		RequiredHexTag = BuildingConfig.HexTags.Special,
		Income = table.freeze({
			WeeklyGold = 40,
		}),
	}),

	Cuartel = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Cuartel",
		DisplayName = "CUARTEL",
		Category = BuildingConfig.Categories.Military,
		Enabled = true,
		RequiresBuilder = true,
		PlacementMode = "Center",
		Gold = 160,
		Limit = 2,
		Population = 4,
		PopulationCapBonus = 0,
		HP = 200,
		Interactable = false,
		BuildTime = 20,
		AllowedSockets = CENTER_SOCKET,
		RotationLocked = false,
		Footprint = Vector3.new(6, 6, 6),
		PivotOffset = Vector3.new(0, 3, 0),
		RequiredHexTag = BuildingConfig.HexTags.General,
		Production = table.freeze({
			Units = table.freeze({
				"InfanteriaLigera",
				"Constructor",
			}),
		}),
	}),

	Fabrica = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Fabrica",
		ModelFallbackPath = "ReplicatedStorage/Assets/Buildings/Cuartel",
		DisplayName = "FABRICA",
		Category = BuildingConfig.Categories.Military,
		Enabled = true,
		RequiresBuilder = true,
		PlacementMode = "Center",
		Gold = 235,
		Limit = 2,
		Population = 5,
		PopulationCapBonus = 0,
		HP = 240,
		Interactable = false,
		BuildTime = 24,
		AllowedSockets = CENTER_SOCKET,
		RotationLocked = false,
		Footprint = Vector3.new(7, 6, 7),
		PivotOffset = Vector3.new(0, 3, 0),
		RequiredHexTag = BuildingConfig.HexTags.General,
		Production = table.freeze({
			Units = table.freeze({
				"Tanque",
			}),
		}),
	}),

	Artilleria = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Artilleria",
		DisplayName = "ARTILLERIA",
		Category = BuildingConfig.Categories.Defense,
		Enabled = false,
		RequiresBuilder = true,
		PlacementMode = "Edge",
		Gold = 260,
		Limit = 4,
		Population = 6,
		PopulationCapBonus = 0,
		HP = 80,
		Interactable = false,
		BuildTime = 26,
		AllowedSockets = EDGE_SOCKETS,
		RotationLocked = false,
		ModelYawOffset = 0,
		Footprint = Vector3.new(4, 4, 4),
		PivotOffset = Vector3.new(0, 2, 0),
		RequiredHexTag = BuildingConfig.HexTags.General,
	}),

	Pared = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Pared",
		DisplayName = "PARED",
		Category = BuildingConfig.Categories.Defense,
		Enabled = true,
		RequiresBuilder = true,
		PlacementMode = "Edge",
		Gold = 35,
		Limit = 12,
		Population = 0,
		PopulationCapBonus = 0,
		HP = 180,
		Interactable = false,
		BuildTime = 5,
		AllowedSockets = EDGE_SOCKETS,
		RotationLocked = false,
		ModelYawOffset = 0,
		Footprint = Vector3.new(5, 4, 1),
		PivotOffset = Vector3.new(0, 2, 0),
		RequiredHexTag = BuildingConfig.HexTags.General,
		BlocksLineOfSight = true,
		BlocksEdgeMovement = true,
	}),

	Torreta = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Torreta",
		ModelFallbackPath = "ReplicatedStorage/Assets/Buildings/Artilleria",
		DisplayName = "TORRETA",
		Category = BuildingConfig.Categories.Defense,
		Enabled = false,
		RequiresBuilder = true,
		PlacementMode = "Center",
		Gold = 260,
		Limit = 4,
		Population = 3,
		PopulationCapBonus = 0,
		HP = 140,
		Interactable = false,
		BuildTime = 24,
		AllowedSockets = CENTER_SOCKET,
		RotationLocked = false,
		Footprint = Vector3.new(4, 5, 4),
		PivotOffset = Vector3.new(0, 2.5, 0),
		RequiredHexTag = BuildingConfig.HexTags.General,
	}),

	Minas = table.freeze({
		Path = "ReplicatedStorage/Assets/Buildings/Minas",
		ModelFallbackPath = "ReplicatedStorage/Assets/Buildings/Pared",
		DisplayName = "MINAS",
		Category = BuildingConfig.Categories.Defense,
		Enabled = false,
		RequiresBuilder = true,
		PlacementMode = "Center",
		Gold = 80,
		Limit = 8,
		Population = 0,
		PopulationCapBonus = 0,
		HP = 40,
		Interactable = false,
		BuildTime = 8,
		AllowedSockets = CENTER_SOCKET,
		RotationLocked = false,
		Footprint = Vector3.new(3, 1, 3),
		PivotOffset = Vector3.new(0, 0.5, 0),
		RequiredHexTag = BuildingConfig.HexTags.General,
	}),
})

BuildingConfig.NexoProduction = table.freeze({
	Units = table.freeze({
		"Constructor",
	}),
})

BuildingConfig.Aliases = table.freeze({
	House = "Casa",
	Sawmill = "Aserradero",
	Barracks = "Cuartel",
	Factory = "Fabrica",
	Artillery = "Artilleria",
	Wall = "Pared",
	Turret = "Torreta",
	Mines = "Minas",
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

function BuildingConfig.IsEnabled(buildingType: any): boolean
	local definition = BuildingConfig.GetBuilding(buildingType)
	return definition ~= nil and definition.Enabled == true
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

function BuildingConfig.GetProductionUnits(buildingType: any): { string }
	local definition = BuildingConfig.GetBuilding(buildingType)
	local production = if definition ~= nil then definition.Production else nil
	local units = if type(production) == "table" then production.Units else nil
	return if type(units) == "table" then units else {}
end

function BuildingConfig.CanProduceUnit(buildingType: any, unitType: any): boolean
	if typeof(unitType) ~= "string" or unitType == "" then
		return false
	end

	for _, configuredUnitType in BuildingConfig.GetProductionUnits(buildingType) do
		if configuredUnitType == unitType then
			return true
		end
	end

	return false
end

function BuildingConfig.CanNexoProduceUnit(unitType: any): boolean
	if typeof(unitType) ~= "string" or unitType == "" then
		return false
	end

	for _, configuredUnitType in BuildingConfig.NexoProduction.Units do
		if configuredUnitType == unitType then
			return true
		end
	end

	return false
end

BuildingConfig.Nexo = table.freeze({
	TagKeyword = "Nexo",
	SelectableTags = table.freeze({
		"Nexo",
	}),
	AllowKeywordTags = true,
	SelectionDurationSeconds = 10,
	AssignmentMessageSeconds = 3,
	MinimumSelectionNexos = 2,
	DiscoveryRetryDelaySeconds = 0.35,
	DiscoveryMaxAttempts = 8,
	HexRaycastHeight = 160,
	HexRaycastDepth = 420,
	SelectionRayDistance = 500,
	ProjectedPickRadiusPixels = 48,
	InitialSelectionPickRadiusPixels = 86,
	RootPartName = "RootPart",
	HexStateAttribute = "State",
	HP = 1000,
	States = table.freeze({
		Available = "available",
		Selected = "selected",
		Taken = "taken",
	}),
	BlockReason = "Nexo",
	AssignedHighlight = table.freeze({
		FillTransparency = 1,
		HoverFillTransparency = 0.8,
		OutlineTransparency = 0.02,
	}),
	GetDefaultLore = function(displayName: string): string
		return `{displayName} mantiene una posicion clave para controlar el frente y sostener la linea de avance.`
	end,
})

function BuildingConfig.IsNexoTag(tag: any): boolean
	if typeof(tag) ~= "string" or tag == "" then
		return false
	end

	for _, selectableTag in BuildingConfig.Nexo.SelectableTags do
		if tag == selectableTag then
			return true
		end
	end

	local keyword = BuildingConfig.Nexo.TagKeyword
	if BuildingConfig.Nexo.AllowKeywordTags == true and typeof(keyword) == "string" and keyword ~= "" then
		return string.find(string.lower(tag), string.lower(keyword), 1, true) ~= nil
	end

	return false
end

return table.freeze(BuildingConfig)
