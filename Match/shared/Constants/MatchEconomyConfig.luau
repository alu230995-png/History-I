local MatchEconomyConfig = {}

MatchEconomyConfig.StartingResources = table.freeze({
	Gold = 0,
	PopulationUsed = 0,
	PopulationCap = 0,
})

MatchEconomyConfig.NexoGoldPerTick = 10
MatchEconomyConfig.NexoPopulationCap = 10

return table.freeze(MatchEconomyConfig)
