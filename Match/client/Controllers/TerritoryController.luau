local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local TerritoryController = Knit.CreateController({
	Name = "TerritoryController",
})

function TerritoryController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._territoryService = nil
	self._territorySnapshot = nil
	self._captureSnapshot = nil
end

function TerritoryController:KnitStart()
	self._territoryService = Knit.GetService("TerritoryService")
	self._territorySnapshot = self._territoryService:GetSnapshot()
	self._captureSnapshot = self._territoryService:GetCaptureSnapshot()

	self._trove:Add(self._territoryService.TerritorySnapshotChanged:Connect(function(snapshot)
		self._territorySnapshot = snapshot
	end))

	self._trove:Add(self._territoryService.CaptureProgressChanged:Connect(function(snapshot)
		self._captureSnapshot = snapshot
	end))
end

function TerritoryController:GetTerritorySnapshot()
	return self._territorySnapshot
end

function TerritoryController:GetCaptureSnapshot()
	return self._captureSnapshot
end

function TerritoryController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
end

return TerritoryController
