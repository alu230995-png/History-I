local TerritoryConfig = {}

TerritoryConfig.OwnerAttribute = "TerritoryOwnerUserId"
TerritoryConfig.StateAttribute = "State"
TerritoryConfig.CaptureProgressAttribute = "CaptureProgress"
TerritoryConfig.CaptureOwnerAttribute = "CaptureOwnerUserId"

TerritoryConfig.SimulationTickSeconds = 0.25
TerritoryConfig.SnapshotIntervalSeconds = 0.5
TerritoryConfig.DefaultCaptureSeconds = 8
TerritoryConfig.DefaultCaptureRate = 1
TerritoryConfig.MinCaptureSeconds = 0.5

return table.freeze(TerritoryConfig)
