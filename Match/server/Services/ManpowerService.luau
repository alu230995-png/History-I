local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local GridConfig = require(Shared:WaitForChild("Constants"):WaitForChild("GridConfig"))
local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local PlayerStates = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStates"))
local StateMachine = require(Shared:WaitForChild("Classes"):WaitForChild("StateMachine"))
local HexUtils = require(Shared:WaitForChild("Utils"):WaitForChild("HexUtils"))

type QueueEntry = {
	Id: string,
	UnitType: string,
	Definition: any,
	StartedAt: number?,
	ReadyAt: number?,
	Ready: boolean,
}

type BarracksQueue = {
	BuildingId: string,
	Owner: Player,
	Entries: { QueueEntry },
}

type HexRecord = {
	Key: string,
	Part: BasePart,
	Q: number,
	R: number,
	Center: Vector3,
	Passable: boolean,
	Neighbors: { HexRecord },
}

type MoveSegment = {
	FromKey: string,
	ToKey: string,
	SlotIndex: number,
	StartedAt: number,
	ArrivesAt: number,
	Duration: number,
}

type UnitRecord = {
	Id: string,
	NetId: number,
	Owner: Player,
	UnitType: string,
	Definition: any,
	HP: number,
	CurrentHexKey: string,
	SlotIndex: number,
	OrderDestinationKey: string?,
	TargetHexKey: string?,
	TargetSlotIndex: number?,
	TargetReserved: boolean,
	TargetDistance: number,
	Segment: MoveSegment?,
	AttemptedHexKey: string?,
	LastHexChangedAt: number,
	LastRepathAt: number,
	StuckFailures: number,
	OrderToken: number,
	StateMachine: any,
	Trove: any,
}

type HexOccupancy = {
	Units: { [string]: number },
	Slots: { [number]: string },
	Reservations: { [number]: string },
}

type FlowField = {
	Revision: number,
	DestinationKey: string,
	NextByKey: { [string]: string },
	DistanceByKey: { [string]: number },
}

local ManpowerService = Knit.CreateService({
	Name = "ManpowerService",

	Client = {
		QueueChanged = Knit.CreateSignal(),
		UnitSpawned = Knit.CreateSignal(),
		UnitDestroyed = Knit.CreateSignal(),
		BatchWaypoints = Knit.CreateSignal(),
	},
})

local MIN_REQUEST_INTERVAL = 0.12
local MAX_COMMAND_UNITS = 64
local REQUEST_NAMES = table.freeze({
	Queue = "Queue",
	Move = "Move",
})

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function getUnitSpeed(definition): number
	local movement = definition.Movement
	local configuredSpeed = if type(movement) == "table" then movement.Speed else definition.Speed
	if not isFiniteNumber(configuredSpeed) then
		return 0.001
	end

	return math.max(configuredSpeed, 0.001)
end

local function getTerrainType(hexPart: BasePart): string
	local terrainType = hexPart:GetAttribute("TerrainType")
	if typeof(terrainType) ~= "string" or terrainType == "" then
		return GridConfig.DefaultTerrainType
	end

	return terrainType
end

local function splitPath(path: string): { string }
	local parts = {}

	for segment in string.gmatch(path, "[^/%.]+") do
		table.insert(parts, segment)
	end

	return parts
end

local function resolvePath(path: any): Instance?
	if typeof(path) ~= "string" or path == "" then
		return nil
	end

	local segments = splitPath(path)
	local firstSegment = segments[1]
	if firstSegment == nil then
		return nil
	end

	local ok, current = pcall(function()
		return game:GetService(firstSegment)
	end)

	if not ok then
		current = ({
			game = game,
			Game = game,
			ReplicatedStorage = ReplicatedStorage,
			ServerStorage = ServerStorage,
			Workspace = Workspace,
		})[firstSegment]
	end

	if current == nil then
		return nil
	end

	for index = 2, #segments do
		current = (current :: Instance):FindFirstChild(segments[index])
		if current == nil then
			return nil
		end
	end

	return current :: Instance
end

local function getUnitSource(unitType: string, definition): Model?
	local source = resolvePath(definition.Path)
	if source == nil then
		warn(("[ManpowerService] Missing unit path for %s: %s"):format(unitType, tostring(definition.Path)))
		return nil
	end

	if not source:IsA("Model") then
		warn(("[ManpowerService] Unit path for %s must point to a Model"):format(unitType))
		return nil
	end

	return source
end

local function getUnitIdFromTarget(target: any): string?
	if typeof(target) == "string" then
		return target
	end

	if typeof(target) ~= "Instance" then
		return nil
	end

	local current = target
	while current ~= nil and current ~= Workspace do
		local unitId = current:GetAttribute("UnitId")
		if typeof(unitId) == "string" then
			return unitId
		end

		current = current.Parent
	end

	return nil
end

local function getQueueProgress(entry: QueueEntry, now: number): number
	if entry.Ready then
		return 1
	end

	if entry.StartedAt == nil or entry.ReadyAt == nil then
		return 0
	end

	local duration = math.max(entry.ReadyAt - entry.StartedAt, 0.001)
	return math.clamp((now - entry.StartedAt) / duration, 0, 1)
end

local function getQueueRemaining(entry: QueueEntry, now: number): number
	if entry.Ready or entry.ReadyAt == nil then
		return 0
	end

	return math.max(0, entry.ReadyAt - now)
end

function ManpowerService.Client:GetBarracksQueue(player: Player, buildingId: any): any
	return self.Server:GetBarracksQueue(player, buildingId)
end

function ManpowerService.Client:GetUnitsSnapshot(_player: Player): any
	return self.Server:GetUnitsSnapshot()
end

function ManpowerService.Client:RequestQueueUnit(player: Player, request: any): any
	return self.Server:RequestQueueUnit(player, request)
