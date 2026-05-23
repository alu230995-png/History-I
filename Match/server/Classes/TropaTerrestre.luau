local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local Tropa = require(script.Parent:WaitForChild("Tropa"))

local TropaTerrestre = {}
TropaTerrestre.__index = TropaTerrestre
setmetatable(TropaTerrestre, {
	__index = Tropa,
})

local function getUnitSpeed(definition): number
	local movement = definition.Movement
	local configuredSpeed = if type(movement) == "table" then movement.Speed else definition.Speed
	if
		typeof(configuredSpeed) ~= "number"
		or configuredSpeed ~= configuredSpeed
		or math.abs(configuredSpeed) == math.huge
	then
		return 0.001
	end

	return math.max(configuredSpeed, 0.001)
end

function TropaTerrestre.new(params)
	local self = Tropa.new(params)
	setmetatable(self, TropaTerrestre)

	self.CurrentHexKey = params.CurrentHexKey
	self.SlotIndex = params.SlotIndex
	self.OrderDestinationKey = nil
	self.TargetHexKey = nil
	self.TargetSlotIndex = nil
	self.TargetReserved = false
	self.TargetDistance = 0
	self.Segment = nil
	self.AttemptedHexKey = nil
	self.LastHexChangedAt = params.Now or os.clock()
	self.LastRepathAt = 0
	self.StuckFailures = 0
	self.OrderToken = 0
	self.MovementProfile = ManpowerConfig.MovementProfiles.Terrestrial

	return self
end

function TropaTerrestre:GetSpeed(): number
	return getUnitSpeed(self.Definition)
end

function TropaTerrestre:SetMoveTarget(
	destinationKey: string,
	targetKey: string,
	slotIndex: number,
	reserved: boolean,
	targetDistance: number,
	now: number
)
	self.OrderDestinationKey = destinationKey
	self.TargetHexKey = targetKey
	self.TargetSlotIndex = slotIndex
	self.TargetReserved = reserved
	self.TargetDistance = targetDistance
	self.LastHexChangedAt = now
	self.LastRepathAt = 0
	self.StuckFailures = 0
	self.AttemptedHexKey = nil
	self.OrderToken += 1
	self.StateMachine:TransitionTo(ManpowerConfig.UnitStates.Moving, {
		Reason = "MoveOrder",
	})
end

function TropaTerrestre:StartSegment(fromKey: string, toKey: string, slotIndex: number, now: number, duration: number)
	self.Segment = {
		FromKey = fromKey,
		ToKey = toKey,
		SlotIndex = slotIndex,
		StartedAt = now,
		ArrivesAt = now + duration,
		Duration = duration,
	}
	self.AttemptedHexKey = toKey
	self.StateMachine:TransitionTo(ManpowerConfig.UnitStates.Moving, {
		Reason = "SegmentStarted",
		ToKey = toKey,
	})
end

function TropaTerrestre:FinishSegment(segment, now: number)
	if self.Segment ~= segment then
		return false
	end

	self.CurrentHexKey = segment.ToKey
	self.SlotIndex = segment.SlotIndex
	self.Segment = nil
	self.AttemptedHexKey = nil
	self.LastHexChangedAt = now
	self.StuckFailures = 0
	return true
end

function TropaTerrestre:FinishMoveOrder()
	self.OrderDestinationKey = nil
	self.TargetHexKey = nil
	self.TargetSlotIndex = nil
	self.TargetReserved = false
	self.TargetDistance = 0
	self.AttemptedHexKey = nil
	self.StateMachine:TransitionTo(ManpowerConfig.UnitStates.Idle, {
		Reason = "MoveFinished",
	})
end

function TropaTerrestre:CancelMoveOrder()
	self.Segment = nil
	self.OrderDestinationKey = nil
	self.TargetHexKey = nil
	self.TargetSlotIndex = nil
	self.TargetReserved = false
	self.TargetDistance = 0
	self.AttemptedHexKey = nil
	self.OrderToken += 1
	self.StateMachine:TransitionTo(ManpowerConfig.UnitStates.Idle, {
		Reason = "MoveCancelled",
	})
end

function TropaTerrestre:GetCombatPosition(gridByKey, now: number?): Vector3?
	local segment = self.Segment
	if segment ~= nil then
		local fromHex = gridByKey[segment.FromKey]
		local toHex = gridByKey[segment.ToKey]
		if fromHex ~= nil and toHex ~= nil then
			local alpha = math.clamp(((now or os.clock()) - segment.StartedAt) / segment.Duration, 0, 1)
			return fromHex.Center:Lerp(toHex.Center, alpha)
		end
	end

	local currentHex = gridByKey[self.CurrentHexKey]
	return if currentHex ~= nil then currentHex.Center else nil
end

return TropaTerrestre
