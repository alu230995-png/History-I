local ManpowerConfig = {}

ManpowerConfig.UnitFolderName = "ManpowerUnits"
ManpowerConfig.QueueCapacity = 4
ManpowerConfig.PlaceholderIcon = "rbxassetid://6031075938"

ManpowerConfig.TerrainPassable = table.freeze({
	Plain = true,
	Forest = true,
	Desert = true,
	Mountain = true,
	Water = false,
})

ManpowerConfig.MovementModes = table.freeze({
	Humanoid = "Humanoid",
	RootPart = "RootPart",
})

ManpowerConfig.UnitStates = table.freeze({
	Idle = "Idle",
	Moving = "Moving",
	Waiting = "Waiting",
	Repathing = "Repathing",
	Acting = "Acting",
})

ManpowerConfig.UnitStateTransitions = table.freeze({
	Idle = table.freeze({
		Moving = true,
		Acting = true,
	}),
	Moving = table.freeze({
		Idle = true,
		Waiting = true,
		Repathing = true,
		Acting = true,
	}),
	Waiting = table.freeze({
		Idle = true,
		Moving = true,
		Repathing = true,
		Acting = true,
	}),
	Repathing = table.freeze({
		Idle = true,
		Moving = true,
		Waiting = true,
		Acting = true,
	}),
	Acting = table.freeze({
		Idle = true,
		Moving = true,
		Waiting = true,
	}),
})

ManpowerConfig.Movement = table.freeze({
	ArrivalRadius = 2.75,
	HumanoidWaypointTimeout = 4,
	RootPartStepSeconds = 0.05,
	BlockedSpawnRetrySeconds = 1,
	SimulationTickSeconds = 0.1,
	MaxUnitsPerHex = 4,
	DestinationSpreadRadius = 2,
	RepathDelaySeconds = 0.45,
	RepathCooldownSeconds = 0.35,
	StuckSeconds = 1.5,
	TemporaryBlockSeconds = 1,
	MaxStuckFailures = 3,
})

ManpowerConfig.VisualMotion = table.freeze({
	ProxySize = Vector3.new(1.9, 1.9, 1.9),
	ProxyGroundClearance = 0.95,
	ProxyFriction = 0.2,
	MaxAxesForce = Vector3.new(250000, 250000, 250000),
	MaxTorque = 250000,
	ArrivalRadius = 0.18,
	SnapDistance = 6,
	PositionGain = 5.5,
	MaxSpeedScale = 1.45,
	MinCatchupSpeed = 6,
	TurnResponsiveness = 9,
	MaxAngularVelocity = 5,
})

ManpowerConfig.VisualSlotOffsets = table.freeze({
	Vector3.new(-1.35, 0, -1.05),
	Vector3.new(1.35, 0, -1.05),
	Vector3.new(-1.35, 0, 1.05),
	Vector3.new(1.35, 0, 1.05),
})

ManpowerConfig.Units = table.freeze({
	InfanteriaLigera = table.freeze({
		DisplayName = "INFANTERIA LIGERA",
		Path = "ReplicatedStorage/Assets/Manpower/InfanteriaLigera",
		Icon = ManpowerConfig.PlaceholderIcon,
		Gold = 25,
		Population = 1,
		TrainingTime = 8,
		HP = 100,
		Movement = table.freeze({
			Speed = 12,
		}),
		VisualMotion = table.freeze({
			PositionGain = 6.5,
			MaxSpeedScale = 1.5,
			TurnResponsiveness = 11,
			MaxAngularVelocity = 6.5,
		}),
		MovementMode = ManpowerConfig.MovementModes.Humanoid,
		RootPartName = "HumanoidRootPart",
		Combat = table.freeze({
			WeaponId = "InfantryRifle",
			HitRadius = 2.25,
			TargetScanIntervalSeconds = 0.25,
			MuzzleSource = "Tool",
			MuzzleName = "Muzzle",
		}),
	}),

	Tanque = table.freeze({
		DisplayName = "TANQUE",
		Path = "ReplicatedStorage/Assets/Manpower/Tanque",
		Icon = ManpowerConfig.PlaceholderIcon,
		Gold = 100,
		Population = 3,
		TrainingTime = 20,
		HP = 300,
		Movement = table.freeze({
			Speed = 8,
		}),
		VisualMotion = table.freeze({
			ProxySize = Vector3.new(3.2, 2.2, 3.2),
			ProxyGroundClearance = 1.1,
			PositionGain = 4.25,
			MaxSpeedScale = 1.25,
			TurnResponsiveness = 5.5,
			MaxAngularVelocity = 3.25,
		}),
		MovementMode = ManpowerConfig.MovementModes.Humanoid,
		RootPartName = "HumanoidRootPart",
		Combat = table.freeze({
			WeaponId = "TankCannon",
			HitRadius = 3.25,
			TargetScanIntervalSeconds = 0.25,
			MuzzleSource = "RootPart",
			MuzzleName = "Muzzle",
		}),
	}),
})

ManpowerConfig.MenuOrder = table.freeze({
	"InfanteriaLigera",
	"Tanque",
})

function ManpowerConfig.GetUnit(unitType: any): any?
	if typeof(unitType) ~= "string" or unitType == "" then
		return nil
	end

	return ManpowerConfig.Units[unitType]
end

return table.freeze(ManpowerConfig)
