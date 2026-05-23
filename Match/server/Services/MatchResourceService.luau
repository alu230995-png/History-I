local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))
local Trove = require(Packages:WaitForChild("Trove"))

local MatchEconomyConfig = require(Shared:WaitForChild("Constants"):WaitForChild("MatchEconomyConfig"))

type ResourceState = {
	Gold: number,
	PopulationUsed: number,
	PopulationCap: number,
}

local MatchResourceService = Knit.CreateService({
	Name = "MatchResourceService",

	Client = {
		ResourcesChanged = Knit.CreateSignal(),
	},
})

local function cloneResourceState(resources: ResourceState): ResourceState
	return {
		Gold = resources.Gold,
		PopulationUsed = resources.PopulationUsed,
		PopulationCap = resources.PopulationCap,
	}
end

local function createResourceState(): ResourceState
	local starting = MatchEconomyConfig.StartingResources

	return {
		Gold = starting.Gold,
		PopulationUsed = starting.PopulationUsed,
		PopulationCap = starting.PopulationCap,
	}
end

function MatchResourceService.Client:GetSnapshot(player: Player): ResourceState
	return self.Server:GetSnapshot(player)
end

function MatchResourceService:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._resources = {}
	self._nexoPopulationActive = {}
	self._clockService = nil
	self._nexoService = nil
	self.ResourcesChanged = Signal.new()
	self._trove:Add(self.ResourcesChanged)
end

function MatchResourceService:KnitStart()
	self._clockService = Knit.GetService("MatchClockService")
	self._nexoService = Knit.GetService("NexoService")

	self._trove:Add(Players.PlayerAdded:Connect(function(player: Player)
		self:_initializePlayer(player)
	end))
	self._trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self._resources[player] = nil
		self._nexoPopulationActive[player] = nil
	end))
	self._trove:Add(self._clockService:OnTick(function()
		self:_awardNexoIncome()
	end))

	for _, player in Players:GetPlayers() do
		self:_initializePlayer(player)
	end
end

function MatchResourceService:GetSnapshot(player: Player): ResourceState
	return cloneResourceState(self:_getResources(player))
end

function MatchResourceService:CanAffordBuilding(
	player: Player,
	goldCost: number,
	populationCost: number
): (boolean, string?)
	return self:_canAfford(player, goldCost, populationCost)
end

function MatchResourceService:CanAffordUnit(
	player: Player,
	goldCost: number,
	populationCost: number
): (boolean, string?)
	return self:_canAfford(player, goldCost, populationCost)
end

function MatchResourceService:_canAfford(player: Player, goldCost: number, populationCost: number): (boolean, string?)
	local resources = self:_getResources(player)
	if resources.Gold < goldCost then
		return false, "NotEnoughGold"
	end

	if resources.PopulationUsed + populationCost > resources.PopulationCap then
		return false, "NotEnoughPopulation"
	end

	return true, nil
end

function MatchResourceService:ApplyBuildingPlaced(
	player: Player,
	goldCost: number,
	populationCost: number,
	populationCapBonus: number
)
	local resources = self:_getResources(player)
	resources.Gold = math.max(0, resources.Gold - goldCost)
	resources.PopulationUsed += populationCost
	resources.PopulationCap += populationCapBonus
	self:_broadcast(player)
end

function MatchResourceService:ApplyBuildingRemoved(player: Player, populationCost: number, populationCapBonus: number)
	local resources = self:_getResources(player)
	resources.PopulationUsed = math.max(0, resources.PopulationUsed - populationCost)
	resources.PopulationCap = math.max(0, resources.PopulationCap - populationCapBonus)
	self:_broadcast(player)
end

function MatchResourceService:ApplyUnitQueued(player: Player, goldCost: number, populationCost: number)
	local resources = self:_getResources(player)
	resources.Gold = math.max(0, resources.Gold - goldCost)
	resources.PopulationUsed += populationCost
	self:_broadcast(player)
end

function MatchResourceService:ReleaseUnitPopulation(player: Player, populationCost: number)
	local resources = self:_getResources(player)
	resources.PopulationUsed = math.max(0, resources.PopulationUsed - populationCost)
	self:_broadcast(player)
end

function MatchResourceService:SetNexoActive(player: Player, isActive: boolean)
	local current = self._nexoPopulationActive[player] == true
	if current == isActive then
		return
	end

	local resources = self:_getResources(player)
	self._nexoPopulationActive[player] = isActive

	if isActive then
		resources.PopulationCap += MatchEconomyConfig.NexoPopulationCap
	else
		resources.PopulationCap = math.max(0, resources.PopulationCap - MatchEconomyConfig.NexoPopulationCap)
	end

	self:_broadcast(player)
end

function MatchResourceService:_awardNexoIncome()
	if self._nexoService == nil then
		return
	end

	for _, player in Players:GetPlayers() do
		if self._nexoService:HasActiveNexo(player) then
			local resources = self:_getResources(player)
			resources.Gold += MatchEconomyConfig.NexoGoldPerTick
			self:_broadcast(player)
		end
	end
end

function MatchResourceService:_initializePlayer(player: Player)
	if self._resources[player] ~= nil then
		return
	end

	self._resources[player] = createResourceState()
	self:_broadcast(player)
end

function MatchResourceService:_getResources(player: Player): ResourceState
	if self._resources[player] == nil then
		self:_initializePlayer(player)
	end

	return self._resources[player]
end

function MatchResourceService:_broadcast(player: Player)
	local snapshot = self:GetSnapshot(player)
	self.ResourcesChanged:Fire(player, snapshot)
	self.Client.ResourcesChanged:Fire(player, snapshot)
end

function MatchResourceService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
	table.clear(self._resources)
	table.clear(self._nexoPopulationActive)
end

return MatchResourceService
