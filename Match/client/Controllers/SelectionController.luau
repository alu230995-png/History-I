local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))
local Trove = require(Packages:WaitForChild("Trove"))

local BuildingConfig = require(Shared:WaitForChild("Constants"):WaitForChild("BuildingConfig"))
local NexoConfig = BuildingConfig.Nexo
local GridConfig = require(Shared:WaitForChild("Constants"):WaitForChild("GridConfig"))
local DiplomacyConfig = require(Shared:WaitForChild("Constants"):WaitForChild("DiplomacyConfig"))
local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local PlayerStates = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStates"))
local StateMachine = require(Shared:WaitForChild("Classes"):WaitForChild("StateMachine"))

local BuildingMenu = require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("BuildingMenu"):WaitForChild("index"))
local NexoBuildMenu = require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("NexoBuildMenu"):WaitForChild("index"))
local NexoSelectionMenu = require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("NexoSelectionMenu"):WaitForChild("index"))
local NexoTimerUI = require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("NexoTimerUI"):WaitForChild("index"))
local UnitSelectionBar = require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("UnitSelectionBar"):WaitForChild("index"))

local UITheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local WorldInput = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("WorldInput"))

local SelectionController = Knit.CreateController({
	Name = "SelectionController",
})

local LOCAL_PLAYER = Players.LocalPlayer
local MAX_RAY_DISTANCE = NexoConfig.SelectionRayDistance
local PROJECTED_NEXO_PICK_RADIUS = NexoConfig.ProjectedPickRadiusPixels
local SELECTED_BILLBOARD_SIZE = UDim2.fromOffset(46, 22)
local px = UITheme.sp
local colors = UITheme.Colors

local function canInteractWithBuildings(playerState: string?): boolean
	return playerState == PlayerStates.Playing
end

local function canInteractWithNexo(playerState: string?): boolean
	return playerState ~= PlayerStates.Defeated and playerState ~= PlayerStates.Spectating
end

local InteractionStates = table.freeze({
	Idle = "Idle",
	HoveringBuilding = "HoveringBuilding",
	SelectedBuilding = "SelectedBuilding",
	BuildingMenuOpen = "BuildingMenuOpen",
	HoveringNexo = "HoveringNexo",
	NexoMenuOpen = "NexoMenuOpen",
	BuildPlacement = "BuildPlacement",
})

local AllowedTransitions = table.freeze({
	Idle = table.freeze({
		HoveringBuilding = true,
		SelectedBuilding = true,
		BuildingMenuOpen = true,
		HoveringNexo = true,
		NexoMenuOpen = true,
		BuildPlacement = true,
	}),
	HoveringBuilding = table.freeze({
		Idle = true,
		SelectedBuilding = true,
		BuildingMenuOpen = true,
	}),
	SelectedBuilding = table.freeze({
		Idle = true,
		HoveringBuilding = true,
		BuildingMenuOpen = true,
	}),
	BuildingMenuOpen = table.freeze({
		Idle = true,
		HoveringBuilding = true,
		SelectedBuilding = true,
	}),
	HoveringNexo = table.freeze({
		Idle = true,
		NexoMenuOpen = true,
		BuildPlacement = true,
	}),
	NexoMenuOpen = table.freeze({
		Idle = true,
		BuildPlacement = true,
	}),
	BuildPlacement = table.freeze({
		Idle = true,
		HoveringNexo = true,
		NexoMenuOpen = true,
	}),
})

local ASSIGNED_HIGHLIGHT_COLORS = table.freeze({
	Color3.fromRGB(63, 176, 92),
	Color3.fromRGB(205, 159, 68),
	Color3.fromRGB(86, 151, 215),
	Color3.fromRGB(205, 86, 126),
	Color3.fromRGB(118, 198, 180),
	Color3.fromRGB(214, 104, 65),
})

local function getRecordById(snapshot, nexoId: string?)
	if snapshot == nil or snapshot.nexos == nil or nexoId == nil then return nil end
	for _, record in snapshot.nexos do
		if record.id == nexoId then return record end
	end
	return nil
end

local function instanceContains(root: Instance?, child: Instance?): boolean
	if root == nil or child == nil then return false end
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

