export type PlayerState =
	"Connecting"
	| "Lobby"
	| "NexoSelection"
	| "LoadingMatch"
	| "Playing"
	| "Building"
	| "Defeated"
	| "Spectating"
export type MatchState = "Booting" | "WaitingForPlayers" | "NexoSelection" | "LoadingMatch" | "Playing" | "MatchEnd"

export type NexoState = "available" | "selected" | "taken"

export type DroneRuntime = {
	Part: BasePart,
	Attachment: Attachment,
	LinearVelocity: LinearVelocity,
}

return {}
