local MatchStates = {
	Booting = "Booting",
	WaitingForPlayers = "WaitingForPlayers",
	NexoSelection = "NexoSelection",
	LoadingMatch = "LoadingMatch",
	Playing = "Playing",
	MatchEnd = "MatchEnd",
}

MatchStates.AllowedTransitions = {
	[MatchStates.Booting] = {
		[MatchStates.WaitingForPlayers] = true,
	},

	[MatchStates.WaitingForPlayers] = {
		[MatchStates.NexoSelection] = true,
		[MatchStates.LoadingMatch] = true,
	},

	[MatchStates.NexoSelection] = {
		[MatchStates.Playing] = true,
		[MatchStates.WaitingForPlayers] = true,
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
