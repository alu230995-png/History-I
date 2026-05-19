export type PlayerState = "Connecting" | "Lobby" | "LoadingMatch" | "Playing" | "Building" | "Defeated" | "Spectating"
export type MatchState = "Booting" | "WaitingForPlayers" | "LoadingMatch" | "Playing" | "MatchEnd"

export type DroneRuntime = {
	Part: BasePart,
	Attachment: Attachment,
	LinearVelocity: LinearVelocity,
}

return {}
