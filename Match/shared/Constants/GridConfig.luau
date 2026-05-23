local GridConfig = {
	HexWidth = 9,
	HexHeight = 10,
	GridOrigin = Vector3.zero,
	HexSnapTolerance = 1.25,
	BuildingPivotTopOffsetY = 0,

	TerrainTypes = {
		Plain = "Plain",
		Water = "Water",
		Forest = "Forest",
		Desert = "Desert",
		Mountain = "Mountain",
	},

	DefaultTerrainType = "Plain",

	BuildableTerrains = {
		Plain = true,
		Water = false,
		Forest = true,
		Desert = true,
		Mountain = true,
	},

	BuildableHexTag = "BuildableHex",
	GeneralBuildingHexTag = "GeneralBuildingHex",
	SpecialBuildingHexTag = "SpecialBuildingHex",
	AutoOptimizeHexParts = true,

	HexPartDefaults = {
		Anchored = true,
		CastShadow = false,
		CanCollide = true,
		CanTouch = false,
		CanQuery = true,
	},

	MaxWallsPerHex = 6,
	MaxBuildingsPerHex = 1,
	BlockedHexTag = "BlockedHex",
}

return table.freeze(GridConfig)
