local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

Knit.AddServicesDeep(script:WaitForChild("Services"))

Knit.Start()
	:andThen(function()
		print("[Knit] Server started")
	end)
	:catch(warn)