local function getStableColorForNexo(nexoId: string?): Color3
	local text = nexoId or ""
	local hash = 0
	for index = 1, #text do
		hash = (hash * 31 + string.byte(text, index)) % 100000
	end
	return ASSIGNED_HIGHLIGHT_COLORS[(hash % #ASSIGNED_HIGHLIGHT_COLORS) + 1]
end

function SelectionController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._camera = Workspace.CurrentCamera
	
	self._placedFolder = nil
	self._nexoService = nil
	self._buildService = nil
	self._buildController = nil
	self._menuCoordinator = nil
	self._gameService = nil
	self._manpowerService = nil
	
	self._playerState = nil
	self._root = nil
	self._screenGui = nil
	self._lastTouchPosition = nil
	self._isBuildingMode = false
	
	self._machine = StateMachine.new(InteractionStates.Idle, AllowedTransitions)
	self._trove:Add(self._machine)
	
	-- Building State
	self._hoveredBuilding = nil
	self._selectedBuilding = nil
	self._barracksQueues = {}
	self._queueReceivedAt = {}
	self._queueBillboards = {}
	
	-- Nexo State
	self._snapshot = { phaseActive = false, remainingSeconds = NexoConfig.SelectionDurationSeconds, nexos = {} }
	self._resources = nil
	self._remainingSeconds = NexoConfig.SelectionDurationSeconds
	self._selectedNexoId = nil
	self._assignedNexoId = nil
	self._hoveredNexoId = nil
	self._assignmentMessage = nil
	self._assignmentToken = 0
	self._selectedBillboards = {}
	self._selectionEnded = false
	self._nexoRaycastParams = RaycastParams.new()
	self._nexoRaycastParams.FilterType = Enum.RaycastFilterType.Include
	self._nexoRaycastInclude = {}

	-- Highlights
	self._buildingHighlight = Instance.new("Highlight")
	self._buildingHighlight.Name = "LocalBuildingHighlight"
	self._buildingHighlight.Enabled = false
	self._buildingHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self._buildingHighlight.FillColor = Color3.fromRGB(255, 255, 255)
	self._buildingHighlight.FillTransparency = 0.8
	self._buildingHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	self._buildingHighlight.OutlineTransparency = 0.05
	self._buildingHighlight.Parent = Workspace
	self._trove:Add(self._buildingHighlight)

	self._nexoHighlight = Instance.new("Highlight")
	self._nexoHighlight.Name = "LocalNexoHoverHighlight"
	self._nexoHighlight.Enabled = false
	self._nexoHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self._nexoHighlight.FillColor = Color3.fromRGB(255, 255, 255)
	self._nexoHighlight.FillTransparency = 0.82
	self._nexoHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	self._nexoHighlight.OutlineTransparency = 0.08
	self._nexoHighlight.Parent = Workspace
	self._trove:Add(self._nexoHighlight)

	self._assignedNexoHighlight = Instance.new("Highlight")
	self._assignedNexoHighlight.Name = "AssignedNexoOutline"
	self._assignedNexoHighlight.Enabled = false
	self._assignedNexoHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self._assignedNexoHighlight.FillTransparency = NexoConfig.AssignedHighlight.FillTransparency
	self._assignedNexoHighlight.OutlineTransparency = NexoConfig.AssignedHighlight.OutlineTransparency
	self._assignedNexoHighlight.Parent = Workspace
	self._trove:Add(self._assignedNexoHighlight)

	-- Troop State
	self._unitFolder = nil
	self._selectedUnits = {}
	self._selectionOrder = {}
	self._unitHighlights = {}

	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
	end))
end

function SelectionController:KnitStart()
	self._nexoService = Knit.GetService("NexoService")
	self._buildService = Knit.GetService("BuildService")
	self._gameService = Knit.GetService("GameService")
	self._manpowerService = Knit.GetService("ManpowerService")
	self._buildController = Knit.GetController("BuildController")
	self._menuCoordinator = Knit.GetController("MenuCoordinatorController")
	self._placedFolder = Workspace:WaitForChild(BuildingConfig.PlacedFolderName, 10)
	self._unitFolder = Workspace:WaitForChild(ManpowerConfig.UnitFolderName, 10)

	if self._unitFolder ~= nil then
		self._trove:Add(self._unitFolder.ChildRemoved:Connect(function(child)
			local unitId = child:GetAttribute("UnitId")
			if typeof(unitId) == "string" then
				self:_deselectUnit(unitId)
			end
		end))
	end
	
	self:_mountUi()
	self:_refreshResources()

	-- Nexo Events
	local snapshot = self._nexoService:GetSnapshot()
	if snapshot ~= nil then self:_setSnapshot(snapshot) end

	self._trove:Add(self._nexoService.NexoSnapshotChanged:Connect(function(nextSnapshot)
		self:_setSnapshot(nextSnapshot)
	end))

	self._trove:Add(self._nexoService.NexoTimerChanged:Connect(function(seconds: number)
		self._remainingSeconds = seconds
		self:_renderUi()
	end))

	self._trove:Add(self._nexoService.NexoAssigned:Connect(function(payload)
		self:_showAssignment(payload)
	end))

	self._trove:Add(self._nexoService.NexoSelectionEnded:Connect(function(snapshotEnded)
		if snapshotEnded ~= nil then self:_setSnapshot(snapshotEnded) end
		self._selectionEnded = true
		self:_closeNexoSelectionMenu(false)
		self:_clearNexoHover()
		self:_renderUi()
	end))

	self._trove:Add(self._buildService.ResourcesChanged:Connect(function(resources)
		self._resources = resources
		if self:_isNexoBuildMenuOpen() then self:_renderUi() end
	end))

	-- Building Events
	self._trove:Add(self._manpowerService.QueueChanged:Connect(function(queue)
		self:_setQueueSnapshot(queue)
	end))
	self._trove:Add(self._buildService.BuildingDestroyed:Connect(function(payload)
		self:_handleBuildingDestroyed(payload)
	end))

	-- State Events
	self._trove:Add(self._gameService.PlayerStateChanged:Connect(function(_oldState: string, newState: string)
		self:_setPlayerState(newState)
	end))
	local state = self._gameService:GetPlayerState()
	self:_setPlayerState(state)

	-- Input & Render
	self._trove:Add(RunService.RenderStepped:Connect(function()
		self:_updateHover()
		self:_updateQueueBillboards()
	end))

	self._trove:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		self:_handleInputBegan(input, gameProcessedEvent)
	end))

	self._trove:Add(UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			self._lastTouchPosition = Vector2.new(input.Position.X, input.Position.Y)
		end
	end))

	self._trove:Add(UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			self._lastTouchPosition = nil
		end
	end))
end

function SelectionController:_mountUi()
	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SelectionMenuGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 60
	screenGui.Parent = playerGui
	self._screenGui = screenGui

	local root = ReactRoblox.createRoot(screenGui)
	self._root = root
	self._trove:Add(function() root:unmount() end)
	self._trove:Add(screenGui)

	self:_renderUi()
end

function SelectionController:_setPlayerState(state: string?)
	self._playerState = state
	self:_setBuildingMode(state == PlayerStates.Building)

	if not canInteractWithNexo(state) then
		self._lastTouchPosition = nil
		self:_closeNexoSelectionMenu(false)
		self:_closeNexoBuildMenu()
		self:_clearNexoHover()
		if self._machine:GetState() ~= InteractionStates.Idle then
			self._machine:TransitionTo(InteractionStates.Idle)
		end
	end
	
	if not canInteractWithBuildings(state) then
		self._hoveredBuilding = nil
		self._lastTouchPosition = nil
		self:_clearBuildingSelection()
	end
