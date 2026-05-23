local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SelectionConfig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("SelectionConfig"))

local visuals = SelectionConfig.Visuals

local SelectionVisuals = {}
SelectionVisuals.__index = SelectionVisuals

local function configureHighlight(
	highlight: Highlight,
	color: Color3,
	fillTransparency: number,
	outlineTransparency: number
)
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = fillTransparency
	highlight.OutlineTransparency = outlineTransparency
end

local function createHighlight(name: string, trove): Highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = name
	highlight.Enabled = false
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = Workspace
	trove:Add(highlight)
	return highlight
end

function SelectionVisuals.new(trove)
	local self = setmetatable({}, SelectionVisuals)
	self._trove = trove
	self._hoverHighlight = createHighlight("SelectionHoverHighlight", trove)
	self._buildingSelectedHighlight = createHighlight("SelectedBuildingHighlight", trove)
	self._assignedNexoHighlight = createHighlight("AssignedNexoHighlight", trove)
	self._unitHighlights = {}

	configureHighlight(
		self._hoverHighlight,
		visuals.UnitColor,
		visuals.HoverFillTransparency,
		visuals.HoverOutlineTransparency
	)
	configureHighlight(
		self._buildingSelectedHighlight,
		visuals.BuildingColor,
		visuals.SelectedFillTransparency,
		visuals.SelectedOutlineTransparency
	)
	configureHighlight(
		self._assignedNexoHighlight,
		visuals.NexoColor,
		visuals.HoverFillTransparency,
		visuals.SelectedOutlineTransparency
	)

	return self
end

function SelectionVisuals:SetHover(entity, localUserId: number)
	if entity == nil then
		self._hoverHighlight.Adornee = nil
		self._hoverHighlight.Enabled = false
		return
	end

	local adornee = nil
	local color = visuals.UnitColor
	local fillTransparency = visuals.HoverFillTransparency
	local outlineTransparency = visuals.HoverOutlineTransparency

	if entity.Type == SelectionConfig.EntityTypes.Unit then
		adornee = entity.Instance
		if entity.Instance:GetAttribute("OwnerUserId") ~= localUserId then
			color = visuals.EnemyColor
			fillTransparency = visuals.InvalidFillTransparency
			outlineTransparency = visuals.InvalidOutlineTransparency
		end
	elseif entity.Type == SelectionConfig.EntityTypes.Building then
		adornee = entity.Instance
		color = if entity.Instance:GetAttribute("OwnerUserId") == localUserId
			then visuals.BuildingColor
			else visuals.EnemyColor
	elseif entity.Type == SelectionConfig.EntityTypes.Nexo then
		adornee = entity.Record and entity.Record.instance
		color = visuals.NexoColor
	end

	self._hoverHighlight.Adornee = adornee
	self._hoverHighlight.Enabled = adornee ~= nil
	configureHighlight(self._hoverHighlight, color, fillTransparency, outlineTransparency)
end

function SelectionVisuals:SetSelectedBuilding(building: Model?)
	self._buildingSelectedHighlight.Adornee = building
	self._buildingSelectedHighlight.Enabled = building ~= nil
end

function SelectionVisuals:SetAssignedNexo(record, color: Color3?, emphasized: boolean?)
	if
		record == nil
		or record.instance == nil
		or record.active ~= true
		or (typeof(record.hp) == "number" and record.hp <= 0)
	then
		self._assignedNexoHighlight.Adornee = nil
		self._assignedNexoHighlight.Enabled = false
		return
	end

	local nextColor = color or visuals.NexoColor
	local fillTransparency = if emphasized then visuals.SelectedFillTransparency else visuals.HoverFillTransparency
	self._assignedNexoHighlight.Adornee = record.instance
	self._assignedNexoHighlight.Enabled = true
	configureHighlight(self._assignedNexoHighlight, nextColor, fillTransparency, visuals.SelectedOutlineTransparency)
end

function SelectionVisuals:SyncUnitSelection(selectedUnits)
	local seen = {}

	for unitId, model in selectedUnits do
		seen[unitId] = true
		local highlight = self._unitHighlights[unitId]
		if highlight == nil then
			highlight = Instance.new("Highlight")
			highlight.Name = `SelectedUnit_{unitId}`
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = Workspace
			self._unitHighlights[unitId] = highlight
			self._trove:Add(highlight)
		end

		highlight.Adornee = model
		highlight.Enabled = model ~= nil and model.Parent ~= nil
		configureHighlight(
			highlight,
			visuals.UnitColor,
			visuals.SelectedFillTransparency,
			visuals.SelectedOutlineTransparency
		)
	end

	for unitId, highlight in self._unitHighlights do
		if seen[unitId] ~= true then
			highlight:Destroy()
			self._unitHighlights[unitId] = nil
		end
	end
end

function SelectionVisuals:ClearUnits()
	for unitId, highlight in self._unitHighlights do
		highlight:Destroy()
		self._unitHighlights[unitId] = nil
	end
end

function SelectionVisuals:Destroy()
	self:ClearUnits()
end

return SelectionVisuals
