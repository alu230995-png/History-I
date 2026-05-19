local NexoConfig = {}

NexoConfig.TagKeyword = "Nexo"
NexoConfig.SelectionDurationSeconds = 10
NexoConfig.AssignmentMessageSeconds = 3
NexoConfig.HexRaycastHeight = 160
NexoConfig.HexRaycastDepth = 420

NexoConfig.States = table.freeze({
	Available = "available",
	Selected = "selected",
	Taken = "taken",
})

NexoConfig.BlockReason = "Nexo"

function NexoConfig.GetDefaultLore(displayName: string): string
	return `{displayName} mantiene una posicion clave para controlar el frente y sostener la linea de avance.`
end

return table.freeze(NexoConfig)