end

function SelectionController:_setBuildingMode(isBuildingMode: boolean)
	if self._isBuildingMode == isBuildingMode then return end
	self._isBuildingMode = isBuildingMode
	
	if isBuildingMode then
		self:_closeNexoBuildMenu()
		self._hoveredBuilding = nil
		self:_clearBuildingSelection()
		self._machine:TransitionTo(InteractionStates.BuildPlacement)
	else
		self._machine:TransitionTo(InteractionStates.Idle)
	end
end

function SelectionController:_getPointerPosition(): Vector2?
	if self._lastTouchPosition ~= nil then return self._lastTouchPosition end
	local mouseLocation = UserInputService:GetMouseLocation()
	if mouseLocation.X >= 0 and mouseLocation.Y >= 0 then return mouseLocation end
	return nil
end

function SelectionController:_isPointerOverUi(pointerPosition: Vector2): boolean
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if playerGui == nil or not playerGui:IsA("PlayerGui") then return false end
	return WorldInput.IsPointerBlocked(playerGui, pointerPosition)
end

function SelectionController:_isPointerOverNexoBuildPanel(pointerPosition: Vector2): boolean
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if playerGui == nil or not playerGui:IsA("PlayerGui") then return false end
	for _, guiObject in playerGui:GetGuiObjectsAtPosition(pointerPosition.X, pointerPosition.Y) do
		local screenGui = guiObject:FindFirstAncestorOfClass("ScreenGui")
		if screenGui == nil or screenGui.Name ~= "SelectionMenuGui" then continue end
		if guiObject.Name == "NexoBuildPanel" or guiObject:FindFirstAncestor("NexoBuildPanel") ~= nil then
			return true
		end
	end
	return false
end

-- =========================================================================
-- Nexo State & Visuals
-- =========================================================================

function SelectionController:_setSnapshot(snapshot)
	self._snapshot = snapshot
	if typeof(snapshot.remainingSeconds) == "number" then
		self._remainingSeconds = snapshot.remainingSeconds
	end
	if snapshot.phaseActive == false and self._remainingSeconds <= 0 then
		self._selectionEnded = true
	end
	self:_refreshNexoRaycastFilter()
	self:_syncAssignedNexoFromSnapshot()
	self:_applyNexoSnapshotVisuals()
	self:_applyNexoHoverHighlight()
	self:_applyAssignedNexoHighlight()
	self:_renderUi()
end

function SelectionController:_syncAssignedNexoFromSnapshot()
	if self._snapshot == nil or self._snapshot.nexos == nil then return end
	for _, record in self._snapshot.nexos do
		if record.takenByUserId == LOCAL_PLAYER.UserId then
			self._assignedNexoId = record.id
			return
		end
	end
end

function SelectionController:_refreshNexoRaycastFilter()
	local includeInstances = self._nexoRaycastInclude
	table.clear(includeInstances)
	if self._snapshot == nil or self._snapshot.nexos == nil then
		self._nexoRaycastParams.FilterDescendantsInstances = includeInstances
		return
	end
	for _, record in self._snapshot.nexos do
		if record.instance ~= nil then table.insert(includeInstances, record.instance) end
	end
	self._nexoRaycastParams.FilterDescendantsInstances = includeInstances
end

-- =========================================================================
-- Entity Querying (Raycasts)
-- =========================================================================

function SelectionController:_getProjectedNexoAtPointer(pointerPosition: Vector2)
	local camera = self._camera
	if camera == nil or self._snapshot.nexos == nil then return nil end
	local closestRecord = nil
	local closestDistanceSquared = PROJECTED_NEXO_PICK_RADIUS * PROJECTED_NEXO_PICK_RADIUS

	for _, record in self._snapshot.nexos do
		local rootPart = record.rootPart
		if rootPart == nil or rootPart.Parent == nil then continue end
		local viewportPoint, onScreen = camera:WorldToViewportPoint(rootPart.Position)
		if not onScreen then continue end

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

function SelectionController:_getEntityAtPointer(pointerPosition: Vector2)
	if self._camera == nil then return nil end

	-- 1. Try Units (if unitFolder exists)
	if self._unitFolder ~= nil then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = { self._unitFolder }
		local ray = self._camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
		local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE, raycastParams)
		if result ~= nil then
			local unitModel = findUnitModel(result.Instance, self._unitFolder)
			if unitModel ~= nil then
				return { Type = "Unit", Instance = unitModel }
			end
		end
	end

	-- 2. Try Buildings (if placedFolder exists)
	if self._placedFolder ~= nil then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = { self._placedFolder }
		local ray = self._camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
		local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE, raycastParams)
		if result ~= nil then
			local building = findBuildingModel(result.Instance, self._placedFolder)
			if building ~= nil then
				return { Type = "Building", Instance = building }
			end
		end
	end

	-- 3. Try Nexos (3D Raycast)
	if self._snapshot.nexos ~= nil and #self._nexoRaycastInclude > 0 then
		local ray = self._camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
		local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE, self._nexoRaycastParams)
		if result ~= nil then
			for _, record in self._snapshot.nexos do
				if instanceContains(record.instance, result.Instance) then
					return { Type = "Nexo", Id = record.id, Record = record }
				end
			end
		end
	end

	-- 4. Try Nexos (Projected - 2D Screen space)
	local projectedNexo = self:_getProjectedNexoAtPointer(pointerPosition)
	if projectedNexo ~= nil then
		return { Type = "Nexo", Id = projectedNexo.id, Record = projectedNexo }
	end

	-- 5. Try HexPart (Terrain)
	local ray = self._camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE)
	if result ~= nil then
		local hexPart = findHexPart(result.Instance)
		if hexPart ~= nil then
			return { Type = "Hex", Part = hexPart }
		end
	end

	return nil
