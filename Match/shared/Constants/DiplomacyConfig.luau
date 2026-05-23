local DiplomacyConfig = {}

DiplomacyConfig.MaxAllianceMembers = 3
DiplomacyConfig.AllianceBreakDelaySeconds = 30
DiplomacyConfig.InvitationTtlSeconds = 20
DiplomacyConfig.RequestCooldownSeconds = 0.35
DiplomacyConfig.TargetRayDistance = 500

DiplomacyConfig.PlayerPickRadiusPixels = 34

DiplomacyConfig.Colors = table.freeze({
	Color3.fromRGB(63, 176, 92),
	Color3.fromRGB(86, 151, 215),
	Color3.fromRGB(205, 159, 68),
	Color3.fromRGB(205, 86, 126),
	Color3.fromRGB(118, 198, 180),
	Color3.fromRGB(214, 104, 65),
})

DiplomacyConfig.MenuIds = table.freeze({
	Nexo = "Nexo",
	NexoBuild = "NexoBuild",
	Building = "Building",
	Diplomacy = "Diplomacy",
})

return table.freeze(DiplomacyConfig)
