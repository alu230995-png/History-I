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
local DiplomacyConfig = require(Shared:WaitForChild("Constants"):WaitForChild("DiplomacyConfig"))
local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local PlayerStates = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStates"))
local SelectionConfig = require(Shared:WaitForChild("Constants"):WaitForChild("SelectionConfig"))
local StateMachine = require(Shared:WaitForChild("Classes"):WaitForChild("StateMachine"))

local AreaSelector = require(script.Parent.Parent:WaitForChild("Selection"):WaitForChild("AreaSelector"))
local EntityPicker = require(script.Parent.Parent:WaitForChild("Selection"):WaitForChild("EntityPicker"))
local PointerTracker = require(script.Parent.Parent:WaitForChild("Selection"):WaitForChild("PointerTracker"))
local SelectionStore = require(script.Parent.Parent:WaitForChild("Selection"):WaitForChild("SelectionStore"))
local SelectionVisuals = require(script.Parent.Parent:WaitForChild("Selection"):WaitForChild("SelectionVisuals"))

local NexoBuildMenu =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("NexoBuildMenu"):WaitForChild("index"))
local NexoSelectionMenu =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("NexoSelectionMenu"):WaitForChild("index"))
local NexoTimerUI =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("NexoTimerUI"):WaitForChild("index"))
local SelectionActionPanel =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("SelectionActionPanel"):WaitForChild("index"))
local SelectionAreaOverlay =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("SelectionAreaOverlay"):WaitForChild("index"))

local UITheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local WorldInput = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("WorldInput"))

local SelectionController = Knit.CreateController({
	Name = "SelectionController",
})

local LOCAL_PLAYER = Players.LocalPlayer
local SELECTED_BILLBOARD_SIZE = UDim2.fromOffset(46, 22)
local px = UITheme.sp
local colors = UITheme.Colors
local EntityTypes = SelectionConfig.EntityTypes
local InteractionStates = SelectionConfig.InteractionStates

local function canInteractWithBuildings(playerState: string?): boolean
	return playerState == PlayerStates.Playing
end

local function canCommandUnits(playerState: string?): boolean
	return playerState == PlayerStates.Playing
end

local function canInteractWithNexo(playerState: string?): boolean
	return playerState ~= PlayerStates.Defeated and playerState ~= PlayerStates.Spectating
end

local function getRecordById(snapshot, nexoId: string?)
	if snapshot == nil or snapshot.nexos == nil or nexoId == nil then
		return nil
	end

	for _, record in snapshot.nexos do
		if record.id == nexoId then
			return record
		end
	end

	return nil
end