end

-- =========================================================================
-- Input & Hover Handling
-- =========================================================================

function SelectionController:_handleInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then return end

	if input.KeyCode == Enum.KeyCode.Escape then
		if #self._selectionOrder > 0 then
			self:_clearUnitSelection()
			return
		end
		if self._selectedNexoId ~= nil then
			self:_closeNexoSelectionMenu(true)
			return
		end
		if self:_isNexoBuildMenuOpen() then
			self:_closeNexoBuildMenu()
			return
		end
		if self._selectedBuilding ~= nil then
			self:_clearBuildingSelection()
			return
		end
	end

	if self._isBuildingMode then return end
	
	if not canInteractWithNexo(self._playerState) and not canInteractWithBuildings(self._playerState) then
		self:_closeNexoSelectionMenu(false)
		self:_closeNexoBuildMenu()
		self:_clearNexoHover()
		self:_clearBuildingSelection()
		self:_clearUnitSelection()
		return
	end

	if self:_isNexoBuildMenuOpen() then
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pointerPosition = UserInputService:GetMouseLocation()
			if not self:_isPointerOverNexoBuildPanel(pointerPosition) then
				self:_closeNexoBuildMenu()
			end
		end
		return
	end

	local pointerPosition = nil
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		pointerPosition = UserInputService:GetMouseLocation()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		pointerPosition = Vector2.new(input.Position.X, input.Position.Y)
		self._lastTouchPosition = pointerPosition
	else
		return
	end

	if pointerPosition == nil or self:_isPointerOverUi(pointerPosition) then return end

	local entity = self:_getEntityAtPointer(pointerPosition)
	
	-- Nexo Selection Phase
	if self._snapshot.phaseActive == true then
		if entity ~= nil and entity.Type == "Nexo" then
			self:_handleNexoSelectionPointer(entity.Record)
		else
			self:_closeNexoSelectionMenu(true)
		end
		return
	end

	-- In-Match Selection
	if entity == nil then
		self:_clearBuildingSelection()
		self:_clearUnitSelection()
		return
	end

	if entity.Type == "Unit" then
		self:_clearBuildingSelection()
		self:_toggleUnit(entity.Instance)
	elseif entity.Type == "Hex" then
		if #self._selectionOrder > 0 then
			self:_requestUnitMove(entity.Part)
		else
			self:_clearBuildingSelection()
			self:_clearUnitSelection()
		end
	elseif entity.Type == "Nexo" then
		self:_clearUnitSelection()
		self:_handleNexoBuildMenuPointer(entity.Record)
	elseif entity.Type == "Building" then
		self:_clearUnitSelection()
		self:_handleBuildingSelectionPointer(entity.Instance)
	end
end

function SelectionController:_updateHover()
	if self._destroyed or self._isBuildingMode or self:_isNexoBuildMenuOpen() then
		self:_clearNexoHover()
		self:_clearBuildingHover()
		return
	end

	local pointerPosition = self:_getPointerPosition()
	if pointerPosition == nil or self:_isPointerOverUi(pointerPosition) then
		self:_clearNexoHover()
		self:_clearBuildingHover()
		return
	end

	local entity = self:_getEntityAtPointer(pointerPosition)

	if self._snapshot.phaseActive == true then
		self:_clearBuildingHover()
		if self._assignedNexoId ~= nil or self._selectedNexoId ~= nil then
			self:_clearNexoHover()
			return
		end
		
		local nextHoveredId = if entity ~= nil and entity.Type == "Nexo" then entity.Id else nil
		if nextHoveredId ~= self._hoveredNexoId then
			self._hoveredNexoId = nextHoveredId
			self:_applyNexoHoverHighlight()
		end
		return
	end

	-- Match phase hover
	if entity ~= nil and entity.Type == "Nexo" then
		self:_clearBuildingHover()
		if self:_canOpenNexoBuildMenu() and entity.Id == self._assignedNexoId then
			self._hoveredNexoId = entity.Id
			self._machine:TransitionTo(InteractionStates.HoveringNexo)
		else
			self._hoveredNexoId = nil
		end
		self:_applyAssignedNexoHighlight()
	elseif entity ~= nil and entity.Type == "Building" then
		self:_clearNexoHover()
		if canInteractWithBuildings(self._playerState) then
			if self._hoveredBuilding ~= entity.Instance then
				self._hoveredBuilding = entity.Instance
				self:_refreshBuildingState()
			end
		end
	else
		self:_clearNexoHover()
		self:_clearBuildingHover()
	end
end

-- =========================================================================
-- Nexo Actions
-- =========================================================================

function SelectionController:_handleNexoSelectionPointer(record)
	if self._assignedNexoId ~= nil then return end
	local canPreview = record ~= nil and (
		record.state == NexoConfig.States.Available or
		(record.state == NexoConfig.States.Selected and record.selectedByUserId == LOCAL_PLAYER.UserId)
	)
	if not canPreview then return end

	self:_openNexoSelectionMenu(record.id)
end

function SelectionController:_handleNexoBuildMenuPointer(record)
	if not self:_canOpenNexoBuildMenu() then return end
	if record == nil or record.id ~= self._assignedNexoId then return end
	self:_openNexoBuildMenu()
end

function SelectionController:_openNexoSelectionMenu(nexoId: string)
	if self._nexoService == nil or not canInteractWithNexo(self._playerState) then return end
	if self._menuCoordinator ~= nil then
		self._menuCoordinator:RequestOpen(DiplomacyConfig.MenuIds.Nexo, function()
			self:_closeNexoSelectionMenu(false)
		end)
	end
	self._selectedNexoId = nexoId
	self:_renderUi()
	
	task.spawn(function()
		local result = self._nexoService:PreviewNexo(nexoId)
		if result ~= nil and result.ok ~= true then
			-- If server rejects, and we haven't selected another one in the meantime
			if self._selectedNexoId == nexoId then
				self._selectedNexoId = nil
				self:_renderUi()
			end
		end
	end)
