local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local GridConfig = require(Shared:WaitForChild("Constants"):WaitForChild("GridConfig"))
local TerritoryConfig = require(Shared:WaitForChild("Constants"):WaitForChild("TerritoryConfig"))
local HexUtils = require(Shared:WaitForChild("Utils"):WaitForChild("HexUtils"))

local TerritoryService = Knit.CreateService({
	Name = "TerritoryService",

	Client = {
		TerritorySnapshotChanged = Knit.CreateSignal(),
		CaptureProgressChanged = Knit.CreateSignal(),
	},
})

type HexRecord = {
	Key: string,
	Part: BasePart,
	State: string?,
	OwnerUserId: number?,
}

local function getHexState(hexPart: BasePart): string?
	local state = hexPart:GetAttribute(TerritoryConfig.StateAttribute)
	return if typeof(state) == "string" and state ~= "" then state else nil
end

local function getHexKey(hexPart: BasePart): string
	local coord = HexUtils.getHexCoordFromPart(hexPart, GridConfig)
	return HexUtils.toKey(coord.q, coord.r)
end

local function getCaptureSettings(unit): (number, number)
	local capture = if unit ~= nil and type(unit.Definition) == "table" then unit.Definition.Capture else nil
	local seconds = if type(capture) == "table" and typeof(capture.Seconds) == "number"
		then math.max(capture.Seconds, TerritoryConfig.MinCaptureSeconds)
		else TerritoryConfig.DefaultCaptureSeconds
	local rate = if type(capture) == "table" and typeof(capture.Rate) == "number"
		then math.max(capture.Rate, 0)
		else TerritoryConfig.DefaultCaptureRate

	return seconds, rate
end

function TerritoryService.Client:GetSnapshot(_player: Player): any
	return self.Server:_createTerritorySnapshot()
end

function TerritoryService.Client:GetCaptureSnapshot(_player: Player): any
	return self.Server:_createCaptureSnapshot()
end

function TerritoryService:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._hexByKey = {}
	self._hexByPart = {}
	self._stateOwnerByState = {}
	self._unitsByHex = {}
	self._activeHexes = {}
	self._captureByHex = {}
	self._simulationAccumulator = 0
	self._snapshotAccumulator = 0
	self._manpowerService = nil
	self._diplomacyService = nil
	self._nexoService = nil
end

function TerritoryService:KnitStart()
	self._manpowerService = Knit.GetService("ManpowerService")
	self._diplomacyService = Knit.GetService("DiplomacyService")
	self._nexoService = Knit.GetService("NexoService")

	self:RebuildHexCache()
	self:_seedActiveUnits()

	self._trove:Add(CollectionService:GetInstanceAddedSignal(GridConfig.BuildableHexTag):Connect(function(instance)
		self:_scanHex(instance)
		self:_broadcastTerritorySnapshot()
	end))
	self._trove:Add(CollectionService:GetInstanceRemovedSignal(GridConfig.BuildableHexTag):Connect(function(instance)
		self:_removeHex(instance)
		self:_broadcastTerritorySnapshot()
	end))
	self._trove:Add(self._manpowerService.UnitEnteredHex:Connect(function(unit, hexKey: string)
		self:_handleUnitEnteredHex(unit, hexKey)
	end))
	self._trove:Add(self._manpowerService.UnitLeftHex:Connect(function(unit, hexKey: string)
		self:_handleUnitLeftHex(unit, hexKey)
	end))
	self._trove:Add(self._manpowerService.UnitDestroyed:Connect(function(unit)
		if unit ~= nil and typeof(unit.CurrentHexKey) == "string" then
			self:_handleUnitLeftHex(unit, unit.CurrentHexKey)
		end
	end))
	self._trove:Add(self._nexoService.TerritoryOwnerChanged:Connect(function(stateName: string?, ownerUserId: number?)
		self:_setStateOwner(stateName, ownerUserId)
	end))
	self._trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self:_handlePlayerRemoving(player)
	end))
	self._trove:Add(RunService.Heartbeat:Connect(function(deltaTime: number)
		self:_stepHeartbeat(deltaTime)
	end))
end

function TerritoryService:RebuildHexCache()
	table.clear(self._hexByKey)
	table.clear(self._hexByPart)

	for _, taggedInstance in CollectionService:GetTagged(GridConfig.BuildableHexTag) do
		self:_scanHex(taggedInstance)
	end
end

function TerritoryService:CanBuildOnHex(player: Player, hexPart: BasePart): (boolean, string?)
	local record = self._hexByPart[hexPart]
	if record == nil then
		return false, "MissingHex"
	end

	if record.OwnerUserId ~= player.UserId then
		return false, "OutOfOwnedTerritory"
	end

	return true, nil
end

function TerritoryService:GetHexOwner(hexPart: BasePart): number?
	local record = self._hexByPart[hexPart]
	return if record ~= nil then record.OwnerUserId else nil
