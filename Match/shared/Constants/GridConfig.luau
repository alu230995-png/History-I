local GridConfig = {
	HexWidth = 9,
	HexHeight = 10,
	GridOrigin = Vector3.zero,
	HexSnapTolerance = 1.25,

	TerrainTypes = {
		Plain = "Plain",
		Water = "Water",
		Forest = "Forest",
	},

	DefaultTerrainType = "Plain",

	BuildableTerrains = {
		Plain = true,
		Water = false,
		Forest = false,
	},

	BuildableHexTag = "BuildableHex",
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
}

return table.freeze(GridConfig)
