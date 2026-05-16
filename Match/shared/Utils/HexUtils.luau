local HexUtils = {}

local SQRT_3 = math.sqrt(3)

local DIRECTIONS = table.freeze({
	{ q = 1, r = 0 },
	{ q = 1, r = -1 },
	{ q = 0, r = -1 },
	{ q = -1, r = 0 },
	{ q = -1, r = 1 },
	{ q = 0, r = 1 },
})

export type AxialCoord = {
	q: number,
	r: number,
}

export type GridConfigLike = {
	HexWidth: number,
	HexHeight: number,
	GridOrigin: Vector3?,
}

export type CubeCoord = {
	x: number,
	y: number,
	z: number,
}

export type SocketPositions = {
	Center: Vector3,
	Edge: { Vector3 },
}

function HexUtils.createAxial(q: number, r: number): AxialCoord
	return {
		q = q,
		r = r,
	}
end

function HexUtils.toKey(q: number, r: number): string
	return (`{q},{r}`)
end

function HexUtils.fromKey(key: string): AxialCoord?
	local qText, rText = string.match(key, "^(-?%d+),(-?%d+)$")
	if qText == nil or rText == nil then
		return nil
	end

	return HexUtils.createAxial(tonumber(qText) :: number, tonumber(rText) :: number)
end

function HexUtils.axialToCube(q: number, r: number): CubeCoord
	local x = q
	local z = r
	local y = -x - z

	return {
		x = x,
		y = y,
		z = z,
	}
end

function HexUtils.cubeToAxial(x: number, _y: number, z: number): AxialCoord
	return HexUtils.createAxial(x, z)
end

function HexUtils.getNeighbor(q: number, r: number, directionIndex: number): AxialCoord
	local direction = DIRECTIONS[((directionIndex - 1) % #DIRECTIONS) + 1]

	return HexUtils.createAxial(q + direction.q, r + direction.r)
end

function HexUtils.getNeighbors(q: number, r: number): { AxialCoord }
	local neighbors = table.create(#DIRECTIONS)

	for index = 1, #DIRECTIONS do
		neighbors[index] = HexUtils.getNeighbor(q, r, index)
	end

	return neighbors
end

function HexUtils.distance(aQ: number, aR: number, bQ: number, bR: number): number
	local a = HexUtils.axialToCube(aQ, aR)
	local b = HexUtils.axialToCube(bQ, bR)

	return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y), math.abs(a.z - b.z))
end

function HexUtils.roundAxial(q: number, r: number): AxialCoord
	local cube = HexUtils.axialToCube(q, r)

	local rx = math.round(cube.x)
	local ry = math.round(cube.y)
	local rz = math.round(cube.z)

	local xDiff = math.abs(rx - cube.x)
	local yDiff = math.abs(ry - cube.y)
	local zDiff = math.abs(rz - cube.z)

	if xDiff > yDiff and xDiff > zDiff then
		rx = -ry - rz
	elseif yDiff > zDiff then
		ry = -rx - rz
	else
		rz = -rx - ry
	end

	return HexUtils.cubeToAxial(rx, ry, rz)
end

function HexUtils.worldToAxial(position: Vector3, hexWidth: number, hexHeight: number, origin: Vector3?): AxialCoord
	local gridOrigin = origin or Vector3.zero
	local localPosition = position - gridOrigin
	local r = localPosition.Z / (hexHeight * 0.75)
	local q = (localPosition.X / hexWidth) - (r / 2)

	return HexUtils.roundAxial(q, r)
end

function HexUtils.axialToWorld(
	q: number,
	r: number,
	hexWidth: number,
	hexHeight: number,
	y: number?,
	origin: Vector3?
): Vector3
	local gridOrigin = origin or Vector3.zero
	local x = hexWidth * (q + (r / 2))
	local z = hexHeight * 0.75 * r

	return Vector3.new(gridOrigin.X + x, y or gridOrigin.Y, gridOrigin.Z + z)
end

function HexUtils.getHexCoordFromPart(hexPart: BasePart, gridConfig: GridConfigLike): AxialCoord
	return HexUtils.worldToAxial(hexPart.Position, gridConfig.HexWidth, gridConfig.HexHeight, gridConfig.GridOrigin)
end

function HexUtils.getHexSurfaceY(hexPart: BasePart): number
	return hexPart.Position.Y + (hexPart.Size.Y * 0.5)
end

function HexUtils.getSocketPositions(
	q: number,
	r: number,
	hexY: number,
	gridConfig: GridConfigLike
): SocketPositions
	local center = HexUtils.axialToWorld(q, r, gridConfig.HexWidth, gridConfig.HexHeight, hexY, gridConfig.GridOrigin)
	local edgePositions = table.create(6)
	local innerRadius = gridConfig.HexWidth * 0.5

	for index = 1, 6 do
		local angle = math.rad((index - 1) * 60)
		edgePositions[index] = center + Vector3.new(innerRadius * math.cos(angle), 0, innerRadius * math.sin(angle))
	end

	return {
		Center = center,
		Edge = edgePositions,
	}
end

function HexUtils.getNearestSocket(hitPosition: Vector3, q: number, r: number, hexY: number, gridConfig: GridConfigLike): string
	local socketPositions = HexUtils.getSocketPositions(q, r, hexY, gridConfig)
	local nearestSocket = "Center"
	local nearestDistance = (hitPosition - socketPositions.Center).Magnitude

	for index = 1, 6 do
		local distance = (hitPosition - socketPositions.Edge[index]).Magnitude
		if distance < nearestDistance then
			nearestSocket = `Edge{index}`
			nearestDistance = distance
		end
	end

	return nearestSocket
end

function HexUtils.hexSizeFromWidth(hexWidth: number): number
	return hexWidth / SQRT_3
end

return table.freeze(HexUtils)
