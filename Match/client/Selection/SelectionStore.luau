local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelectionConfig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("SelectionConfig"))

local SelectionStore = {}
SelectionStore.__index = SelectionStore

function SelectionStore.new(localUserId: number)
	local self = setmetatable({}, SelectionStore)
	self._localUserId = localUserId
	self._selectedUnits = {}
	self._unitOrder = {}
	self._selectedBuilding = nil
	return self
end

function SelectionStore:GetSelectedUnits()
	return self._selectedUnits
end

function SelectionStore:GetUnitOrder()
	return self._unitOrder
end

function SelectionStore:GetSelectedUnitCount(): number
	return #self._unitOrder
end

function SelectionStore:GetSelectedBuilding(): Model?
	return self._selectedBuilding
end

function SelectionStore:SelectBuilding(building: Model?)
	self._selectedBuilding = building
end

function SelectionStore:ClearBuilding()
	self._selectedBuilding = nil
end

function SelectionStore:CanSelectUnit(model: Model?): boolean
	return model ~= nil
		and model:GetAttribute("OwnerUserId") == self._localUserId
		and typeof(model:GetAttribute("UnitId")) == "string"
end

function SelectionStore:IsUnitSelected(unitId: string): boolean
	return self._selectedUnits[unitId] ~= nil
end

function SelectionStore:SelectUnit(model: Model, replace: boolean?)
	if not self:CanSelectUnit(model) then
		return false
	end

	if replace then
		self:ClearUnits()
	end

	local unitId = model:GetAttribute("UnitId")
	if self._selectedUnits[unitId] ~= nil then
		return false
	end

	if #self._unitOrder >= SelectionConfig.MaxSelectedUnits then
		return false
	end

	self._selectedUnits[unitId] = model
	table.insert(self._unitOrder, unitId)
	return true
end

function SelectionStore:ToggleUnit(model: Model)
	if not self:CanSelectUnit(model) then
		return false
	end

	local unitId = model:GetAttribute("UnitId")
	if self._selectedUnits[unitId] ~= nil then
		self:DeselectUnit(unitId)
		return true
	end

	return self:SelectUnit(model, false)
end

function SelectionStore:SelectUnits(models: { Model }, replace: boolean?)
	if replace then
		self:ClearUnits()
	end

	local changed = false
	for index = 1, #models do
		if self:SelectUnit(models[index], false) then
			changed = true
		end
	end
	return changed
end

function SelectionStore:DeselectUnit(unitId: string)
	if self._selectedUnits[unitId] == nil then
		return false
	end

	self._selectedUnits[unitId] = nil
	for index = #self._unitOrder, 1, -1 do
		if self._unitOrder[index] == unitId then
			table.remove(self._unitOrder, index)
			break
		end
	end
	return true
end

function SelectionStore:RemoveMissingUnits()
	local changed = false
	for index = #self._unitOrder, 1, -1 do
		local unitId = self._unitOrder[index]
		local model = self._selectedUnits[unitId]
		if model == nil or model.Parent == nil then
			self._selectedUnits[unitId] = nil
			table.remove(self._unitOrder, index)
			changed = true
		end
	end
	return changed
end

function SelectionStore:ClearUnits()
	if #self._unitOrder <= 0 then
		return false
	end

	table.clear(self._selectedUnits)
	table.clear(self._unitOrder)
	return true
end

function SelectionStore:ClearAll()
	local hadUnits = self:ClearUnits()
	local hadBuilding = self._selectedBuilding ~= nil
	self._selectedBuilding = nil
	return hadUnits or hadBuilding
end

function SelectionStore:Destroy()
	self:ClearAll()
end

return SelectionStore
