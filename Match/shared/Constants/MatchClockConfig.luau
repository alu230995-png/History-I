local MatchClockConfig = {}

MatchClockConfig.TickSeconds = 1
MatchClockConfig.StartDate = table.freeze({
	Year = 1905,
	Month = 1,
	Day = 1,
})

return table.freeze(MatchClockConfig)
