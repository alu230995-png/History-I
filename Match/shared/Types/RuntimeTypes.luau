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
export type ArmyPhase = "Phase1" | "Phase2"

export type AllianceInvite = {
	id: string,
	fromUserId: number,
	toUserId: number,
	expiresAt: number,
}

export type AllianceBreak = {
	allianceId: string,
	requesterUserId: number,
	targetUserId: number?,
	endsAt: number,
}

export type AllianceSnapshot = {
	selfUserId: number,
	maxMembers: number,
	alliances: { any },
	invites: { AllianceInvite },
	breaks: { AllianceBreak },
}

export type TerritoryOwnerSnapshot = {
	hexKey: string,
	state: string?,
	ownerUserId: number?,
}

export type CaptureProgressSnapshot = {
	hexKey: string,
	attackerUserId: number?,
	progress: number,
	required: number,
	contested: boolean,
}

export type DroneRuntime = {
	Part: BasePart,
	Attachment: Attachment,
	LinearVelocity: LinearVelocity,
}

return {}
