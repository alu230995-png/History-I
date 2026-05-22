local GameConstants = {
	Match = {
		MinimumPlayersToStart = 1,
	},

	Camera = {
		Speed = 80,
		Height = 30,
		VelocitySendInterval = 1 / 30,
		VelocityEpsilon = 0.1,
		MovementDeadzone = 0.08,
		RenderSmoothTime = 0.07,
		RenderMaxSpeed = 500,
		RenderSnapDistance = 0.25,
		ZoomMinHeight = 10,
		ZoomMaxHeight = 60,
		ZoomStep = 8,
		ZoomSmoothTime = 0.08,
		ZoomMaxSpeed = 500,
		PinchZoomStudsPerPixel = 0.12,
	},

	Drone = {
		NamePrefix = "Drone_",
		FolderName = "CommandDrones",
		Size = Vector3.new(2, 2, 2),
		SpawnPosition = Vector3.new(0, 20, 0),
		MaxForce = Vector3.new(100000, 100000, 100000),
		MaxSpeed = 90,
		MaxVelocityRequestsPerSecond = 40,
	},

	ControlRig = {
		FolderName = "CommandControlRigs",
		RootSize = Vector3.new(2, 2, 1),
		HeadSize = Vector3.new(1, 1, 1),
	},

	MapBounds = {
		Min = Vector3.new(-250, 0, -250),
		Max = Vector3.new(250, 150, 250),
	},
}

return table.freeze(GameConstants)