end

function TerritoryService:TransferState(stateName: string?, newOwnerUserId: number?, oldOwnerUserId: number?)
	if typeof(stateName) ~= "string" or stateName == "" or typeof(newOwnerUserId) ~= "number" then
		return
	end

	self._stateOwnerByState[stateName] = newOwnerUserId
	for _, record in self._hexByKey do
		if record.State ~= stateName then
			continue
		end

		if oldOwnerUserId == nil or record.OwnerUserId == nil or record.OwnerUserId == oldOwnerUserId then
			self:_setHexOwner(record, newOwnerUserId)
		end
	end

	self:_broadcastTerritorySnapshot()
end

function TerritoryService:_setStateOwner(stateName: string?, ownerUserId: number?)
	if typeof(stateName) ~= "string" or stateName == "" or typeof(ownerUserId) ~= "number" then
		return
	end

	if self._stateOwnerByState[stateName] == ownerUserId then
		return
	end

	self._stateOwnerByState[stateName] = ownerUserId
	for _, record in self._hexByKey do
		if record.State == stateName and record.OwnerUserId == nil then
			self:_setHexOwner(record, ownerUserId)
		end
	end
	self:_broadcastTerritorySnapshot()
end

function TerritoryService:_scanHex(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	local hexPart = instance :: BasePart
	local key = getHexKey(hexPart)
	local stateName = getHexState(hexPart)
	local ownerUserId = if stateName ~= nil then self._stateOwnerByState[stateName] else nil
	local attributeOwner = hexPart:GetAttribute(TerritoryConfig.OwnerAttribute)
	if typeof(attributeOwner) == "number" then
		ownerUserId = attributeOwner
	end

	local record = {
		Key = key,
		Part = hexPart,
		State = stateName,
		OwnerUserId = ownerUserId,
	}
	self._hexByKey[key] = record
	self._hexByPart[hexPart] = record
	self:_applyHexAttributes(record)
end

function TerritoryService:_removeHex(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	local record = self._hexByPart[instance]
	if record == nil then
		return
	end

	self._hexByPart[instance] = nil
	if self._hexByKey[record.Key] == record then
		self._hexByKey[record.Key] = nil
	end
	self._unitsByHex[record.Key] = nil
	self._activeHexes[record.Key] = nil
	self._captureByHex[record.Key] = nil
end

function TerritoryService:_seedActiveUnits()
	for _, unit in self._manpowerService:GetCombatUnits() do
		if typeof(unit.CurrentHexKey) == "string" then
			self:_handleUnitEnteredHex(unit, unit.CurrentHexKey)
		end
	end
end

function TerritoryService:_handleUnitEnteredHex(unit, hexKey: string)
	if unit == nil or typeof(hexKey) ~= "string" then
		return
	end

	local units = self._unitsByHex[hexKey]
	if units == nil then
		units = {}
		self._unitsByHex[hexKey] = units
	end
	units[unit.Id] = unit
	self._activeHexes[hexKey] = true
end

function TerritoryService:_handleUnitLeftHex(unit, hexKey: string)
	local units = self._unitsByHex[hexKey]
	if units == nil or unit == nil then
		return
	end

	units[unit.Id] = nil
	if next(units) == nil then
		self._unitsByHex[hexKey] = nil
		self._activeHexes[hexKey] = nil
		self:_clearCapture(hexKey)
	end
end

function TerritoryService:_stepHeartbeat(deltaTime: number)
	if self._destroyed then
		return
	end

	self._simulationAccumulator += math.min(deltaTime, 0.5)
	while self._simulationAccumulator >= TerritoryConfig.SimulationTickSeconds do
		self._simulationAccumulator -= TerritoryConfig.SimulationTickSeconds
		self:_stepCapture(TerritoryConfig.SimulationTickSeconds)
	end

	self._snapshotAccumulator += deltaTime
	if self._snapshotAccumulator >= TerritoryConfig.SnapshotIntervalSeconds then
		self._snapshotAccumulator = 0
		self:_broadcastCaptureSnapshot()
	end
end

function TerritoryService:_stepCapture(deltaSeconds: number)
	for hexKey in self._activeHexes do
		self:_stepHexCapture(hexKey, deltaSeconds)
	end
end

function TerritoryService:_stepHexCapture(hexKey: string, deltaSeconds: number)
	local record = self._hexByKey[hexKey]
	local units = self._unitsByHex[hexKey]
	if record == nil or units == nil or record.OwnerUserId == nil then
		self:_clearCapture(hexKey)
		return
	end

	local attackersByUserId = {}
	local defendersPresent = false

	for _, unit in units do
		if unit == nil or unit.Owner == nil or not self._manpowerService:IsCombatUnitActive(unit) then
			continue
		end

		local ownerUserId = unit.Owner.UserId
		if self._diplomacyService:AreHostile(ownerUserId, record.OwnerUserId) then
			local seconds, rate = getCaptureSettings(unit)
			local attacker = attackersByUserId[ownerUserId]
			if attacker == nil then
				attacker = {
					Required = seconds,
					Rate = 0,
				}
				attackersByUserId[ownerUserId] = attacker
			end
			attacker.Required = math.max(attacker.Required, seconds)
			attacker.Rate += rate
		else
			defendersPresent = true
		end
	end

	local selectedAttackerUserId = nil
	local selectedAttack = nil
	for attackerUserId, attack in attackersByUserId do
		if selectedAttack == nil or attack.Rate > selectedAttack.Rate then
			selectedAttackerUserId = attackerUserId
			selectedAttack = attack
		elseif selectedAttack ~= nil and attack.Rate == selectedAttack.Rate then
			selectedAttackerUserId = nil
		end
	end

	if selectedAttackerUserId == nil or selectedAttack == nil then
		self:_clearCapture(hexKey)
		return
	end

	local capture = self._captureByHex[hexKey]
	if capture == nil or capture.AttackerUserId ~= selectedAttackerUserId then
		capture = {
			AttackerUserId = selectedAttackerUserId,
			Progress = 0,
			Required = selectedAttack.Required,
			Contested = false,
		}
		self._captureByHex[hexKey] = capture
	end

	capture.Required = selectedAttack.Required
	capture.Contested = defendersPresent
	if defendersPresent then
		self:_applyCaptureAttributes(record, capture)
		return
	end

	capture.Progress += selectedAttack.Rate * deltaSeconds
	if capture.Progress >= capture.Required then
		self:_setHexOwner(record, selectedAttackerUserId)
		self:_clearCapture(hexKey)
	else
		self:_applyCaptureAttributes(record, capture)
	end
end

function TerritoryService:_setHexOwner(record: HexRecord, ownerUserId: number?)
	record.OwnerUserId = ownerUserId
	self:_applyHexAttributes(record)
end

function TerritoryService:_applyHexAttributes(record: HexRecord)
	if record.Part.Parent == nil then
		return
	end

	if record.OwnerUserId ~= nil then
		record.Part:SetAttribute(TerritoryConfig.OwnerAttribute, record.OwnerUserId)
	else
		record.Part:SetAttribute(TerritoryConfig.OwnerAttribute, nil)
	end
end

function TerritoryService:_applyCaptureAttributes(record: HexRecord, capture)
	record.Part:SetAttribute(TerritoryConfig.CaptureOwnerAttribute, capture.AttackerUserId)
	record.Part:SetAttribute(
		TerritoryConfig.CaptureProgressAttribute,
		math.clamp(capture.Progress / capture.Required, 0, 1)
	)
end

function TerritoryService:_clearCapture(hexKey: string)
	local capture = self._captureByHex[hexKey]
	if capture == nil then
		return
	end

	self._captureByHex[hexKey] = nil
	local record = self._hexByKey[hexKey]
	if record ~= nil and record.Part.Parent ~= nil then
		record.Part:SetAttribute(TerritoryConfig.CaptureOwnerAttribute, nil)
		record.Part:SetAttribute(TerritoryConfig.CaptureProgressAttribute, nil)
	end
end

function TerritoryService:_createTerritorySnapshot(): any
	local hexes = {}
	for _, record in self._hexByKey do
		table.insert(hexes, {
			hexKey = record.Key,
			state = record.State,
			ownerUserId = record.OwnerUserId,
			hexPart = record.Part,
		})
	end

	return {
		hexes = hexes,
	}
end

function TerritoryService:_createCaptureSnapshot(): any
	local captures = {}
	for hexKey, capture in self._captureByHex do
		table.insert(captures, {
			hexKey = hexKey,
			attackerUserId = capture.AttackerUserId,
			progress = capture.Progress,
			required = capture.Required,
			contested = capture.Contested,
		})
	end

	return {
		captures = captures,
	}
end

function TerritoryService:_broadcastTerritorySnapshot()
	self.Client.TerritorySnapshotChanged:FireAll(self:_createTerritorySnapshot())
end

function TerritoryService:_broadcastCaptureSnapshot()
	self.Client.CaptureProgressChanged:FireAll(self:_createCaptureSnapshot())
end

function TerritoryService:_handlePlayerRemoving(player: Player)
	for _, record in self._hexByKey do
		if record.OwnerUserId == player.UserId then
			self:_setHexOwner(record, nil)
		end
	end
	self:_broadcastTerritorySnapshot()
end

function TerritoryService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
	table.clear(self._hexByKey)
	table.clear(self._hexByPart)
	table.clear(self._stateOwnerByState)
	table.clear(self._unitsByHex)
	table.clear(self._activeHexes)
	table.clear(self._captureByHex)
end

return TerritoryService