local function getStableColorForNexo(nexoId: string?): Color3
	local text = nexoId or ""
	local hash = 0
	for index = 1, #text do
		hash = (hash * 31 + string.byte(text, index)) % 100000
	end

	local palette = SelectionConfig.AssignedNexoColors
	return palette[(hash % #palette) + 1]
end

function SelectionController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._camera = Workspace.CurrentCamera
	self._lastViewportSize = if self._camera ~= nil then self._camera.ViewportSize else Vector2.zero

	self._placedFolder = nil
	self._nexoService = nil
	self._buildService = nil
	self._buildController = nil
	self._menuCoordinator = nil
	self._gameService = nil
	self._manpowerService = nil
	self._unitFolder = nil

	self._playerState = nil
	self._root = nil
	self._screenGui = nil
	self._isBuildingMode = false
	self._lastUiSignature = nil
	self._lastAreaSignature = nil
	self._asyncToken = 0

	self._machine = StateMachine.new(InteractionStates.Idle, SelectionConfig.AllowedTransitions)
	self._trove:Add(self._machine)

	self._pointer = PointerTracker.new(UserInputService)
	self._areaSelector = AreaSelector.new()
	self._entityPicker = EntityPicker.new()
	self._selectionStore = SelectionStore.new(LOCAL_PLAYER.UserId)
	self._visuals = SelectionVisuals.new(self._trove)
	self._trove:Add(function()
		self._pointer:Destroy()
		self._areaSelector:Destroy()
		self._entityPicker:Destroy()
		self._selectionStore:Destroy()
		self._visuals:Destroy()
	end)

	self._snapshot = { phaseActive = false, remainingSeconds = NexoConfig.SelectionDurationSeconds, nexos = {} }
	self._resources = nil
	self._remainingSeconds = NexoConfig.SelectionDurationSeconds
	self._selectedNexoId = nil
	self._assignedNexoId = nil
	self._hoveredEntity = nil
	self._assignmentMessage = nil
	self._assignmentToken = 0
	self._selectedBillboards = {}
	self._selectionEnded = false

	self._barracksQueues = {}
	self._queueReceivedAt = {}
	self._queueBillboards = {}

	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
		self._lastViewportSize = if self._camera ~= nil then self._camera.ViewportSize else Vector2.zero
		self._entityPicker:SetCamera(self._camera)
		self:_renderUi()
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

	self._entityPicker:SetCamera(self._camera)
	self._entityPicker:SetPlacedFolder(self._placedFolder)
	self._entityPicker:SetUnitFolder(self._unitFolder)

	if self._unitFolder ~= nil then
		self._trove:Add(self._unitFolder.ChildRemoved:Connect(function(child)
			local unitId = child:GetAttribute("UnitId")
			if typeof(unitId) == "string" and self._selectionStore:DeselectUnit(unitId) then
				self:_syncSelectionVisuals()
				self:_renderUi()
			end
		end))
	end

	self:_mountUi()
	self:_refreshResources()

	local snapshot = self._nexoService:GetSnapshot()
	if snapshot ~= nil then
		self:_setSnapshot(snapshot)
	end

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
		if snapshotEnded ~= nil then
			self:_setSnapshot(snapshotEnded)
		end
		self._selectionEnded = true
		self:_closeNexoSelectionMenu(false)
		self:_clearHover()
		self:_renderUi()
	end))

	self._trove:Add(self._buildService.ResourcesChanged:Connect(function(resources)
		self._resources = resources
		if self:_isNexoBuildMenuOpen() then
			self:_renderUi()
		end
	end))

	self._trove:Add(self._manpowerService.QueueChanged:Connect(function(queue)
		self:_setQueueSnapshot(queue)
	end))

	self._trove:Add(self._buildService.BuildingDestroyed:Connect(function(payload)
		self:_handleBuildingDestroyed(payload)
	end))

	self._trove:Add(self._gameService.PlayerStateChanged:Connect(function(_oldState: string, newState: string)
		self:_setPlayerState(newState)
	end))
	self:_setPlayerState(self._gameService:GetPlayerState())

	self._trove:Add(RunService.RenderStepped:Connect(function()
		self:_step()
	end))

	self._trove:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		self:_handleInputBegan(input, gameProcessedEvent)
	end))

	self._trove:Add(UserInputService.InputChanged:Connect(function(input: InputObject)
		self:_handleInputChanged(input)
	end))

	self._trove:Add(UserInputService.InputEnded:Connect(function(input: InputObject)
		self:_handleInputEnded(input)
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
	self._trove:Add(function()
		root:unmount()
	end)
	self._trove:Add(screenGui)

	self:_renderUi()
end

function SelectionController:_nextAsyncToken(): number
	self._asyncToken += 1
	return self._asyncToken
end

function SelectionController:_setPlayerState(state: string?)
	self._playerState = state
	self:_setBuildingMode(state == PlayerStates.Building)

	if not canInteractWithNexo(state) then
		self:_closeNexoSelectionMenu(false)
		self:_closeNexoBuildMenu()
		self:_clearHover()
	end

	if not canInteractWithBuildings(state) then
		self:_clearBuildingSelection()
	end

	if not canCommandUnits(state) then
		self:_clearUnitSelection()
	end

	if state == PlayerStates.Building then
		self:_clearUnitSelection()
		self:_clearBuildingSelection()
		self:_closeNexoBuildMenu()
	end

	self:_renderUi()
end

function SelectionController:_setBuildingMode(isBuildingMode: boolean)
	if self._isBuildingMode == isBuildingMode then
		return
	end

	self._isBuildingMode = isBuildingMode
	if isBuildingMode then
		self._areaSelector:Cancel()
		self:_clearHover()
		self:_clearUnitSelection()
		self:_clearBuildingSelection()
		self:_closeNexoBuildMenu()
		self._machine:TransitionTo(InteractionStates.BuildPlacement)
	else
		self._machine:TransitionTo(InteractionStates.Idle)
	end
end

function SelectionController:_isPointerOverUi(pointerPosition: Vector2): boolean
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		return false
	end

	return WorldInput.IsPointerBlocked(playerGui, pointerPosition)
end

function SelectionController:_isPointerOverNexoBuildPanel(pointerPosition: Vector2): boolean
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		return false
	end

	for _, guiObject in playerGui:GetGuiObjectsAtPosition(pointerPosition.X, pointerPosition.Y) do
		local screenGui = guiObject:FindFirstAncestorOfClass("ScreenGui")
		if screenGui == nil or screenGui.Name ~= "SelectionMenuGui" then
			continue
		end
		if guiObject.Name == "NexoBuildPanel" or guiObject:FindFirstAncestor("NexoBuildPanel") ~= nil then
			return true
		end
	end

	return false
end

function SelectionController:_setSnapshot(snapshot)
	self._snapshot = snapshot
		or { phaseActive = false, remainingSeconds = NexoConfig.SelectionDurationSeconds, nexos = {} }
	if typeof(self._snapshot.remainingSeconds) == "number" then
		self._remainingSeconds = self._snapshot.remainingSeconds
	end
	if self._snapshot.phaseActive == false and self._remainingSeconds <= 0 then
		self._selectionEnded = true
	end

	self._entityPicker:SetNexoSnapshot(self._snapshot)
	self:_syncAssignedNexoFromSnapshot()
	self:_applyNexoSnapshotVisuals()
	self:_applyAssignedNexoHighlight()
	self:_renderUi()
end

function SelectionController:_syncAssignedNexoFromSnapshot()
	if self._snapshot == nil or self._snapshot.nexos == nil then
		return
	end

	for _, record in self._snapshot.nexos do
		if record.takenByUserId == LOCAL_PLAYER.UserId then
			self._assignedNexoId = record.id
			return
		end
	end
end

function SelectionController:_step()
	if self._destroyed then
		return
	end

	local viewportSize = if self._camera ~= nil then self._camera.ViewportSize else Vector2.zero
	if viewportSize ~= self._lastViewportSize then
		self._lastViewportSize = viewportSize
		self:_renderUi()
	end

	self:_updateQueueBillboards()

	if self._areaSelector:IsActive() then
		local pointerPosition = self._pointer:GetPosition()
		if pointerPosition ~= nil then
			self._areaSelector:Update(pointerPosition)
			if self._areaSelector:IsDragging() then
				self._machine:TransitionTo(InteractionStates.AreaSelecting)
			end
			self:_renderAreaIfChanged()
		end
		return
	end

	self:_updateHover()
end

function SelectionController:_handleInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		self:_handleEscape()
		return
	end

	if self._isBuildingMode then
		return
	end

	local pointerPosition = nil
	if
		input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton3
	then
		pointerPosition = self._pointer:BeginInput(input)
	else
		return
	end

	if pointerPosition == nil then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton3 or self._areaSelector:CanBegin(input) then
		if not self:_isPointerOverUi(pointerPosition) and self._areaSelector:Begin(input, pointerPosition) then
			self._machine:TransitionTo(InteractionStates.AreaSelecting)
			self:_renderUi()
			return
		end
	end

	if self:_isNexoBuildMenuOpen() then
		if
			(input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
			and not self:_isPointerOverNexoBuildPanel(pointerPosition)
		then
			self:_closeNexoBuildMenu()
		end
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	if self:_isPointerOverUi(pointerPosition) then
		return
	end

	self:_handlePrimaryPointer(pointerPosition)
end

function SelectionController:_handleInputChanged(input: InputObject)
	local changedPointerPosition = self._pointer:UpdateInput(input)

	if self._areaSelector:IsActive() then
		local pointerPosition = changedPointerPosition or self._pointer:GetPosition()
		if pointerPosition ~= nil then
			self._areaSelector:Update(pointerPosition)
			self:_renderAreaIfChanged()
		end
	end
end

function SelectionController:_handleInputEnded(input: InputObject)
	local shouldFinishArea = self._areaSelector:IsActive()
		and self._areaSelector:MatchesInput(input)
		and (input.UserInputType == Enum.UserInputType.MouseButton3 or input.UserInputType == Enum.UserInputType.Touch)

	if shouldFinishArea then
		local rect = self._areaSelector:Finish()
		if rect ~= nil and canCommandUnits(self._playerState) then
			local units =
				self._entityPicker:GetOwnUnitsInRect(rect, LOCAL_PLAYER.UserId, SelectionConfig.MaxSelectedUnits)
			if #units > 0 then
				self:_clearBuildingSelection()
				self._selectionStore:SelectUnits(units, true)
				self:_syncSelectionVisuals()
			end
		end

		self._machine:TransitionTo(InteractionStates.Idle)
		self._lastAreaSignature = nil
		self:_renderUi()
	end

	if input.UserInputType == Enum.UserInputType.Touch then
		self._pointer:ClearTouch(input)
	end
end

function SelectionController:_handleEscape()
	if self._areaSelector:IsActive() or self._areaSelector:IsTouchArmed() then
		self._areaSelector:Cancel()
		self._machine:TransitionTo(InteractionStates.Idle)
		self:_renderUi()
		return
	end

	if self._selectionStore:GetSelectedUnitCount() > 0 then
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

	if self._selectionStore:GetSelectedBuilding() ~= nil then
		self:_clearBuildingSelection()
	end
end

function SelectionController:_handlePrimaryPointer(pointerPosition: Vector2)
	if not canInteractWithNexo(self._playerState) and not canInteractWithBuildings(self._playerState) then
		self:_closeNexoSelectionMenu(false)
		self:_closeNexoBuildMenu()
		self:_clearHover()
		self:_clearBuildingSelection()
		self:_clearUnitSelection()
		return
	end

	local entity = self._entityPicker:Pick(pointerPosition)

	if self._snapshot.phaseActive == true then
		self:_clearBuildingSelection()
		self:_clearUnitSelection()
		if entity ~= nil and entity.Type == EntityTypes.Nexo then
			self:_handleNexoSelectionPointer(entity.Record)
		else
			self:_closeNexoSelectionMenu(true)
		end
		return
	end

	if entity == nil then
		self:_clearBuildingSelection()
		self:_clearUnitSelection()
		return
	end

	if entity.Type == EntityTypes.Unit then
		self:_clearBuildingSelection()
		if self._selectionStore:ToggleUnit(entity.Instance) then
			self:_syncSelectionVisuals()
			self:_renderUi()
		end
	elseif entity.Type == EntityTypes.Hex then
		if self._selectionStore:GetSelectedUnitCount() > 0 then
			self:_requestUnitMove(entity.Part)
		else
			self:_clearBuildingSelection()
			self:_clearUnitSelection()
		end
	elseif entity.Type == EntityTypes.Nexo then
		self:_clearUnitSelection()
		if entity.Id == self._assignedNexoId and self:_canOpenNexoBuildMenu() then
			self:_openNexoBuildMenu()
		end
	elseif entity.Type == EntityTypes.Building then
		self:_clearUnitSelection()
		self:_handleBuildingSelectionPointer(entity.Instance)
	end
end

function SelectionController:_updateHover()
	if self._isBuildingMode or self:_isNexoBuildMenuOpen() then
		self:_clearHover()
		return
	end

	local pointerPosition = self._pointer:GetPosition()
	if pointerPosition == nil or self:_isPointerOverUi(pointerPosition) then
		self:_clearHover()
		return
	end

	local entity = self._entityPicker:Pick(pointerPosition)
	if self._snapshot.phaseActive == true then
		if
			self._assignedNexoId ~= nil
			or self._selectedNexoId ~= nil
			or entity == nil
			or entity.Type ~= EntityTypes.Nexo
		then
			entity = nil
		end
	elseif entity ~= nil and entity.Type == EntityTypes.Hex then
		entity = nil
	end

	self._hoveredEntity = entity
	self._visuals:SetHover(entity, LOCAL_PLAYER.UserId)
	self:_applyAssignedNexoHighlight()

	if entity ~= nil then
		self._machine:TransitionTo(InteractionStates.Hovering)
	elseif self._machine:GetState() == InteractionStates.Hovering then
		self._machine:TransitionTo(InteractionStates.Idle)
	end
end

function SelectionController:_clearHover()
	self._hoveredEntity = nil
	self._visuals:SetHover(nil, LOCAL_PLAYER.UserId)
	if self._machine:GetState() == InteractionStates.Hovering then
		self._machine:TransitionTo(InteractionStates.Idle)
	end
	self:_applyAssignedNexoHighlight()
end

function SelectionController:_handleNexoSelectionPointer(record)
	if self._assignedNexoId ~= nil then
		return
	end

	local canPreview = record ~= nil
		and (
			record.state == NexoConfig.States.Available
			or (record.state == NexoConfig.States.Selected and record.selectedByUserId == LOCAL_PLAYER.UserId)
		)
	if not canPreview then
		return
	end

	self:_openNexoSelectionMenu(record.id)
end

function SelectionController:_openNexoSelectionMenu(nexoId: string)
	if self._nexoService == nil or not canInteractWithNexo(self._playerState) then
		return
	end

	if self._menuCoordinator ~= nil then
		self._menuCoordinator:RequestOpen(DiplomacyConfig.MenuIds.Nexo, function()
			self:_closeNexoSelectionMenu(false)
		end)
	end

	self._selectedNexoId = nexoId
	self:_renderUi()

	local token = self:_nextAsyncToken()
	task.spawn(function()
		local result = self._nexoService:PreviewNexo(nexoId)
		if self._destroyed or token ~= self._asyncToken then
			return
		end
		if result ~= nil and result.ok ~= true and self._selectedNexoId == nexoId then
			self._selectedNexoId = nil
			self:_renderUi()
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
		local token = self:_nextAsyncToken()
		task.spawn(function()
			self._nexoService:ReleaseNexo(nexoId)
			if self._destroyed or token ~= self._asyncToken then
				return
			end
		end)
	end

	self:_renderUi()
end

function SelectionController:_claimSelectedNexo()
	if self._selectedNexoId == nil or self._nexoService == nil or not canInteractWithNexo(self._playerState) then
		return
	end

	local nexoId = self._selectedNexoId
	local token = self:_nextAsyncToken()
	task.spawn(function()
		local result = self._nexoService:ClaimNexo(nexoId)
		if self._destroyed or token ~= self._asyncToken then
			return
		end
		if result ~= nil and result.ok == true then
			self:_closeNexoSelectionMenu(false)
		else
			self._selectedNexoId = nil
			self:_renderUi()
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
	if not self:_canOpenNexoBuildMenu() then
		return
	end

	if self._menuCoordinator ~= nil then
		self._menuCoordinator:RequestOpen(DiplomacyConfig.MenuIds.NexoBuild, function()
			self:_closeNexoBuildMenu()
		end)
	end

	self:_refreshResources()
	self._machine:TransitionTo(InteractionStates.NexoBuildMenuOpen)
	self:_applyAssignedNexoHighlight()
	self:_renderUi()
end

function SelectionController:_closeNexoBuildMenu()
	if not self:_isNexoBuildMenuOpen() then
		return
	end

	if self._menuCoordinator ~= nil then
		self._menuCoordinator:Close(DiplomacyConfig.MenuIds.NexoBuild)
	end

	self._machine:TransitionTo(InteractionStates.Idle)
	self:_applyAssignedNexoHighlight()
	self:_renderUi()
end

function SelectionController:_isNexoBuildMenuOpen(): boolean
	return self._machine:GetState() == InteractionStates.NexoBuildMenuOpen
end

function SelectionController:_selectBuildingFromNexo(buildingType: string)
	if not canInteractWithNexo(self._playerState) then
		return
	end

	self:_clearUnitSelection()
	self:_clearBuildingSelection()
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

	local displayName = if payload ~= nil and typeof(payload.displayName) == "string"
		then payload.displayName
		else "NEXO"
	self._assignmentToken += 1
	local token = self._assignmentToken
	self._assignmentMessage = `SE TE ASIGNO EL NEXO {string.upper(displayName)}`
	self:_renderUi()

	task.delay(NexoConfig.AssignmentMessageSeconds, function()
		if self._destroyed or self._assignmentToken ~= token then
			return
		end
		self._assignmentMessage = nil
		self:_renderUi()
	end)
end

function SelectionController:_handleBuildingSelectionPointer(building: Model)
	if self._menuCoordinator ~= nil then
		self._menuCoordinator:RequestOpen(DiplomacyConfig.MenuIds.Building, function()
			self:_clearBuildingSelection()
		end)
	end

	self._selectionStore:SelectBuilding(building)
	self._machine:TransitionTo(InteractionStates.BuildingSelected)
	self:_syncSelectionVisuals()
	self:_refreshSelectedBarracksQueue()
	self:_renderUi()
end

function SelectionController:_clearBuildingSelection()
	if self._selectionStore:GetSelectedBuilding() == nil then
		return
	end

	self._selectionStore:ClearBuilding()
	if self._menuCoordinator ~= nil then
		self._menuCoordinator:Close(DiplomacyConfig.MenuIds.Building)
	end
	if self._machine:GetState() == InteractionStates.BuildingSelected then
		self._machine:TransitionTo(InteractionStates.Idle)
	end
	self:_syncSelectionVisuals()
	self:_renderUi()
end

function SelectionController:_destroyActiveBuilding()
	if not canInteractWithBuildings(self._playerState) then
		return
	end

	local building = self._selectionStore:GetSelectedBuilding()
	if building == nil or self._buildService == nil then
		return
	end

	local buildingId = building:GetAttribute("BuildingId")
	if typeof(buildingId) ~= "string" then
		return
	end

	local result = self._buildService:RequestDestroy({ buildingId = buildingId })
	if result ~= nil and result.ok == true then
		self:_clearBuildingSelection()
	else
		self:_renderUi()
	end
end

function SelectionController:_moveActiveBuilding()
	if not canInteractWithBuildings(self._playerState) then
		return
	end

	local building = self._selectionStore:GetSelectedBuilding()
	if building == nil or self._buildController == nil then
		return
	end

	local result = self._buildController:StartMovingBuilding(building)
	if result == nil or result.ok == true then
		self:_clearBuildingSelection()
	else
		self:_renderUi()
	end
end

function SelectionController:_refreshSelectedBarracksQueue()
	if not canInteractWithBuildings(self._playerState) then
		return
	end

	local building = self._selectionStore:GetSelectedBuilding()
	if building == nil or self._manpowerService == nil then
		return
	end
	if
		building:GetAttribute("BuildingType") ~= "Cuartel"
		or building:GetAttribute("OwnerUserId") ~= LOCAL_PLAYER.UserId
	then
		return
	end

	local buildingId = building:GetAttribute("BuildingId")
	if typeof(buildingId) ~= "string" then
		return
	end

	local token = self:_nextAsyncToken()
	task.spawn(function()
		local result = self._manpowerService:GetBarracksQueue(buildingId)
		if self._destroyed or token ~= self._asyncToken then
			return
		end
		if result ~= nil and result.ok == true and result.queue ~= nil then
			self:_setQueueSnapshot(result.queue)
		end
	end)
end

function SelectionController:_queueSelectedUnit(unitType: string)
	if not canInteractWithBuildings(self._playerState) then
		return
	end

	local building = self._selectionStore:GetSelectedBuilding()
	if building == nil or self._manpowerService == nil then
		return
	end

	local buildingId = building:GetAttribute("BuildingId")
	if typeof(buildingId) ~= "string" then
		return
	end

	local token = self:_nextAsyncToken()
	task.spawn(function()
		local result = self._manpowerService:RequestQueueUnit({ buildingId = buildingId, unitType = unitType })
		if self._destroyed or token ~= self._asyncToken then
			return
		end
		if result ~= nil and result.queue ~= nil then
			self:_setQueueSnapshot(result.queue)
		else
			self:_renderUi()
		end
	end)
end

function SelectionController:_setQueueSnapshot(queue)
	if type(queue) ~= "table" or typeof(queue.BuildingId) ~= "string" then
		return
	end

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
	if queue == nil then
		return nil
	end

	local displayed = table.clone(queue)
	local sourceEntries = if type(queue.Entries) == "table" then queue.Entries else {}
	local entries = table.create(#sourceEntries)
	local elapsed = os.clock() - (self._queueReceivedAt[buildingId] or os.clock())
	for index = 1, #sourceEntries do
		local source = sourceEntries[index]
		local entry = table.clone(source)
		if
			index == 1
			and entry.Ready ~= true
			and typeof(entry.Progress) == "number"
			and typeof(entry.TrainingTime) == "number"
			and entry.TrainingTime > 0
		then
			entry.Progress = math.clamp(entry.Progress + (elapsed / entry.TrainingTime), 0, 1)
		end
		entries[index] = entry
	end
	displayed.Entries = entries
	return displayed
end

function SelectionController:_ensureQueueBillboard(buildingId: string)
	if self._queueBillboards[buildingId] ~= nil or self._placedFolder == nil then
		return
	end

	local model = self._placedFolder:FindFirstChild(buildingId)
	if model == nil or not model:IsA("Model") then
		return
	end

	local adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if adornee == nil then
		return
	end

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
	stroke.Color = colors.Amber
	stroke.Thickness = px(1)
	stroke.Transparency = 0.14
	stroke.Parent = panel

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.Position = UDim2.fromOffset(px(6), px(3))
	label.Size = UDim2.new(1, -px(12), 0, px(14))
	label.TextColor3 = colors.Text
	label.TextSize = px(10)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "PRODUCCION"
	label.Parent = panel

	local track = Instance.new("Frame")
	track.BackgroundColor3 = colors.PanelRaised
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(px(6), px(22))
	track.Size = UDim2.new(1, -px(12), 0, px(7))
	track.Parent = panel

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = colors.Amber
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
	if billboardState ~= nil then
		billboardState.Billboard:Destroy()
	end
	self._queueBillboards[buildingId] = nil
end

function SelectionController:_handleBuildingDestroyed(payload)
	if type(payload) ~= "table" or typeof(payload.BuildingId) ~= "string" then
		return
	end

	self._barracksQueues[payload.BuildingId] = nil
	self._queueReceivedAt[payload.BuildingId] = nil
	self:_removeQueueBillboard(payload.BuildingId)

	local selectedBuilding = self._selectionStore:GetSelectedBuilding()
	if selectedBuilding ~= nil and selectedBuilding:GetAttribute("BuildingId") == payload.BuildingId then
		self:_clearBuildingSelection()
	end
end

function SelectionController:_syncSelectionVisuals()
	self._selectionStore:RemoveMissingUnits()
	self._visuals:SyncUnitSelection(self._selectionStore:GetSelectedUnits())
	self._visuals:SetSelectedBuilding(self._selectionStore:GetSelectedBuilding())
	self:_applyAssignedNexoHighlight()
end

function SelectionController:_clearUnitSelection()
	if self._selectionStore:ClearUnits() then
		self:_syncSelectionVisuals()
		self:_renderUi()
	end
end

function SelectionController:_requestUnitMove(hexPart: BasePart)
	if self._manpowerService == nil or self._playerState ~= PlayerStates.Playing then
		return
	end

	local order = self._selectionStore:GetUnitOrder()
	local unitIds = table.create(#order)
	for index = 1, #order do
		unitIds[index] = order[index]
	end

	local result = self._manpowerService:RequestMoveUnits({
		unitIds = unitIds,
		destinationHex = hexPart,
	})

	if result ~= nil and result.ok ~= true and result.reason == "NoMovableUnits" then
		self:_clearUnitSelection()
	end
end

function SelectionController:_getSelectedUnitsForPanel()
	local order = self._selectionStore:GetUnitOrder()
	local selectedUnits = self._selectionStore:GetSelectedUnits()
	local units = table.create(#order)

	for index = 1, #order do
		local unitId = order[index]
		local model = selectedUnits[unitId]
		if model ~= nil then
			units[#units + 1] = {
				UnitId = unitId,
				UnitType = model:GetAttribute("UnitType") or "InfanteriaLigera",
			}
		end
	end

	return units
end

function SelectionController:_getSelectedBuildingForPanel()
	local building = self._selectionStore:GetSelectedBuilding()
	if building == nil then
		return nil
	end

	local ownerUserId = building:GetAttribute("OwnerUserId")
	return {
		Instance = building,
		BuildingId = building:GetAttribute("BuildingId"),
		BuildingType = building:GetAttribute("BuildingType"),
		HP = building:GetAttribute("HP"),
		MaxHP = building:GetAttribute("MaxHP"),
		OwnerUserId = ownerUserId,
		CanEdit = ownerUserId == LOCAL_PLAYER.UserId,
	}
end

function SelectionController:_refreshResources()
	if self._buildService == nil then
		return
	end

	local resources = self._buildService:GetResources()
	if resources ~= nil then
		self._resources = resources
	end
end

function SelectionController:_applyAssignedNexoHighlight()
	local record = getRecordById(self._snapshot, self._assignedNexoId)
	local emphasized = self:_isNexoBuildMenuOpen()
		or (
			self._hoveredEntity ~= nil
			and self._hoveredEntity.Type == EntityTypes.Nexo
			and self._hoveredEntity.Id == self._assignedNexoId
		)
	self._visuals:SetAssignedNexo(record, getStableColorForNexo(self._assignedNexoId), emphasized)
end

function SelectionController:_applyNexoSnapshotVisuals()
	local seen = {}
	if self._snapshot.nexos ~= nil then
		for _, record in self._snapshot.nexos do
			seen[record.id] = true
			if
				record.state == NexoConfig.States.Selected
				and record.selectedByUserId ~= nil
				and record.selectedByUserId ~= LOCAL_PLAYER.UserId
			then
				self:_ensureSelectedBillboard(record)
			else
				self:_removeSelectedBillboard(record.id)
			end
		end
	end

	for nexoId in self._selectedBillboards do
		if seen[nexoId] ~= true then
			self:_removeSelectedBillboard(nexoId)
		end
	end
end

function SelectionController:_ensureSelectedBillboard(record)
	if self._selectedBillboards[record.id] ~= nil then
		return
	end

	local adornee = nil
	if record.instance ~= nil then
		adornee = if record.instance:IsA("BasePart")
			then record.instance
			else record.instance:FindFirstChildWhichIsA("BasePart", true)
	end
	if adornee == nil then
		return
	end

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
	if billboard ~= nil then
		billboard:Destroy()
	end
	self._selectedBillboards[nexoId] = nil
end

function SelectionController:_armAreaSelection()
	self._areaSelector:ArmTouch()
	self:_renderUi()
end

function SelectionController:_clearCommandSelection()
	self:_clearUnitSelection()
	self:_clearBuildingSelection()
end

function SelectionController:_getAreaRectForRender()
	if self._areaSelector:IsDragging() then
		return self._areaSelector:GetRect()
	end
	return nil
end

function SelectionController:_renderAreaIfChanged()
	local rect = self:_getAreaRectForRender()
	local signature = if rect ~= nil
		then `{math.floor(rect.Min.X)}|{math.floor(rect.Min.Y)}|{math.floor(rect.Size.X)}|{math.floor(rect.Size.Y)}`
		else "none"
	if signature == self._lastAreaSignature then
		return
	end

	self._lastAreaSignature = signature
	self:_renderUi()
end

function SelectionController:_renderUi()
	if self._root == nil then
		return
	end

	local selectedBuilding = self._selectionStore:GetSelectedBuilding()
	if selectedBuilding ~= nil and selectedBuilding.Parent == nil then
		self._selectionStore:ClearBuilding()
		self:_syncSelectionVisuals()
	end

	local units = self:_getSelectedUnitsForPanel()
	local building = self:_getSelectedBuildingForPanel()
	local buildingId = if building ~= nil then building.BuildingId else nil
	local queue = if typeof(buildingId) == "string" then self:_getQueueForDisplay(buildingId) else nil
	local canShowActionPanel = self._snapshot.phaseActive ~= true
		and not self._isBuildingMode
		and canInteractWithBuildings(self._playerState)
	local canOpenNexoBuild = self:_canOpenNexoBuildMenu()

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
			visible = self._selectedNexoId ~= nil,
			nexoId = self._selectedNexoId,
			snapshot = self._snapshot,
			localUserId = LOCAL_PLAYER.UserId,
			viewportSize = self._lastViewportSize,
			isMobile = UserInputService.TouchEnabled,
			onSelect = function()
				self:_claimSelectedNexo()
			end,
			onClose = function()
				self:_closeNexoSelectionMenu(true)
			end,
		}),
		NexoBuildMenu = React.createElement(NexoBuildMenu, {
			visible = self:_isNexoBuildMenuOpen(),
			resources = self._resources,
			viewportSize = self._lastViewportSize,
			isMobile = UserInputService.TouchEnabled,
			onClose = function()
				self:_closeNexoBuildMenu()
			end,
			onSelectBuilding = function(buildingType: string)
				self:_selectBuildingFromNexo(buildingType)
			end,
		}),
		AreaOverlay = React.createElement(SelectionAreaOverlay, {
			rect = self:_getAreaRectForRender(),
		}),
		ActionPanel = React.createElement(SelectionActionPanel, {
			visible = canShowActionPanel
				and (canOpenNexoBuild or #units > 0 or building ~= nil or self._areaSelector:IsTouchArmed()),
			units = units,
			building = building,
			queue = queue,
			canOpenNexoBuild = canOpenNexoBuild,
			areaModeArmed = self._areaSelector:IsTouchArmed(),
			viewportSize = self._lastViewportSize,
			isMobile = UserInputService.TouchEnabled,
			onArmArea = function()
				self:_armAreaSelection()
			end,
			onOpenNexoBuild = function()
				self:_openNexoBuildMenu()
			end,
			onClear = function()
				self:_clearCommandSelection()
			end,
			onDeselectUnit = function(unitId: string)
				if self._selectionStore:DeselectUnit(unitId) then
					self:_syncSelectionVisuals()
					self:_renderUi()
				end
			end,
			onMoveBuilding = function()
				self:_moveActiveBuilding()
			end,
			onDestroyBuilding = function()
				self:_destroyActiveBuilding()
			end,
			onQueueUnit = function(unitType: string)
				self:_queueSelectedUnit(unitType)
			end,
		}),
	}))
end

function SelectionController:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:_nextAsyncToken()

	for nexoId in self._selectedBillboards do
		self:_removeSelectedBillboard(nexoId)
	end
	for buildingId in self._queueBillboards do
		self:_removeQueueBillboard(buildingId)
	end

	table.clear(self._selectedBillboards)
	table.clear(self._queueBillboards)
	table.clear(self._barracksQueues)
	table.clear(self._queueReceivedAt)
	self._trove:Destroy()
end

return SelectionController
