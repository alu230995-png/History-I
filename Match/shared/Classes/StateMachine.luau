local Packages = script.Parent.Parent.Parent:WaitForChild("Packages")
local Signal = require(Packages:WaitForChild("Signal"))
local Trove = require(Packages:WaitForChild("Trove"))

local StateMachine = {}
StateMachine.__index = StateMachine

export type Transition = {
	OldState: string,
	NewState: string,
	Context: any?,
	StateTrove: any,
}

export type StateMachine = typeof(setmetatable(
	{} :: {
		_allowedTransitions: { [string]: { [string]: boolean } }?,
		_destroyed: boolean,
		_state: string,
		_stateTrove: any,
		_transitionSignal: any,
		_trove: any,
	},
	StateMachine
))

local function canTransition(
	allowedTransitions: { [string]: { [string]: boolean } }?,
	oldState: string,
	newState: string
): boolean
	if allowedTransitions == nil then
		return true
	end

	local allowedFromCurrent = allowedTransitions[oldState]
	if allowedFromCurrent == nil then
		return false
	end

	return allowedFromCurrent[newState] == true
end

function StateMachine.new(initialState: string, allowedTransitions: { [string]: { [string]: boolean } }?): StateMachine
	assert(
		type(initialState) == "string" and initialState ~= "",
		"StateMachine initialState must be a non-empty string"
	)

	local self = setmetatable({}, StateMachine)
	self._allowedTransitions = allowedTransitions
	self._destroyed = false
	self._state = initialState
	self._stateTrove = Trove.new()
	self._transitionSignal = Signal.new()
	self._trove = Trove.new()
	self._trove:Add(self._transitionSignal)

	return self
end

function StateMachine:GetState(): string
	return self._state
end

function StateMachine:GetStateTrove()
	return self._stateTrove
end

function StateMachine:OnTransition(callback: (Transition) -> ())
	assert(type(callback) == "function", "StateMachine:OnTransition requires a callback")

	return self._transitionSignal:Connect(callback)
end

function StateMachine:TransitionTo(newState: string, context: any?): (boolean, any?)
	if self._destroyed then
		warn("[FSM] Ignored transition on destroyed state machine")
		return false, nil
	end

	if type(newState) ~= "string" or newState == "" then
		warn("[FSM] Invalid transition target")
		return false, nil
	end

	local oldState = self._state
	if oldState == newState then
		return true, self._stateTrove
	end

	if not canTransition(self._allowedTransitions, oldState, newState) then
		warn(("[FSM] Invalid transition: %s -> %s"):format(oldState, newState))
		return false, self._stateTrove
	end

	self._stateTrove:Destroy()
	self._stateTrove = Trove.new()
	self._state = newState

	self._transitionSignal:Fire({
		OldState = oldState,
		NewState = newState,
		Context = context,
		StateTrove = self._stateTrove,
	})

	return true, self._stateTrove
end

function StateMachine:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._stateTrove:Destroy()
	self._trove:Destroy()
end

return StateMachine
