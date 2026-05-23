local PhysicsService = game:GetService("PhysicsService")

local TropaCollisionGroups = {}

TropaCollisionGroups.TropasGroupName = "Tropas"

local groupReady = false

function TropaCollisionGroups.EnsureTropasGroup()
	if groupReady then
		return
	end

	groupReady = true
	pcall(function()
		PhysicsService:RegisterCollisionGroup(TropaCollisionGroups.TropasGroupName)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(
			TropaCollisionGroups.TropasGroupName,
			TropaCollisionGroups.TropasGroupName,
			false
		)
	end)
end

function TropaCollisionGroups.ApplyToPart(part: BasePart)
	TropaCollisionGroups.EnsureTropasGroup()

	pcall(function()
		part.CollisionGroup = TropaCollisionGroups.TropasGroupName
	end)
end

function TropaCollisionGroups.ApplyToModel(model: Instance)
	TropaCollisionGroups.EnsureTropasGroup()

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			TropaCollisionGroups.ApplyToPart(descendant)
		end
	end
end

return table.freeze(TropaCollisionGroups)
