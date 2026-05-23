local ArmyPhaseConfig = {}

ArmyPhaseConfig.Phases = table.freeze({
	Phase1 = "Phase1",
	Phase2 = "Phase2",
})

ArmyPhaseConfig.DefaultPhase = ArmyPhaseConfig.Phases.Phase1

ArmyPhaseConfig.AllowedTransitions = table.freeze({
	[ArmyPhaseConfig.Phases.Phase1] = table.freeze({
		[ArmyPhaseConfig.Phases.Phase2] = true,
	}),
	[ArmyPhaseConfig.Phases.Phase2] = table.freeze({}),
})

function ArmyPhaseConfig.IsValidPhase(phase: any): boolean
	if typeof(phase) ~= "string" then
		return false
	end

	for _, configuredPhase in ArmyPhaseConfig.Phases do
		if phase == configuredPhase then
			return true
		end
	end

	return false
end

function ArmyPhaseConfig.CanTransition(currentPhase: any, nextPhase: any): boolean
	local transitions = ArmyPhaseConfig.AllowedTransitions[currentPhase]
	return transitions ~= nil and transitions[nextPhase] == true
end

return table.freeze(ArmyPhaseConfig)