end

function ManpowerService.Client:RequestMoveUnits(player: Player, request: any): any
	return self.Server:RequestMoveUnits(player, request)
end

function ManpowerService:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._queues = {}
	self._units = {}
	self._unitsByOwner = {}
	self._activeUnits = {}
	self._gridByPart = {}
	self._gridByKey = {}
	self._hexOccupancy = {}
	self._temporaryBlocks = {}
	self._flowFields = {}
	self._lastRequestAt = {}
	self._pendingWaypoints = {}
	self._pathRevision = 0
	self._simulationAccumulator = 0
	self._nextQueueId = 0
	self._nextUnitId = 0
	self._nextNetId = 0
	self._buildService = nil
	self._gameService = nil
	self._resourceService = nil
end

function ManpowerService:KnitStart()
	self._buildService = Knit.GetService("BuildService")
	self._gameService = Knit.GetService("GameService")
	self._resourceService = Knit.GetService("MatchResourceService")
	self:RebuildHexCache()

	self._trove:Add(CollectionService:GetInstanceAddedSignal(GridConfig.BuildableHexTag):Connect(function(instance)
		self:_scanGridHex(instance)
		self:_rebuildHexNeighbors()
		self:_invalidateNavigation()
	end))
	self._trove:Add(CollectionService:GetInstanceRemovedSignal(GridConfig.BuildableHexTag):Connect(function(instance)
		self:_removeGridHex(instance)
		self:_rebuildHexNeighbors()
		self:_invalidateNavigation()
	end))
	self._trove:Add(self._buildService.BuildingDestroyed:Connect(function(payload)
		self:_handleBuildingDestroyed(payload)
	end))
	self._trove:Add(self._buildService.CenterPathingChanged:Connect(function()
		self:_invalidateNavigation()
	end))
	self._trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self:_handlePlayerRemoving(player)
	end))
	self._trove:Add(RunService.Heartbeat:Connect(function(deltaTime: number)
		self:_stepHeartbeat(deltaTime)
	end))
end

function ManpowerService:RebuildHexCache()
	table.clear(self._gridByPart)
	table.clear(self._gridByKey)

	for _, taggedInstance in CollectionService:GetTagged(GridConfig.BuildableHexTag) do
		self:_scanGridHex(taggedInstance)
	end

	self:_rebuildHexNeighbors()
	self:_invalidateNavigation()
end

function ManpowerService:GetBarracksQueue(player: Player, buildingId: any): any
	local record, reason = self:_getOwnedBarracks(player, buildingId)
	if record == nil then
		return {
			ok = false,
			reason = reason,
		}
	end

	local queue = self._queues[record.BuildingId]
	return {
		ok = true,
		queue = if queue ~= nil then self:_snapshotQueue(queue) else self:_emptyQueueSnapshot(record.BuildingId),
	}
end

function ManpowerService:GetUnitsSnapshot(): any
	local now = os.clock()
	local units = {}

	for _, unit in self._units do
		table.insert(units, self:_snapshotUnit(unit, now))
	end

	return {
		TickSeconds = ManpowerConfig.Movement.SimulationTickSeconds,
		Units = units,
	}
end

function ManpowerService:RequestQueueUnit(player: Player, request: any): any
	if self:_isRateLimited(player, REQUEST_NAMES.Queue) then
		return { ok = false, reason = "RateLimited" }
	end

	if type(request) ~= "table" then
		return { ok = false, reason = "InvalidRequest" }
	end

	if self._gameService ~= nil and self._gameService:GetPlayerState(player) ~= PlayerStates.Playing then
		return { ok = false, reason = "NotPlaying" }
	end

	local record, barracksReason = self:_getOwnedBarracks(player, request.buildingId)
	if record == nil then
		return { ok = false, reason = barracksReason }
	end

	local definition = ManpowerConfig.GetUnit(request.unitType)
	if definition == nil then
		return { ok = false, reason = "InvalidUnit" }
	end

	local queue = self:_ensureQueue(record)
	if #queue.Entries >= ManpowerConfig.QueueCapacity then
		return { ok = false, reason = "QueueFull", queue = self:_snapshotQueue(queue) }
	end

	if getUnitSource(request.unitType, definition) == nil then
		return { ok = false, reason = "MissingUnitModel", queue = self:_snapshotQueue(queue) }
	end

	local canAfford, resourceReason =
		self._resourceService:CanAffordUnit(player, definition.Gold or 0, definition.Population or 0)
	if not canAfford then
		return { ok = false, reason = resourceReason, queue = self:_snapshotQueue(queue) }
	end

	self._resourceService:ApplyUnitQueued(player, definition.Gold or 0, definition.Population or 0)
	table.insert(queue.Entries, self:_createQueueEntry(request.unitType, definition))

	if #queue.Entries == 1 then
		self:_startQueueHead(queue)
	else
		self:_broadcastQueue(queue)
	end

	return {
		ok = true,
		queue = self:_snapshotQueue(queue),
	}
end

function ManpowerService:RequestMoveUnits(player: Player, request: any): any
	if self:_isRateLimited(player, REQUEST_NAMES.Move) then
		return { ok = false, reason = "RateLimited" }
	end

	if type(request) ~= "table" or type(request.unitIds) ~= "table" then
		return { ok = false, reason = "InvalidRequest" }
	end

	if self._gameService ~= nil and self._gameService:GetPlayerState(player) ~= PlayerStates.Playing then
		return { ok = false, reason = "NotPlaying" }
	end

	local destinationHex = self:_getHexRecord(request.destinationHex)
	if destinationHex == nil then
		return { ok = false, reason = "InvalidHex" }
	end

	if not self:_isHexNavigationPassable(destinationHex) then
		return { ok = false, reason = "BlockedTerrain" }
	end

	local units = {}
	local seenIds = {}
	for _, unitId in request.unitIds do
		if #units >= MAX_COMMAND_UNITS then
			break
		end

		if typeof(unitId) ~= "string" or seenIds[unitId] == true then
			continue
		end
		seenIds[unitId] = true

		local unit = self._units[unitId]
		if unit == nil or unit.Owner ~= player then
			continue
		end

		self:_cancelMoveOrder(unit, true)
		table.insert(units, unit)
	end

	local commanded = self:_assignMoveTargets(units, destinationHex)
	if commanded <= 0 then
		return { ok = false, reason = "NoMovableUnits" }
	end

	return {
		ok = true,
		commanded = commanded,
	}
