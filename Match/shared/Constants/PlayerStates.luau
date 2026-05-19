local PlayerStates = {
	Connecting = "Connecting",
	Lobby = "Lobby",
	NexoSelection = "NexoSelection",
	LoadingMatch = "LoadingMatch",
	Playing = "Playing",
	Building = "Building",
	Defeated = "Defeated",
	Spectating = "Spectating",
}

PlayerStates.AllowedTransitions = {
	[PlayerStates.Connecting] = {
		[PlayerStates.Lobby] = true,
	},

	[PlayerStates.Lobby] = {
		[PlayerStates.NexoSelection] = true,
		[PlayerStates.LoadingMatch] = true,
		[PlayerStates.Playing] = true,
		[PlayerStates.Building] = true,
	},

	[PlayerStates.NexoSelection] = {
		[PlayerStates.Playing] = true,
		[PlayerStates.Lobby] = true,
		[PlayerStates.Spectating] = true,
	},

	[PlayerStates.LoadingMatch] = {
		[PlayerStates.NexoSelection] = true,
		[PlayerStates.Playing] = true,
		[PlayerStates.Lobby] = true,
	},

	[PlayerStates.Playing] = {
		[PlayerStates.Building] = true,
		[PlayerStates.Defeated] = true,
		[PlayerStates.Spectating] = true,
		[PlayerStates.Lobby] = true,
	},

	[PlayerStates.Building] = {
		[PlayerStates.Lobby] = true,
		[PlayerStates.Playing] = true,
		[PlayerStates.Defeated] = true,
		[PlayerStates.Spectating] = true,
	},

	[PlayerStates.Defeated] = {
		[PlayerStates.Spectating] = true,
		[PlayerStates.Lobby] = true,
	},

	[PlayerStates.Spectating] = {
		[PlayerStates.Lobby] = true,
		[PlayerStates.LoadingMatch] = true,
	},
}

return table.freeze(PlayerStates)
