local MatchStates = {
	Booting = "Booting",
	WaitingForPlayers = "WaitingForPlayers",
	LoadingMatch = "LoadingMatch",
	Playing = "Playing",
	MatchEnd = "MatchEnd",
}

MatchStates.AllowedTransitions = {
	[MatchStates.Booting] = {
		[MatchStates.WaitingForPlayers] = true,
	},

	[MatchStates.WaitingForPlayers] = {
		[MatchStates.LoadingMatch] = true,
	},

	[MatchStates.LoadingMatch] = {
		[MatchStates.Playing] = true,
		[MatchStates.WaitingForPlayers] = true,
	},

	[MatchStates.Playing] = {
		[MatchStates.MatchEnd] = true,
	},

	[MatchStates.MatchEnd] = {
		[MatchStates.WaitingForPlayers] = true,
	},
}

return table.freeze(MatchStates)