end

function SelectionController:_closeNexoSelectionMenu(release: boolean)
	local nexoId = self._selectedNexoId
	self._selectedNexoId = nil
	if self._menuCoordinator ~= nil then
		self._menuCoordinator:Close(DiplomacyConfig.MenuIds.Nexo)
	end
	if release and nexoId ~= nil and self._nexoService ~= nil then
		task.spawn(function()
			self._nexoService:ReleaseNexo(nexoId)
		end)
	end
	self:_renderUi()
end

function SelectionController:_claimSelectedNexo()
	if self._selectedNexoId == nil or self._nexoService == nil or not canInteractWithNexo(self._playerState) then return end
	
	-- Set loading state artificially or just spawn to avoid UI freeze
	local nexoId = self._selectedNexoId
	task.spawn(function()
		local result = self._nexoService:ClaimNexo(nexoId)
		if result ~= nil and result.ok == true then
			self:_closeNexoSelectionMenu(false)
		end
	end)
end

function SelectionController:_canOpenNexoBuildMenu(): boolean
	return self._selectionEnded
		and self._snapshot.phaseActive ~= true
		and self._assignedNexoId ~= nil
		and not self._isBuildingMode
		and canInteractWithNexo(self._playerState)
end

function SelectionController:_openNexoBuildMenu()
	if not self:_canOpenNexoBuildMenu() then return end
	if self._menuCoordinator ~= nil then
		self._menuCoordinator:RequestOpen(DiplomacyConfig.MenuIds.NexoBuild, function()
			self:_closeNexoBuildMenu()
		end)
	end
	self:_refreshResources()
	self._machine:TransitionTo(InteractionStates.NexoMenuOpen)
	self:_applyAssignedNexoHighlight()
	self:_renderUi()
end

function SelectionController:_closeNexoBuildMenu()
	if not self:_isNexoBuildMenuOpen() then return end
	if self._menuCoordinator ~= nil then
		self._menuCoordinator:Close(DiplomacyConfig.MenuIds.NexoBuild)
	end
	self._machine:TransitionTo(InteractionStates.Idle)
	self:_applyAssignedNexoHighlight()
	self:_renderUi()
end

function SelectionController:_isNexoBuildMenuOpen(): boolean
	return self._machine:GetState() == InteractionStates.NexoMenuOpen
end

function SelectionController:_selectBuildingFromNexo(buildingType: string)
	if not canInteractWithNexo(self._playerState) then return end
	self._machine:TransitionTo(InteractionStates.BuildPlacement)
	self:_renderUi()
	if self._buildController ~= nil then
		self._buildController:SetSelectedBuildingType(buildingType)
	end
end

function SelectionController:_showAssignment(payload)
	if payload ~= nil and typeof(payload.nexoId) == "string" then
		self._assignedNexoId = payload.nexoId
		self:_applyAssignedNexoHighlight()
	end
	local displayName = if payload ~= nil and typeof(payload.displayName) == "string" then payload.displayName else "NEXO"
	self._assignmentToken += 1
	local token = self._assignmentToken
	self._assignmentMessage = `SE TE ASIGNO EL NEXO {string.upper(displayName)}`
	self:_renderUi()
	task.delay(NexoConfig.AssignmentMessageSeconds, function()
		if self._destroyed or self._assignmentToken ~= token then return end
		self._assignmentMessage = nil
		self:_renderUi()
	end)
end

function SelectionController:_clearNexoHover()
	if self._hoveredNexoId == nil and not self._nexoHighlight.Enabled then return end
	self._hoveredNexoId = nil
	self:_applyNexoHoverHighlight()
	if self._machine:GetState() == InteractionStates.HoveringNexo then
		self._machine:TransitionTo(InteractionStates.Idle)
		self:_applyAssignedNexoHighlight()
	end
end

-- =========================================================================
-- Building Actions
-- =========================================================================

function SelectionController:_handleBuildingSelectionPointer(building: Model)
	if self._menuCoordinator ~= nil then
		self._menuCoordinator:RequestOpen(DiplomacyConfig.MenuIds.Building, function()
			self:_clearBuildingSelection()
		end)
	end
	self._selectedBuilding = building
	self._machine:TransitionTo(InteractionStates.BuildingMenuOpen)
	self:_applyBuildingHighlight()
	self:_refreshSelectedBarracksQueue()
	self:_renderUi()
end

function SelectionController:_clearBuildingSelection()
	self._selectedBuilding = nil
	if self._menuCoordinator ~= nil then
		self._menuCoordinator:Close(DiplomacyConfig.MenuIds.Building)
	end
	self:_refreshBuildingState()
	self:_renderUi()
end

function SelectionController:_clearBuildingHover()
	if self._hoveredBuilding == nil and not self._buildingHighlight.Enabled then return end
	self._hoveredBuilding = nil
	self:_refreshBuildingState()
end

function SelectionController:_refreshBuildingState()
	if self._selectedBuilding ~= nil then
		if self._machine:GetState() ~= InteractionStates.BuildingMenuOpen then
			self._machine:TransitionTo(InteractionStates.SelectedBuilding)
		end
	elseif self._hoveredBuilding ~= nil then
		self._machine:TransitionTo(InteractionStates.HoveringBuilding)
	else
		if self._machine:GetState() == InteractionStates.HoveringBuilding or self._machine:GetState() == InteractionStates.SelectedBuilding or self._machine:GetState() == InteractionStates.BuildingMenuOpen then
			self._machine:TransitionTo(InteractionStates.Idle)
		end
	end
	self:_applyBuildingHighlight()
	self:_renderUi()