end

function ManpowerService:DamageUnit(target: any, damage: any): { ok: boolean, reason: string?, hp: number? }
	if not isFiniteNumber(damage) or damage <= 0 then
		return { ok = false, reason = "InvalidDamage" }
	end

	local unitId = getUnitIdFromTarget(target)
	if unitId == nil then
		return { ok = false, reason = "InvalidUnit" }
	end

	local unit = self._units[unitId]
	if unit == nil then
		return { ok = false, reason = "MissingUnit" }
	end

	unit.HP = math.max(0, unit.HP - damage)
	if unit.HP <= 0 then
		self:_destroyUnit(unit, "Dead")
	end

	return {
		ok = true,
		hp = unit.HP,
	}
end

function ManpowerService:_emptyQueueSnapshot(buildingId: string): any
	return {
		BuildingId = buildingId,
		Capacity = ManpowerConfig.QueueCapacity,
		Count = 0,
		Entries = {},
	}
end

function ManpowerService:_snapshotQueue(queue: BarracksQueue): any
	local now = os.clock()
	local entries = table.create(#queue.Entries)

	for index = 1, #queue.Entries do
		local entry = queue.Entries[index]
		entries[index] = {
			Id = entry.Id,
			UnitType = entry.UnitType,
			DisplayName = entry.Definition.DisplayName,
			TrainingTime = entry.Definition.TrainingTime or 0,
			Progress = getQueueProgress(entry, now),
			Remaining = getQueueRemaining(entry, now),
			Ready = entry.Ready,
		}
	end

	return {
		BuildingId = queue.BuildingId,
		Capacity = ManpowerConfig.QueueCapacity,
		Count = #queue.Entries,
		Entries = entries,
	}
end

function ManpowerService:_snapshotUnit(unit: UnitRecord, now: number): any
	local snapshot = {
		NetId = unit.NetId,
		UnitId = unit.Id,
		UnitType = unit.UnitType,
		OwnerUserId = unit.Owner.UserId,
		HexKey = unit.CurrentHexKey,
		SlotIndex = unit.SlotIndex,
		HP = unit.HP,
		State = unit.StateMachine:GetState(),
	}

	local segment = unit.Segment
	if segment ~= nil then
		snapshot.Segment = {
			segment.FromKey,
			segment.ToKey,
			segment.SlotIndex,
			segment.Duration,
			math.clamp(now - segment.StartedAt, 0, segment.Duration),
		}
	end

	return snapshot
end

function ManpowerService:_broadcastQueue(queue: BarracksQueue)
	self.Client.QueueChanged:Fire(queue.Owner, self:_snapshotQueue(queue))
end

function ManpowerService:_broadcastEmptyQueue(owner: Player, buildingId: string)
	self.Client.QueueChanged:Fire(owner, self:_emptyQueueSnapshot(buildingId))
end

function ManpowerService:_getOwnedBarracks(player: Player, buildingId: any): (any?, string?)
	if typeof(buildingId) ~= "string" then
		return nil, "InvalidBuilding"
	end

	local record = self._buildService:GetPlacedBuildingRecord(buildingId)
	if record == nil then
		return nil, "MissingBuilding"
	end

	if record.Owner ~= player then
		return nil, "NotOwner"
	end

	if record.BuildingType ~= "Cuartel" then
		return nil, "NotBarracks"
	end

	return record, nil
end

function ManpowerService:_ensureQueue(record): BarracksQueue
	local queue = self._queues[record.BuildingId]
	if queue ~= nil then
		return queue
	end

	queue = {
		BuildingId = record.BuildingId,
		Owner = record.Owner,
		Entries = {},
	}
	self._queues[record.BuildingId] = queue

	return queue
end

function ManpowerService:_createQueueEntry(unitType: string, definition): QueueEntry
	self._nextQueueId += 1

	return {
		Id = `Queue_{self._nextQueueId}`,
		UnitType = unitType,
		Definition = definition,
		StartedAt = nil,
		ReadyAt = nil,
		Ready = false,
	}
end

function ManpowerService:_startQueueHead(queue: BarracksQueue)
	local entry = queue.Entries[1]
	if entry == nil then
		self:_broadcastQueue(queue)
		return
	end

	if entry.Ready then
		self:_scheduleSpawnRetry(queue, entry)
		self:_broadcastQueue(queue)
		return
	end

	local trainingTime = math.max(0, entry.Definition.TrainingTime or 0)
	entry.StartedAt = os.clock()
	entry.ReadyAt = entry.StartedAt + trainingTime
	self:_broadcastQueue(queue)

	task.delay(trainingTime, function()
		if self._destroyed then
			return
		end

		self:_completeQueueHead(queue, entry)
	end)
end

function ManpowerService:_completeQueueHead(queue: BarracksQueue, entry: QueueEntry)
	if self._queues[queue.BuildingId] ~= queue or queue.Entries[1] ~= entry then
		return
	end

	entry.Ready = true
	entry.ReadyAt = os.clock()
	local spawned = self:_trySpawnQueueHead(queue, entry)
	if not spawned then
		self:_broadcastQueue(queue)
		self:_scheduleSpawnRetry(queue, entry)
	end
end

function ManpowerService:_scheduleSpawnRetry(queue: BarracksQueue, entry: QueueEntry)
	task.delay(ManpowerConfig.Movement.BlockedSpawnRetrySeconds, function()
		if
			self._destroyed
			or self._queues[queue.BuildingId] ~= queue
			or queue.Entries[1] ~= entry
			or not entry.Ready
		then
			return
		end

		if not self:_trySpawnQueueHead(queue, entry) then
			self:_scheduleSpawnRetry(queue, entry)
		end
	end)
end

function ManpowerService:_trySpawnQueueHead(queue: BarracksQueue, entry: QueueEntry): boolean
	local buildingRecord = self._buildService:GetPlacedBuildingRecord(queue.BuildingId)
	if buildingRecord == nil or buildingRecord.Owner ~= queue.Owner or buildingRecord.BuildingType ~= "Cuartel" then
		self:_cancelQueue(queue, true)
		return true
	end

	local spawnHex, spawnSlot = self:_findBarracksSpawnSlot(buildingRecord.HexPart)
	if spawnHex == nil or spawnSlot == nil then
		return false
	end

	local unit = self:_spawnUnit(queue.Owner, entry.UnitType, entry.Definition, spawnHex, spawnSlot)
	if unit == nil then
		table.remove(queue.Entries, 1)
		self._resourceService:ReleaseUnitPopulation(queue.Owner, entry.Definition.Population or 0)
		self:_startQueueHead(queue)
		return true
	end

	table.remove(queue.Entries, 1)
	self:_startQueueHead(queue)
	return true
end

function ManpowerService:_findBarracksSpawnSlot(hexPart: BasePart): (HexRecord?, number?)
	local barracksHex = self:_getHexRecord(hexPart)
	if barracksHex == nil then
		return nil, nil
	end

	for index = 1, #barracksHex.Neighbors do
		local spawnHex = barracksHex.Neighbors[index]
		if self:_isHexNavigationPassable(spawnHex) then
			local spawnSlot = self:_getAvailableSlot(spawnHex.Key)
			if spawnSlot ~= nil then
				return spawnHex, spawnSlot
			end
		end
	end

	return nil, nil
end

function ManpowerService:_spawnUnit(
	owner: Player,
	unitType: string,
	definition,
	spawnHex: HexRecord,
	spawnSlot: number
): UnitRecord?
	if getUnitSource(unitType, definition) == nil then
		return nil
	end

	self._nextUnitId += 1
	self._nextNetId += 1
	local unitId = `{unitType}_{owner.UserId}_{self._nextUnitId}`
	local unitTrove = Trove.new()
	self._trove:Add(unitTrove)
	local unitStateMachine = StateMachine.new(ManpowerConfig.UnitStates.Idle, ManpowerConfig.UnitStateTransitions)
	unitTrove:Add(unitStateMachine)

	local unit = {
		Id = unitId,
		NetId = self._nextNetId,
		Owner = owner,
		UnitType = unitType,
		Definition = definition,
		HP = definition.HP or 1,
		CurrentHexKey = spawnHex.Key,
		SlotIndex = spawnSlot,
		OrderDestinationKey = nil,
		TargetHexKey = nil,
		TargetSlotIndex = nil,
		TargetReserved = false,
		TargetDistance = 0,
		Segment = nil,
		AttemptedHexKey = nil,
		LastHexChangedAt = os.clock(),
		LastRepathAt = 0,
		StuckFailures = 0,
		OrderToken = 0,
		StateMachine = unitStateMachine,
		Trove = unitTrove,
	}

	self._units[unitId] = unit
	self:_indexOwnerUnit(unit)
	self:_occupySlot(spawnHex.Key, unit, spawnSlot)
	self.Client.UnitSpawned:FireAll(self:_snapshotUnit(unit, os.clock()))

	return unit
end

function ManpowerService:_assignMoveTargets(units: { UnitRecord }, destinationHex: HexRecord): number
	if #units <= 0 then
		return 0
	end

	local now = os.clock()
	local commanded = 0
	local nextUnitIndex = 1
	local open = { destinationHex }
	local openIndex = 1
	local visited = { [destinationHex.Key] = true }

	while openIndex <= #open and nextUnitIndex <= #units do
		local candidate = open[openIndex]
		openIndex += 1

		if self:_isHexNavigationPassable(candidate) then
			while nextUnitIndex <= #units do
				local unit = units[nextUnitIndex]
				local slotIndex, reserved = self:_reserveTargetSlot(unit, candidate.Key)
				if slotIndex == nil then
					break
				end

				unit.OrderDestinationKey = destinationHex.Key
				unit.TargetHexKey = candidate.Key
				unit.TargetSlotIndex = slotIndex
				unit.TargetReserved = reserved
				unit.TargetDistance = HexUtils.distance(candidate.Q, candidate.R, destinationHex.Q, destinationHex.R)
				unit.LastHexChangedAt = now
				unit.LastRepathAt = 0
				unit.StuckFailures = 0
				unit.AttemptedHexKey = nil
				unit.OrderToken += 1
				unit.StateMachine:TransitionTo(ManpowerConfig.UnitStates.Moving, {
					Reason = "MoveOrder",
				})
				self._activeUnits[unit.Id] = unit
				commanded += 1
				nextUnitIndex += 1
			end
		end

		for index = 1, #candidate.Neighbors do
			local neighbor = candidate.Neighbors[index]
			if visited[neighbor.Key] ~= true then
				visited[neighbor.Key] = true
				table.insert(open, neighbor)
			end
		end
	end

	return commanded
end

function ManpowerService:_stepHeartbeat(deltaTime: number)
	if self._destroyed then
		return
	end

	self._simulationAccumulator += math.min(deltaTime, 0.5)
	local stepSeconds = ManpowerConfig.Movement.SimulationTickSeconds
	while self._simulationAccumulator >= stepSeconds do
		self._simulationAccumulator -= stepSeconds
		self:_stepSimulation(os.clock())
	end
end

function ManpowerService:_stepSimulation(now: number)
	self:_pruneTemporaryBlocks(now)

	for _, unit in self._activeUnits do
		if self._units[unit.Id] ~= unit then
			self._activeUnits[unit.Id] = nil
			continue
		end

		self:_stepUnit(unit, now)
	end

	self:_flushWaypointBatch()
end

function ManpowerService:_stepUnit(unit: UnitRecord, now: number)
	local segment = unit.Segment
	if segment ~= nil then
		if now < segment.ArrivesAt then
			return
		end

		self:_finishSegment(unit, segment, now)
	end

	if unit.TargetHexKey == nil or unit.OrderDestinationKey == nil then
		self._activeUnits[unit.Id] = nil
		return
	end

	if unit.CurrentHexKey == unit.TargetHexKey then
		self:_finishMoveOrder(unit)
		return
	end

	local nextHex = self:_getNextHexForUnit(unit)
	if nextHex ~= nil and self:_tryStartSegment(unit, nextHex, now) then
		return
	end

	if nextHex ~= nil then
		unit.AttemptedHexKey = nextHex.Key
	end
	unit.StateMachine:TransitionTo(ManpowerConfig.UnitStates.Waiting, {
		Reason = "NoStep",
	})
	self:_updateStuckUnit(unit, now)
end

function ManpowerService:_getNextHexForUnit(unit: UnitRecord): HexRecord?
	local currentHex = self._gridByKey[unit.CurrentHexKey]
	local targetHex = if unit.TargetHexKey ~= nil then self._gridByKey[unit.TargetHexKey] else nil
	local destinationHex = if unit.OrderDestinationKey ~= nil then self._gridByKey[unit.OrderDestinationKey] else nil
	if currentHex == nil or targetHex == nil or destinationHex == nil then
		return nil
	end

	local useSpreadStep = targetHex ~= destinationHex
		and HexUtils.distance(currentHex.Q, currentHex.R, destinationHex.Q, destinationHex.R)
			<= unit.TargetDistance + ManpowerConfig.Movement.DestinationSpreadRadius
	if useSpreadStep then
		local localStep = self:_getLocalStepTowardTarget(unit, currentHex, targetHex)
		if localStep ~= nil then
			return localStep
		end
	end

	local primaryField = self:_getFlowField(destinationHex.Key)
	if primaryField ~= nil then
		local nextKey = primaryField.NextByKey[currentHex.Key]
		local nextHex = if nextKey ~= nil then self._gridByKey[nextKey] else nil
		if nextHex ~= nil then
			return nextHex
		end
	end

	if targetHex ~= destinationHex then
		local targetField = self:_getFlowField(targetHex.Key)
		if targetField ~= nil then
			local nextKey = targetField.NextByKey[currentHex.Key]
			return if nextKey ~= nil then self._gridByKey[nextKey] else nil
		end
	end

	return nil
end

function ManpowerService:_getLocalStepTowardTarget(
	unit: UnitRecord,
	currentHex: HexRecord,
	targetHex: HexRecord
): HexRecord?
	local currentDistance = HexUtils.distance(currentHex.Q, currentHex.R, targetHex.Q, targetHex.R)
	local bestHex = nil
	local bestDistance = math.huge

	for index = 1, #currentHex.Neighbors do
		local neighbor = currentHex.Neighbors[index]
		local neighborDistance = HexUtils.distance(neighbor.Q, neighbor.R, targetHex.Q, targetHex.R)
		if
			neighborDistance < currentDistance
			and neighborDistance < bestDistance
			and self:_isHexNavigationPassable(neighbor)
			and self:_canUnitEnterHex(unit, neighbor.Key)
		then
			bestHex = neighbor
			bestDistance = neighborDistance
		end
	end

	return bestHex
end

function ManpowerService:_tryStartSegment(unit: UnitRecord, nextHex: HexRecord, now: number): boolean
	if not self:_isHexNavigationPassable(nextHex) then
		return false
	end

	local slotIndex = self:_reserveStepSlot(unit, nextHex.Key)
	if slotIndex == nil then
		return false
	end

	local currentHex = self._gridByKey[unit.CurrentHexKey]
	if currentHex == nil then
		self:_releaseReservation(nextHex.Key, unit.Id, slotIndex)
		return false
	end

	local distance = (nextHex.Center - currentHex.Center).Magnitude
	local speed = getUnitSpeed(unit.Definition)
	local duration = math.max(distance / speed, ManpowerConfig.Movement.SimulationTickSeconds)
	unit.Segment = {
		FromKey = currentHex.Key,
		ToKey = nextHex.Key,
		SlotIndex = slotIndex,
		StartedAt = now,
		ArrivesAt = now + duration,
		Duration = duration,
	}
	unit.AttemptedHexKey = nextHex.Key
	unit.StateMachine:TransitionTo(ManpowerConfig.UnitStates.Moving, {
		Reason = "SegmentStarted",
		ToKey = nextHex.Key,
	})
	self:_queueWaypoint(unit, currentHex.Key, nextHex.Key, slotIndex, duration)
	return true
end

function ManpowerService:_finishSegment(unit: UnitRecord, segment: MoveSegment, now: number)
	if unit.Segment ~= segment then
		return
	end

	self:_releaseOccupiedSlot(segment.FromKey, unit)
	self:_occupySlot(segment.ToKey, unit, segment.SlotIndex)
	unit.CurrentHexKey = segment.ToKey
	unit.SlotIndex = segment.SlotIndex
	unit.Segment = nil
	unit.AttemptedHexKey = nil
	unit.LastHexChangedAt = now
	unit.StuckFailures = 0

	if unit.TargetHexKey == unit.CurrentHexKey then
		unit.TargetReserved = false
		self:_finishMoveOrder(unit)
	end
end

function ManpowerService:_finishMoveOrder(unit: UnitRecord)
	if unit.TargetReserved and unit.TargetHexKey ~= nil and unit.TargetSlotIndex ~= nil then
		self:_releaseReservation(unit.TargetHexKey, unit.Id, unit.TargetSlotIndex)
	end

	unit.OrderDestinationKey = nil
	unit.TargetHexKey = nil
	unit.TargetSlotIndex = nil
	unit.TargetReserved = false
	unit.TargetDistance = 0
	unit.AttemptedHexKey = nil
	unit.StateMachine:TransitionTo(ManpowerConfig.UnitStates.Idle, {
		Reason = "MoveFinished",
	})
	self._activeUnits[unit.Id] = nil
end

function ManpowerService:_cancelMoveOrder(unit: UnitRecord, queueCorrection: boolean)
	local segment = unit.Segment
	if segment ~= nil then
		self:_releaseReservation(segment.ToKey, unit.Id, segment.SlotIndex)
		unit.Segment = nil
	end

	if unit.TargetReserved and unit.TargetHexKey ~= nil and unit.TargetSlotIndex ~= nil then
		self:_releaseReservation(unit.TargetHexKey, unit.Id, unit.TargetSlotIndex)
	end

	unit.OrderDestinationKey = nil
	unit.TargetHexKey = nil
	unit.TargetSlotIndex = nil
	unit.TargetReserved = false
	unit.TargetDistance = 0
	unit.AttemptedHexKey = nil
	unit.OrderToken += 1
	unit.StateMachine:TransitionTo(ManpowerConfig.UnitStates.Idle, {
		Reason = "MoveCancelled",
	})
	self._activeUnits[unit.Id] = nil

	if queueCorrection then
		self:_queueWaypoint(
			unit,
			unit.CurrentHexKey,
			unit.CurrentHexKey,
			unit.SlotIndex,
			ManpowerConfig.Movement.SimulationTickSeconds
		)
	end
end

function ManpowerService:_updateStuckUnit(unit: UnitRecord, now: number)
	local stalledSeconds = now - unit.LastHexChangedAt
	if stalledSeconds >= ManpowerConfig.Movement.RepathDelaySeconds then
		self:_requestUnitRepath(unit, now)
	end

	if stalledSeconds < ManpowerConfig.Movement.StuckSeconds then
		return
	end

	unit.StuckFailures += 1
	unit.LastHexChangedAt = now

	if unit.StuckFailures < ManpowerConfig.Movement.MaxStuckFailures then
		return
	end

	self:_recoverStuckUnit(unit, now)
end

function ManpowerService:_requestUnitRepath(unit: UnitRecord, now: number)
	if now - unit.LastRepathAt < ManpowerConfig.Movement.RepathCooldownSeconds then
		return
	end

	unit.LastRepathAt = now
	unit.StateMachine:TransitionTo(ManpowerConfig.UnitStates.Repathing, {
		Reason = "StepBlocked",
		BlockedKey = unit.AttemptedHexKey,
	})

	if unit.AttemptedHexKey ~= nil and self._temporaryBlocks[unit.AttemptedHexKey] == nil then
		self:_temporarilyBlockHex(unit.AttemptedHexKey, now)
	end
end

function ManpowerService:_recoverStuckUnit(unit: UnitRecord, now: number)
	local currentHex = self._gridByKey[unit.CurrentHexKey]
	if currentHex == nil then
		return
	end

	for index = 1, #currentHex.Neighbors do
		local neighbor = currentHex.Neighbors[index]
		if self:_canUnitEnterHex(unit, neighbor.Key) and self:_tryStartSegment(unit, neighbor, now) then
			unit.StuckFailures = 0
			return
		end
	end

	unit.StateMachine:TransitionTo(ManpowerConfig.UnitStates.Waiting, {
		Reason = "RecoveryBlocked",
	})
end

function ManpowerService:_queueWaypoint(
	unit: UnitRecord,
	fromKey: string,
	toKey: string,
	slotIndex: number,
	duration: number
)
	table.insert(self._pendingWaypoints, {
		unit.NetId,
		fromKey,
		toKey,
		slotIndex,
		duration,
	})
end

function ManpowerService:_flushWaypointBatch()
	if #self._pendingWaypoints <= 0 then
		return
	end

	local batch = self._pendingWaypoints
	self._pendingWaypoints = {}
	self.Client.BatchWaypoints:FireAll(batch)
end

function ManpowerService:_getFlowField(destinationKey: string): FlowField?
	local cached = self._flowFields[destinationKey]
	if cached ~= nil and cached.Revision == self._pathRevision then
		return cached
	end

	local destinationHex = self._gridByKey[destinationKey]
	if destinationHex == nil or not self:_isHexNavigationPassable(destinationHex) then
		return nil
	end

	local nextByKey = {}
	local distanceByKey = { [destinationKey] = 0 }
	local open = { destinationHex }
	local openIndex = 1

	while openIndex <= #open do
		local current = open[openIndex]
		openIndex += 1
		local currentDistance = distanceByKey[current.Key] or 0

		for index = 1, #current.Neighbors do
			local neighbor = current.Neighbors[index]
			if distanceByKey[neighbor.Key] == nil and self:_isHexNavigationPassable(neighbor) then
				distanceByKey[neighbor.Key] = currentDistance + 1
				nextByKey[neighbor.Key] = current.Key
				table.insert(open, neighbor)
			end
		end
	end

	local field = {
		Revision = self._pathRevision,
		DestinationKey = destinationKey,
		NextByKey = nextByKey,
		DistanceByKey = distanceByKey,
	}
	self._flowFields[destinationKey] = field
	return field
end

function ManpowerService:_invalidateNavigation()
	self._pathRevision += 1
	table.clear(self._flowFields)
end

function ManpowerService:_temporarilyBlockHex(hexKey: string, now: number)
	local expiresAt = now + ManpowerConfig.Movement.TemporaryBlockSeconds
	if (self._temporaryBlocks[hexKey] or 0) >= expiresAt then
		return
	end

	self._temporaryBlocks[hexKey] = expiresAt
	self:_invalidateNavigation()
end

function ManpowerService:_pruneTemporaryBlocks(now: number)
	local changed = false
	for hexKey, expiresAt in self._temporaryBlocks do
		if expiresAt <= now then
			self._temporaryBlocks[hexKey] = nil
			changed = true
		end
	end

	if changed then
		self:_invalidateNavigation()
	end
end

function ManpowerService:_isHexNavigationPassable(hexRecord: HexRecord): boolean
	if not hexRecord.Passable or hexRecord.Part.Parent == nil then
		return false
	end

	if self._temporaryBlocks[hexRecord.Key] ~= nil then
		return false
	end

	return self._buildService == nil or not self._buildService:IsHexCenterBlocked(hexRecord.Part)
end

function ManpowerService:_reserveTargetSlot(unit: UnitRecord, hexKey: string): (number?, boolean)
	if unit.CurrentHexKey == hexKey then
		return unit.SlotIndex, false
	end

	local slotIndex = self:_reserveSlot(hexKey, unit.Id)
	return slotIndex, slotIndex ~= nil
end

function ManpowerService:_reserveStepSlot(unit: UnitRecord, hexKey: string): number?
	if unit.TargetHexKey == hexKey and unit.TargetSlotIndex ~= nil then
		local occupancy = self:_ensureHexOccupancy(hexKey)
		local reservation = occupancy.Reservations[unit.TargetSlotIndex]
		if reservation == unit.Id then
			return unit.TargetSlotIndex
		end
	end

	return self:_reserveSlot(hexKey, unit.Id)
end

function ManpowerService:_reserveSlot(hexKey: string, unitId: string): number?
	local slotIndex = self:_getAvailableSlot(hexKey, unitId)
	if slotIndex == nil then
		return nil
	end

	local occupancy = self:_ensureHexOccupancy(hexKey)
	occupancy.Reservations[slotIndex] = unitId
	return slotIndex
end

function ManpowerService:_occupySlot(hexKey: string, unit: UnitRecord, slotIndex: number)
	local occupancy = self:_ensureHexOccupancy(hexKey)
	occupancy.Units[unit.Id] = slotIndex
	occupancy.Slots[slotIndex] = unit.Id
	if occupancy.Reservations[slotIndex] == unit.Id then
		occupancy.Reservations[slotIndex] = nil
	end
end

function ManpowerService:_releaseOccupiedSlot(hexKey: string, unit: UnitRecord)
	local occupancy = self._hexOccupancy[hexKey]
	if occupancy == nil then
		return
	end

	local slotIndex = occupancy.Units[unit.Id]
	if slotIndex ~= nil then
		occupancy.Units[unit.Id] = nil
		if occupancy.Slots[slotIndex] == unit.Id then
			occupancy.Slots[slotIndex] = nil
		end
	end

	self:_trimHexOccupancy(hexKey, occupancy)
end

function ManpowerService:_releaseReservation(hexKey: string, unitId: string, slotIndex: number)
	local occupancy = self._hexOccupancy[hexKey]
	if occupancy == nil then
		return
	end

	if occupancy.Reservations[slotIndex] == unitId then
		occupancy.Reservations[slotIndex] = nil
	end
	self:_trimHexOccupancy(hexKey, occupancy)
end

function ManpowerService:_getAvailableSlot(hexKey: string, reservedFor: string?): number?
	local occupancy = self._hexOccupancy[hexKey]
	for slotIndex = 1, ManpowerConfig.Movement.MaxUnitsPerHex do
		local occupiedBy = if occupancy ~= nil then occupancy.Slots[slotIndex] else nil
		local reservedBy = if occupancy ~= nil then occupancy.Reservations[slotIndex] else nil
		if occupiedBy == nil and (reservedBy == nil or reservedBy == reservedFor) then
			return slotIndex
		end
	end

	return nil
end

function ManpowerService:_canUnitEnterHex(unit: UnitRecord, hexKey: string): boolean
	local hexRecord = self._gridByKey[hexKey]
	if hexRecord == nil or not self:_isHexNavigationPassable(hexRecord) then
		return false
	end

	if unit.TargetHexKey == hexKey and unit.TargetSlotIndex ~= nil and unit.TargetReserved then
		local occupancy = self._hexOccupancy[hexKey]
		return occupancy ~= nil and occupancy.Reservations[unit.TargetSlotIndex] == unit.Id
	end

	return self:_getAvailableSlot(hexKey, unit.Id) ~= nil
end

function ManpowerService:_ensureHexOccupancy(hexKey: string): HexOccupancy
	local occupancy = self._hexOccupancy[hexKey]
	if occupancy ~= nil then
		return occupancy
	end

	occupancy = {
		Units = {},
		Slots = {},
		Reservations = {},
	}
	self._hexOccupancy[hexKey] = occupancy
	return occupancy
end

function ManpowerService:_trimHexOccupancy(hexKey: string, occupancy: HexOccupancy)
	if next(occupancy.Units) == nil and next(occupancy.Reservations) == nil then
		self._hexOccupancy[hexKey] = nil
	end
end

function ManpowerService:_indexOwnerUnit(unit: UnitRecord)
	local ownerUnits = self._unitsByOwner[unit.Owner]
	if ownerUnits == nil then
		ownerUnits = {}
		self._unitsByOwner[unit.Owner] = ownerUnits
	end

	ownerUnits[unit.Id] = unit
end

function ManpowerService:_unindexOwnerUnit(unit: UnitRecord)
	local ownerUnits = self._unitsByOwner[unit.Owner]
	if ownerUnits == nil then
		return
	end

	ownerUnits[unit.Id] = nil
	if next(ownerUnits) == nil then
		self._unitsByOwner[unit.Owner] = nil
	end
end

function ManpowerService:_getHexRecord(target: any): HexRecord?
	if typeof(target) ~= "Instance" or not target:IsA("BasePart") then
		return nil
	end

	return self._gridByPart[target]
end

function ManpowerService:_scanGridHex(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	local hexPart = instance :: BasePart
	local coord = HexUtils.getHexCoordFromPart(hexPart, GridConfig)
	local key = HexUtils.toKey(coord.q, coord.r)
	local record = {
		Key = key,
		Part = hexPart,
		Q = coord.q,
		R = coord.r,
		Center = HexUtils.getHexTopCenterFromPart(hexPart),
		Passable = ManpowerConfig.TerrainPassable[getTerrainType(hexPart)] == true,
		Neighbors = {},
	}

	self._gridByPart[hexPart] = record
	self._gridByKey[key] = record
end

function ManpowerService:_rebuildHexNeighbors()
	for _, record in self._gridByKey do
		table.clear(record.Neighbors)
		for directionIndex = 1, 6 do
			local neighborCoord = HexUtils.getNeighbor(record.Q, record.R, directionIndex)
			local neighbor = self._gridByKey[HexUtils.toKey(neighborCoord.q, neighborCoord.r)]
			if neighbor ~= nil then
				table.insert(record.Neighbors, neighbor)
			end
		end
	end
end

function ManpowerService:_removeGridHex(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	local record = self._gridByPart[instance]
	if record == nil then
		return
	end

	self._gridByPart[instance] = nil
	if self._gridByKey[record.Key] == record then
		self._gridByKey[record.Key] = nil
	end
end

function ManpowerService:_isRateLimited(player: Player, requestName: string): boolean
	local now = os.clock()
	local requestTimes = self._lastRequestAt[player]
	if requestTimes == nil then
		requestTimes = {}
		self._lastRequestAt[player] = requestTimes
	end

	local lastRequest = requestTimes[requestName]
	requestTimes[requestName] = now

	return lastRequest ~= nil and now - lastRequest < MIN_REQUEST_INTERVAL
end

function ManpowerService:_cancelQueue(queue: BarracksQueue, releasePopulation: boolean)
	if self._queues[queue.BuildingId] ~= queue then
		return
	end

	self._queues[queue.BuildingId] = nil
	if releasePopulation then
		for index = 1, #queue.Entries do
			local entry = queue.Entries[index]
			self._resourceService:ReleaseUnitPopulation(queue.Owner, entry.Definition.Population or 0)
		end
	end

	table.clear(queue.Entries)
	self:_broadcastEmptyQueue(queue.Owner, queue.BuildingId)
end

function ManpowerService:_destroyUnit(unit: UnitRecord, reason: string)
	if self._units[unit.Id] ~= unit then
		return
	end

	self:_cancelMoveOrder(unit, false)
	self._units[unit.Id] = nil
	self._activeUnits[unit.Id] = nil
	self:_unindexOwnerUnit(unit)
	self:_releaseOccupiedSlot(unit.CurrentHexKey, unit)
	unit.Trove:Destroy()
	self._resourceService:ReleaseUnitPopulation(unit.Owner, unit.Definition.Population or 0)
	self.Client.UnitDestroyed:FireAll({
		NetId = unit.NetId,
		UnitId = unit.Id,
		Reason = reason,
	})
end

function ManpowerService:_handleBuildingDestroyed(payload)
	if type(payload) ~= "table" or payload.BuildingType ~= "Cuartel" then
		return
	end

	local queue = self._queues[payload.BuildingId]
	if queue ~= nil then
		self:_cancelQueue(queue, true)
	end
end

function ManpowerService:_handlePlayerRemoving(player: Player)
	self._lastRequestAt[player] = nil

	local queues = {}
	for _, queue in self._queues do
		if queue.Owner == player then
			table.insert(queues, queue)
		end
	end
	for index = 1, #queues do
		self:_cancelQueue(queues[index], false)
	end

	local ownerUnits = self._unitsByOwner[player]
	if ownerUnits == nil then
		return
	end

	local units = {}
	for _, unit in ownerUnits do
		table.insert(units, unit)
	end
	for index = 1, #units do
		self:_destroyUnit(units[index], "OwnerLeft")
	end
end

function ManpowerService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	local queues = {}
	for _, queue in self._queues do
		table.insert(queues, queue)
	end
	for index = 1, #queues do
		self:_cancelQueue(queues[index], false)
	end

	local units = {}
	for _, unit in self._units do
		table.insert(units, unit)
	end
	for index = 1, #units do
		self:_destroyUnit(units[index], "ServiceDestroyed")
	end

	self._trove:Destroy()
	table.clear(self._queues)
	table.clear(self._units)
	table.clear(self._unitsByOwner)
	table.clear(self._activeUnits)
	table.clear(self._gridByPart)
	table.clear(self._gridByKey)
	table.clear(self._hexOccupancy)
	table.clear(self._temporaryBlocks)
	table.clear(self._flowFields)
	table.clear(self._lastRequestAt)
	table.clear(self._pendingWaypoints)
end

return ManpowerService
