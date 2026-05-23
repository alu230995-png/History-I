local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildingConfig = require(Shared:WaitForChild("Constants"):WaitForChild("BuildingConfig"))
local GridConfig = require(Shared:WaitForChild("Constants"):WaitForChild("GridConfig"))
local SelectionConfig = require(Shared:WaitForChild("Constants"):WaitForChild("SelectionConfig"))

local EntityTypes = SelectionConfig.EntityTypes
local NexoConfig = BuildingConfig.Nexo

local EntityPicker = {}
EntityPicker.__index = EntityPicker

local function instanceContains(root: Instance?, child: Instance?): boolean
	if root == nil or child == nil then
		return false
	end

	return child == root or child:IsDescendantOf(root)
end

local function findBuildingModel(instance: Instance?, placedFolder: Folder?): Model?
	local current = instance
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("BuildingId") ~= nil then
			if placedFolder == nil or current:IsDescendantOf(placedFolder) then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

local function findUnitModel(instance: Instance?, unitFolder: Folder?): Model?
	local current = instance
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("UnitId") ~= nil then
			if unitFolder == nil or current:IsDescendantOf(unitFolder) then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

local function findHexPart(instance: Instance?): BasePart?
	local current = instance
	while current ~= nil and current ~= Workspace do
		if current:IsA("BasePart") and CollectionService:HasTag(current, GridConfig.BuildableHexTag) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function getModelRoot(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

function EntityPicker.new()
	local self = setmetatable({}, EntityPicker)
	self._camera = Workspace.CurrentCamera
	self._placedFolder = nil
	self._unitFolder = nil
	self._snapshot = { nexos = {} }
	self._nexoRaycastInclude = {}

	self._unitRaycastParams = RaycastParams.new()
	self._unitRaycastParams.FilterType = Enum.RaycastFilterType.Include
	self._unitRaycastParams.FilterDescendantsInstances = {}

	self._buildingRaycastParams = RaycastParams.new()
	self._buildingRaycastParams.FilterType = Enum.RaycastFilterType.Include
	self._buildingRaycastParams.FilterDescendantsInstances = {}

	self._nexoRaycastParams = RaycastParams.new()
	self._nexoRaycastParams.FilterType = Enum.RaycastFilterType.Include
	self._nexoRaycastParams.FilterDescendantsInstances = self._nexoRaycastInclude

	return self
end

function EntityPicker:SetCamera(camera: Camera?)
	self._camera = camera
end

function EntityPicker:SetPlacedFolder(folder: Folder?)
	self._placedFolder = folder
	self._buildingRaycastParams.FilterDescendantsInstances = if folder ~= nil then { folder } else {}
end

function EntityPicker:SetUnitFolder(folder: Folder?)
	self._unitFolder = folder
	self._unitRaycastParams.FilterDescendantsInstances = if folder ~= nil then { folder } else {}
end

function EntityPicker:SetNexoSnapshot(snapshot)
	self._snapshot = snapshot or { nexos = {} }
	table.clear(self._nexoRaycastInclude)

	if self._snapshot.nexos ~= nil then
		for _, record in self._snapshot.nexos do
			if record.instance ~= nil then
				table.insert(self._nexoRaycastInclude, record.instance)
			end
		end
	end

	self._nexoRaycastParams.FilterDescendantsInstances = self._nexoRaycastInclude
end

function EntityPicker:_getProjectedNexoAtPointer(pointerPosition: Vector2)
	local camera = self._camera
	local snapshot = self._snapshot
	if camera == nil or snapshot.nexos == nil then
		return nil
	end

	local pickRadius = if snapshot.phaseActive == true
		then NexoConfig.InitialSelectionPickRadiusPixels
			or NexoConfig.ProjectedPickRadiusPixels
			or SelectionConfig.ProjectedNexoPickRadiusPixels
		else NexoConfig.ProjectedPickRadiusPixels or SelectionConfig.ProjectedNexoPickRadiusPixels
	local closestRecord = nil
	local closestDistanceSquared = pickRadius * pickRadius

	for _, record in snapshot.nexos do
		local rootPart = record.rootPart
		if rootPart == nil or rootPart.Parent == nil then
			continue
		end

		local viewportPoint, onScreen = camera:WorldToViewportPoint(rootPart.Position)
		if not onScreen then
			continue
		end

		local offsetX = viewportPoint.X - pointerPosition.X
		local offsetY = viewportPoint.Y - pointerPosition.Y
		local distanceSquared = offsetX * offsetX + offsetY * offsetY
		if distanceSquared < closestDistanceSquared then
			closestRecord = record
			closestDistanceSquared = distanceSquared
		end
	end

	return closestRecord
end

function EntityPicker:Pick(pointerPosition: Vector2)
	local camera = self._camera
	if camera == nil then
		return nil
	end

	local maxDistance = NexoConfig.SelectionRayDistance or SelectionConfig.SelectionRayDistance
	local ray = camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
	local direction = ray.Direction * maxDistance

	if self._unitFolder ~= nil then
		local result = Workspace:Raycast(ray.Origin, direction, self._unitRaycastParams)
		if result ~= nil then
			local unitModel = findUnitModel(result.Instance, self._unitFolder)
			if unitModel ~= nil then
				return { Type = EntityTypes.Unit, Instance = unitModel }
			end
		end
	end

	if self._placedFolder ~= nil then
		local result = Workspace:Raycast(ray.Origin, direction, self._buildingRaycastParams)
		if result ~= nil then
			local buildingModel = findBuildingModel(result.Instance, self._placedFolder)
			if buildingModel ~= nil then
				return { Type = EntityTypes.Building, Instance = buildingModel }
			end
		end
	end

	if self._snapshot.nexos ~= nil and #self._nexoRaycastInclude > 0 then
		local result = Workspace:Raycast(ray.Origin, direction, self._nexoRaycastParams)
		if result ~= nil then
			for _, record in self._snapshot.nexos do
				if instanceContains(record.instance, result.Instance) then
					return { Type = EntityTypes.Nexo, Id = record.id, Record = record }
				end
			end
		end
	end

	local projectedNexo = self:_getProjectedNexoAtPointer(pointerPosition)
	if projectedNexo ~= nil then
		return { Type = EntityTypes.Nexo, Id = projectedNexo.id, Record = projectedNexo }
	end

	local result = Workspace:Raycast(ray.Origin, direction)
	if result ~= nil then
		local hexPart = findHexPart(result.Instance)
		if hexPart ~= nil then
			return { Type = EntityTypes.Hex, Part = hexPart }
		end
	end

	return nil
end

function EntityPicker:GetOwnUnitsInRect(rect, ownerUserId: number, limit: number?): { Model }
	local camera = self._camera
	local unitFolder = self._unitFolder
	if camera == nil or unitFolder == nil or rect == nil then
		return {}
	end

	local maxUnits = limit or SelectionConfig.MaxSelectedUnits
	local units = {}

	for _, child in unitFolder:GetChildren() do
		if #units >= maxUnits then
			break
		end
		if not child:IsA("Model") or child:GetAttribute("OwnerUserId") ~= ownerUserId then
			continue
		end

		local root = getModelRoot(child)
		if root == nil then
			continue
		end

		local viewportPoint, onScreen = camera:WorldToViewportPoint(root.Position)
		if
			onScreen
			and viewportPoint.X >= rect.Min.X
			and viewportPoint.X <= rect.Max.X
			and viewportPoint.Y >= rect.Min.Y
			and viewportPoint.Y <= rect.Max.Y
		then
			table.insert(units, child)
		end
	end

	return units
end

function EntityPicker:Destroy()
	table.clear(self._nexoRaycastInclude)
end

return EntityPicker
