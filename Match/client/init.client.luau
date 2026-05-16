local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

Knit.AddControllersDeep(script:WaitForChild("Controllers"))

Knit.Start({
	ServicePromises = false,
})
	:andThen(function()
		print("[Knit] Client started")
	end)
	:catch(warn)
