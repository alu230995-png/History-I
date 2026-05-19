local data = {}

local function findNexo(snapshot, nexoId: string?)
	if snapshot == nil or snapshot.nexos == nil or nexoId == nil then
		return nil
	end

	for _, nexo in snapshot.nexos do
		if nexo.id == nexoId then
			return nexo
		end
	end

	return nil
end

function data.getNexoData(nexoId: string?, snapshot, localUserId: number?)
	local nexo = findNexo(snapshot, nexoId)
	if nexo == nil then
		return {
			id = nexoId,
			nombre = "NEXO",
			lore = "Datos de Nexo no disponibles.",
			estado = "missing",
			statusText = "NEXO NO DISPONIBLE",
			canSelect = false,
		}
	end

	local selectedByOther = nexo.state == "selected"
		and nexo.selectedByUserId ~= nil
		and nexo.selectedByUserId ~= localUserId
	local taken = nexo.state == "taken"
	local statusText = "DISPONIBLE"
	if taken then
		statusText = "ESTE NEXO YA FUE RECLAMADO"
	elseif selectedByOther then
		statusText = "OTRO JUGADOR ESTA REVISANDO ESTE NEXO"
	elseif nexo.state == "selected" then
		statusText = "LISTO PARA CONFIRMAR"
	end

	return {
		id = nexo.id,
		nombre = nexo.displayName or "NEXO",
		lore = nexo.lore or "",
		estado = nexo.state,
		statusText = statusText,
		canSelect = not taken and not selectedByOther,
	}
end

return data