end

function SelectionController:_destroyActiveBuilding()
	if not canInteractWithBuildings(self._playerState) then return end
	local building = self._selectedBuilding
	if building == nil or self._buildService == nil then return end
	local buildingId = building:GetAttribute("BuildingId")
	if typeof(buildingId) ~= "string" then return end
	local result = self._buildService:RequestDestroy({ buildingId = buildingId })
	if result ~= nil and result.ok == true then
		self._hoveredBuilding = nil
		self:_clearBuildingSelection()
	end
end

function SelectionController:_moveActiveBuilding()
	if not canInteractWithBuildings(self._playerState) then return end
	local building = self._selectedBuilding
	if building == nil or self._buildController == nil then return end
	local result = self._buildController:StartMovingBuilding(building)
	if result == nil or result.ok == true then
		self._hoveredBuilding = nil
		self:_clearBuildingSelection()
	end
end

-- =========================================================================
-- Troop/Queue Actions
-- =========================================================================

function SelectionController:_refreshSelectedBarracksQueue()
	if not canInteractWithBuildings(self._playerState) then return end
	local building = self._selectedBuilding
	if building == nil or self._manpowerService == nil then return end
	if building:GetAttribute("BuildingType") ~= "Cuartel" or building:GetAttribute("OwnerUserId") ~= LOCAL_PLAYER.UserId then return end
	local buildingId = building:GetAttribute("BuildingId")
	if typeof(buildingId) ~= "string" then return end
	task.spawn(function()
		local result = self._manpowerService:GetBarracksQueue(buildingId)
		if result ~= nil and result.ok == true and result.queue ~= nil then
			self:_setQueueSnapshot(result.queue)
		end
	end)
end

function SelectionController:_queueSelectedUnit(unitType: string)
	if not canInteractWithBuildings(self._playerState) then return end
	local building = self._selectedBuilding
	if building == nil or self._manpowerService == nil then return end
	local buildingId = building:GetAttribute("BuildingId")
	if typeof(buildingId) ~= "string" then return end
	task.spawn(function()
		local result = self._manpowerService:RequestQueueUnit({ buildingId = buildingId, unitType = unitType })
		if result ~= nil and result.queue ~= nil then
			self:_setQueueSnapshot(result.queue)
		end
	end)
end

function SelectionController:_setQueueSnapshot(queue)
	if type(queue) ~= "table" or typeof(queue.BuildingId) ~= "string" then return end
	self._barracksQueues[queue.BuildingId] = queue
	self._queueReceivedAt[queue.BuildingId] = os.clock()
	if queue.Count == 0 then
		self:_removeQueueBillboard(queue.BuildingId)
	else
		self:_ensureQueueBillboard(queue.BuildingId)
	end
	self:_updateQueueBillboards()
	self:_renderUi()
end

