local MatchEconomyConfig = {}

MatchEconomyConfig.StartingResources = table.freeze({
	Gold = 0,
	PopulationUsed = 0,
	PopulationCap = 0,
})

MatchEconomyConfig.DaysPerWeek = 7
MatchEconomyConfig.IncomeTickSeconds = 0.25
MatchEconomyConfig.NexoGoldPerWeek = 20
MatchEconomyConfig.NexoGoldPerTick = 20
MatchEconomyConfig.NexoPopulationCap = 10

return table.freeze(MatchEconomyConfig)
