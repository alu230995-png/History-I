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

export type PlacementMode = "Center" | "Edge"

function HexUtils.createAxial(q: number, r: number): AxialCoord
	return {
		q = q,
		r = r,
	}
end

function HexUtils.toKey(q: number, r: number): string
	return `{q},{r}`
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

function HexUtils.getSocketPositions(q: number, r: number, hexY: number, gridConfig: GridConfigLike): SocketPositions
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

function HexUtils.getSocketPositionsFromPart(hexPart: BasePart): SocketPositions
	local center = hexPart.CFrame:PointToWorldSpace(Vector3.new(0, hexPart.Size.Y * 0.5, 0))
	local edgePositions = table.create(6)
	local edgeCenterRadius = hexPart.Size.X * 0.5

	for index = 1, 6 do
		local angle = math.rad((index - 1) * 60)
		local localOffset =
			Vector3.new(edgeCenterRadius * math.cos(angle), hexPart.Size.Y * 0.5, edgeCenterRadius * math.sin(angle))
		edgePositions[index] = hexPart.CFrame:PointToWorldSpace(localOffset)
	end

	return {
		Center = center,
		Edge = edgePositions,
	}
end

function HexUtils.getEdgeIndex(socketName: any): number?
	if typeof(socketName) ~= "string" then
		return nil
	end

	return tonumber(string.match(socketName, "^Edge([1-6])$"))
end

function HexUtils.getEdgeSocketName(edgeIndex: number): string
	return `Edge{((edgeIndex - 1) % 6) + 1}`
end

function HexUtils.getNextEdgeSocketName(socketName: string, direction: number): string
	local edgeIndex = HexUtils.getEdgeIndex(socketName) or 1
	local step = if direction < 0 then -1 else 1

	return HexUtils.getEdgeSocketName(edgeIndex + step)
end

function HexUtils.getSocketPosition(
	q: number,
	r: number,
	hexY: number,
	socketName: string,
	gridConfig: GridConfigLike
): Vector3
	local socketPositions = HexUtils.getSocketPositions(q, r, hexY, gridConfig)

	if socketName == "Center" then
		return socketPositions.Center
	end

	local edgeIndex = HexUtils.getEdgeIndex(socketName)
	if edgeIndex == nil then
		return socketPositions.Center
	end

	return socketPositions.Edge[edgeIndex]
end

function HexUtils.getSocketPositionFromPart(hexPart: BasePart, socketName: string): Vector3
	local socketPositions = HexUtils.getSocketPositionsFromPart(hexPart)

	if socketName == "Center" then
		return socketPositions.Center
	end

	local edgeIndex = HexUtils.getEdgeIndex(socketName)
	if edgeIndex == nil then
		return socketPositions.Center
	end

	return socketPositions.Edge[edgeIndex]
end

function HexUtils.getEdgeYawDegrees(socketName: string): number
	local edgeIndex = HexUtils.getEdgeIndex(socketName) or 1
	local outwardAngle = (edgeIndex - 1) * 60

	return (outwardAngle + 90) % 360
end

function HexUtils.getEdgeYawDegreesFromPart(hexPart: BasePart, socketName: string): number
	local edgeIndex = HexUtils.getEdgeIndex(socketName) or 1
	local angle = math.rad((edgeIndex - 1) * 60)
	local normal = hexPart.CFrame:VectorToWorldSpace(Vector3.new(math.cos(angle), 0, math.sin(angle)))
	local outwardAngle = math.deg(math.atan2(normal.Z, normal.X))

	return (outwardAngle + 90) % 360
end

function HexUtils.getNearestEdgeSocket(
	hitPosition: Vector3,
	q: number,
	r: number,
	hexY: number,
	gridConfig: GridConfigLike
): string
	local socketPositions = HexUtils.getSocketPositions(q, r, hexY, gridConfig)
	local nearestSocket = "Edge1"
	local nearestDistance = (hitPosition - socketPositions.Edge[1]).Magnitude

	for index = 2, 6 do
		local distance = (hitPosition - socketPositions.Edge[index]).Magnitude
		if distance < nearestDistance then
			nearestSocket = `Edge{index}`
			nearestDistance = distance
		end
	end

	return nearestSocket
end

function HexUtils.getNearestSocketForPlacementMode(
	hitPosition: Vector3,
	q: number,
	r: number,
	hexY: number,
	gridConfig: GridConfigLike,
	placementMode: PlacementMode
): string
	if placementMode == "Edge" then
		return HexUtils.getNearestEdgeSocket(hitPosition, q, r, hexY, gridConfig)
	end

	return "Center"
end

function HexUtils.getNearestSocketForPlacementModeFromPart(
	hitPosition: Vector3,
	hexPart: BasePart,
	placementMode: PlacementMode
): string
	if placementMode ~= "Edge" then
		return "Center"
	end

	local socketPositions = HexUtils.getSocketPositionsFromPart(hexPart)
	local nearestSocket = "Edge1"
	local nearestDistance = (hitPosition - socketPositions.Edge[1]).Magnitude

	for index = 2, 6 do
		local distance = (hitPosition - socketPositions.Edge[index]).Magnitude
		if distance < nearestDistance then
			nearestSocket = `Edge{index}`
			nearestDistance = distance
		end
	end

	return nearestSocket
end

function HexUtils.getNearestSocket(
	hitPosition: Vector3,
	q: number,
	r: number,
	hexY: number,
	gridConfig: GridConfigLike
): string
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