function SelectionController:_getQueueForDisplay(buildingId: string)
	local queue = self._barracksQueues[buildingId]
	if queue == nil then return nil end
	local displayed = table.clone(queue)
	local sourceEntries = if type(queue.Entries) == "table" then queue.Entries else {}
	local entries = table.create(#sourceEntries)
	local elapsed = os.clock() - (self._queueReceivedAt[buildingId] or os.clock())
	for index = 1, #sourceEntries do
		local source = sourceEntries[index]
		local entry = table.clone(source)
		if index == 1 and entry.Ready ~= true and typeof(entry.Progress) == "number" and typeof(entry.TrainingTime) == "number" and entry.TrainingTime > 0 then
			entry.Progress = math.clamp(entry.Progress + (elapsed / entry.TrainingTime), 0, 1)
		end
		entries[index] = entry
	end
	displayed.Entries = entries
	return displayed
end

function SelectionController:_ensureQueueBillboard(buildingId: string)
	if self._queueBillboards[buildingId] ~= nil or self._placedFolder == nil then return end
	local model = self._placedFolder:FindFirstChild(buildingId)
	if model == nil or not model:IsA("Model") then return end
	local adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if adornee == nil then return end

	local _boxCFrame, boxSize = model:GetBoundingBox()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = `BarracksQueue_{buildingId}`
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 220
	billboard.Size = UDim2.fromOffset(px(140), px(36))
	billboard.StudsOffsetWorldSpace = Vector3.new(0, (boxSize.Y * 0.5) + 4.2, 0)
	billboard.Parent = adornee

	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = Color3.fromRGB(17, 20, 22)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = billboard
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(205, 159, 68)
	stroke.Thickness = px(1)
	stroke.Transparency = 0.14
	stroke.Parent = panel

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.Position = UDim2.fromOffset(px(6), px(3))
	label.Size = UDim2.new(1, -px(12), 0, px(14))
	label.TextColor3 = Color3.fromRGB(232, 235, 228)
	label.TextSize = px(10)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "PRODUCCION"
	label.Parent = panel

	local track = Instance.new("Frame")
	track.BackgroundColor3 = Color3.fromRGB(29, 33, 35)
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(px(6), px(22))
	track.Size = UDim2.new(1, -px(12), 0, px(7))
	track.Parent = panel

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(205, 159, 68)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track

	self._queueBillboards[buildingId] = { Billboard = billboard, Label = label, Fill = fill }
end

function SelectionController:_updateQueueBillboards()
	for buildingId, queue in self._barracksQueues do
		if queue.Count == 0 then
			self:_removeQueueBillboard(buildingId)
			continue
		end
		self:_ensureQueueBillboard(buildingId)
		local billboardState = self._queueBillboards[buildingId]
		local displayed = self:_getQueueForDisplay(buildingId)
		local active = if displayed ~= nil and type(displayed.Entries) == "table" then displayed.Entries[1] else nil
		if billboardState ~= nil and active ~= nil then
			local progress = if typeof(active.Progress) == "number" then active.Progress else 0
			local name = active.DisplayName or active.UnitType or "UNIDAD"
			billboardState.Label.Text = `{name}  {queue.Count}/{ManpowerConfig.QueueCapacity}`
			billboardState.Fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		end
	end
end

function SelectionController:_removeQueueBillboard(buildingId: string)
	local billboardState = self._queueBillboards[buildingId]
	if billboardState ~= nil then billboardState.Billboard:Destroy() end
	self._queueBillboards[buildingId] = nil
end

function SelectionController:_handleBuildingDestroyed(payload)
	if type(payload) ~= "table" or typeof(payload.BuildingId) ~= "string" then return end
	self._barracksQueues[payload.BuildingId] = nil
	self._queueReceivedAt[payload.BuildingId] = nil
	self:_removeQueueBillboard(payload.BuildingId)
	if self._selectedBuilding ~= nil and self._selectedBuilding:GetAttribute("BuildingId") == payload.BuildingId then
		self:_clearBuildingSelection()
	end
end

-- =========================================================================
-- Visual Applications
-- =========================================================================

function SelectionController:_applyBuildingHighlight()
	local highlightedBuilding = self._selectedBuilding or self._hoveredBuilding
	self._buildingHighlight.Adornee = highlightedBuilding
	self._buildingHighlight.Enabled = highlightedBuilding ~= nil
end

function SelectionController:_applyNexoHoverHighlight()
	local record = getRecordById(self._snapshot, self._hoveredNexoId)
	if record == nil or record.state == NexoConfig.States.Taken then
		self._nexoHighlight.Adornee = nil
		self._nexoHighlight.Enabled = false
		return
	end

	self._nexoHighlight.Adornee = record.instance
	self._nexoHighlight.Enabled = record.instance ~= nil

	if record.state == NexoConfig.States.Selected and record.selectedByUserId ~= LOCAL_PLAYER.UserId then
		self._nexoHighlight.FillColor = colors.Amber
		self._nexoHighlight.OutlineColor = colors.Amber
		self._nexoHighlight.FillTransparency = 0.9
		self._nexoHighlight.OutlineTransparency = 0.25
	else
		self._nexoHighlight.FillColor = Color3.fromRGB(255, 255, 255)
		self._nexoHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		self._nexoHighlight.FillTransparency = 0.82
		self._nexoHighlight.OutlineTransparency = 0.08
	end
end

function SelectionController:_applyAssignedNexoHighlight()
	local record = getRecordById(self._snapshot, self._assignedNexoId)
	if record == nil or record.instance == nil or record.active ~= true or (typeof(record.hp) == "number" and record.hp <= 0) then
		self._assignedNexoHighlight.Adornee = nil
		self._assignedNexoHighlight.Enabled = false
		return
	end

	local color = getStableColorForNexo(record.id)
	local state = self._machine:GetState()
	local fillTransparency = if state == InteractionStates.HoveringNexo or state == InteractionStates.NexoMenuOpen
		then NexoConfig.AssignedHighlight.HoverFillTransparency
		else NexoConfig.AssignedHighlight.FillTransparency

	self._assignedNexoHighlight.Adornee = record.instance
	self._assignedNexoHighlight.Enabled = true
	self._assignedNexoHighlight.FillColor = color
	self._assignedNexoHighlight.OutlineColor = color
	self._assignedNexoHighlight.FillTransparency = fillTransparency
	self._assignedNexoHighlight.OutlineTransparency = NexoConfig.AssignedHighlight.OutlineTransparency
end

function SelectionController:_applyNexoSnapshotVisuals()
	local seen = {}
	for _, record in self._snapshot.nexos do
		seen[record.id] = true
		if record.state == NexoConfig.States.Selected and record.selectedByUserId ~= nil and record.selectedByUserId ~= LOCAL_PLAYER.UserId then
			self:_ensureSelectedBillboard(record)
		else
			self:_removeSelectedBillboard(record.id)
		end
	end
	for nexoId in self._selectedBillboards do
		if seen[nexoId] ~= true then self:_removeSelectedBillboard(nexoId) end
	end
end

function SelectionController:_ensureSelectedBillboard(record)
	if self._selectedBillboards[record.id] ~= nil then return end
	local adornee = nil
	if record.instance ~= nil then
		adornee = if record.instance:IsA("BasePart") then record.instance else record.instance:FindFirstChildWhichIsA("BasePart", true)
	end
	if adornee == nil then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = `NexoSelected_{record.id}`
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 260
	billboard.Size = SELECTED_BILLBOARD_SIZE
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = colors.Panel
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = "JUGADOR"
	label.TextColor3 = colors.Amber
	label.TextScaled = true
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.Amber
	stroke.Thickness = 1
	stroke.Transparency = 0.15
	stroke.Parent = label
	
	billboard.Parent = adornee
	self._selectedBillboards[record.id] = billboard
end

function SelectionController:_removeSelectedBillboard(nexoId: string)
	local billboard = self._selectedBillboards[nexoId]
	if billboard ~= nil then billboard:Destroy() end
	self._selectedBillboards[nexoId] = nil
end

function SelectionController:_toggleUnit(model: Model)
	if self._playerState ~= PlayerStates.Playing then return end
	if model:GetAttribute("OwnerUserId") ~= LOCAL_PLAYER.UserId then return end

	local unitId = model:GetAttribute("UnitId")
	if typeof(unitId) ~= "string" then return end

	if self._selectedUnits[unitId] ~= nil then
		self:_deselectUnit(unitId)
		return
	end

	self._selectedUnits[unitId] = model
	table.insert(self._selectionOrder, unitId)
	self:_ensureUnitHighlight(unitId, model)
	self:_renderUi()
end

function SelectionController:_ensureUnitHighlight(unitId: string, model: Model)
	if self._unitHighlights[unitId] ~= nil then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = `SelectedUnit_{unitId}`
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.78
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0.02
	highlight.Parent = Workspace
	self._unitHighlights[unitId] = highlight
	self._trove:Add(highlight)
end

function SelectionController:_deselectUnit(unitId: string)
	if self._selectedUnits[unitId] == nil then return end

	self._selectedUnits[unitId] = nil
	for index = #self._selectionOrder, 1, -1 do
		if self._selectionOrder[index] == unitId then
			table.remove(self._selectionOrder, index)
			break
		end
	end

	local highlight = self._unitHighlights[unitId]
	if highlight ~= nil then
		highlight:Destroy()
	end
	self._unitHighlights[unitId] = nil
	self:_renderUi()
end

function SelectionController:_clearUnitSelection()
	for index = #self._selectionOrder, 1, -1 do
		self:_deselectUnit(self._selectionOrder[index])
	end
end

function SelectionController:_requestUnitMove(hexPart: BasePart)
	if self._manpowerService == nil or self._playerState ~= PlayerStates.Playing then return end

	local unitIds = table.create(#self._selectionOrder)
	for index = 1, #self._selectionOrder do
		unitIds[index] = self._selectionOrder[index]
	end

	self._manpowerService:RequestMoveUnits({
		unitIds = unitIds,
		destinationHex = hexPart,
	})
end

function SelectionController:_getSelectedUnitsForBar()
	local units = table.create(#self._selectionOrder)
	for index = 1, #self._selectionOrder do
		local unitId = self._selectionOrder[index]
		local model = self._selectedUnits[unitId]
		if model ~= nil then
			local unitType = model:GetAttribute("UnitType") or "InfanteriaLigera"
			units[index] = {
				UnitId = unitId,
				UnitType = unitType,
			}
		end
	end
	return units
end

-- =========================================================================
-- Render Unified UI
-- =========================================================================

function SelectionController:_refreshResources()
	if self._buildService == nil then return end
	local resources = self._buildService:GetResources()
	if resources ~= nil then self._resources = resources end
end

function SelectionController:_renderUi()
	if self._root == nil then return end

	local state = self._machine:GetState()
	local nexoSelectionMenuVisible = self._selectedNexoId ~= nil
	local nexoBuildMenuVisible = self:_isNexoBuildMenuOpen()
	
	-- Building Data
	local buildingVisible = canInteractWithBuildings(self._playerState) and self._selectedBuilding ~= nil and (state == InteractionStates.BuildingMenuOpen or state == InteractionStates.SelectedBuilding)
	local buildingType = if self._selectedBuilding ~= nil then self._selectedBuilding:GetAttribute("BuildingType") else nil
	local hp = if self._selectedBuilding ~= nil then self._selectedBuilding:GetAttribute("HP") else nil
	local maxHp = if self._selectedBuilding ~= nil then self._selectedBuilding:GetAttribute("MaxHP") else nil
	local ownerUserId = if self._selectedBuilding ~= nil then self._selectedBuilding:GetAttribute("OwnerUserId") else nil
	local canEdit = ownerUserId == LOCAL_PLAYER.UserId
	local buildingId = if self._selectedBuilding ~= nil then self._selectedBuilding:GetAttribute("BuildingId") else nil
	local queue = if typeof(buildingId) == "string" then self:_getQueueForDisplay(buildingId) else nil

	self._root:render(React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		NexoTimerPanel = React.createElement(NexoTimerUI, {
			visible = self._snapshot.phaseActive == true,
			segundosRestantes = self._remainingSeconds,
			assignmentMessage = self._assignmentMessage,
		}),
		NexoSelectionMenu = React.createElement(NexoSelectionMenu, {
			visible = nexoSelectionMenuVisible,
			nexoId = self._selectedNexoId,
			snapshot = self._snapshot,
			localUserId = LOCAL_PLAYER.UserId,
			onSelect = function() self:_claimSelectedNexo() end,
			onClose = function() self:_closeNexoSelectionMenu(true) end,
		}),
		NexoBuildMenu = React.createElement(NexoBuildMenu, {
			visible = nexoBuildMenuVisible,
			resources = self._resources,
			onClose = function() self:_closeNexoBuildMenu() end,
			onSelectBuilding = function(bType: string) self:_selectBuildingFromNexo(bType) end,
		}),
		BuildingMenu = React.createElement(BuildingMenu, {
			visible = buildingVisible,
			buildingType = buildingType,
			hp = hp,
			maxHp = maxHp,
			canEdit = canEdit,
			queue = queue,
			onMove = function() self:_moveActiveBuilding() end,
			onDestroy = function() self:_destroyActiveBuilding() end,
			onClose = function() self:_clearBuildingSelection() end,
			onQueueUnit = function(uType: string) self:_queueSelectedUnit(uType) end,
		}),
		UnitSelectionBar = React.createElement(UnitSelectionBar, {
			units = self:_getSelectedUnitsForBar(),
			onDeselect = function(unitId: string)
				self:_deselectUnit(unitId)
			end,
		})
	}))
end

function SelectionController:Destroy()
	if self._destroyed then return end
	self._destroyed = true

	self._buildingHighlight:Destroy()
	self._nexoHighlight:Destroy()
	self._assignedNexoHighlight:Destroy()
	for nexoId in self._selectedBillboards do self:_removeSelectedBillboard(nexoId) end
	for buildingId in self._queueBillboards do self:_removeQueueBillboard(buildingId) end
	
	for unitId, highlight in self._unitHighlights do
		if highlight ~= nil then
			highlight:Destroy()
		end
	end
	table.clear(self._unitHighlights)
	table.clear(self._selectedUnits)
	table.clear(self._selectionOrder)

	self._trove:Destroy()
	table.clear(self._nexoRaycastInclude)
end

return SelectionController
