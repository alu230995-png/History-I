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

local NexoConfig = require(Shared:WaitForChild("Constants"):WaitForChild("NexoConfig"))
local PlayerStates = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStates"))
local StateMachine = require(Shared:WaitForChild("Classes"):WaitForChild("StateMachine"))
local UITheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local WorldInput = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("WorldInput"))

local NexoBuildMenu =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("NexoBuildMenu"):WaitForChild("index"))
local NexoSelectionMenu =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("NexoSelectionMenu"):WaitForChild("index"))
local NexoTimerUI =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("NexoTimerUI"):WaitForChild("index"))

local NexoSelectionController = Knit.CreateController({
	Name = "NexoSelectionController",
})

local LOCAL_PLAYER = Players.LocalPlayer
local MAX_RAY_DISTANCE = 500
local SELECTED_BILLBOARD_SIZE = UDim2.fromOffset(46, 22)

local colors = UITheme.Colors

local NexoInteractionStates = table.freeze({
	Idle = "Idle",
	NexoHovered = "NexoHovered",
	NexoMenuOpen = "NexoMenuOpen",
	BuildPlacement = "BuildPlacement",
})

local AllowedInteractionTransitions = table.freeze({
	Idle = table.freeze({
		NexoHovered = true,
		NexoMenuOpen = true,
		BuildPlacement = true,
	}),
	NexoHovered = table.freeze({
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
		NexoHovered = true,
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

local function instanceContains(root: Instance?, child: Instance?): boolean
	if root == nil or child == nil then
		return false
	end

	return child == root or child:IsDescendantOf(root)
end

local function getStableColorForNexo(nexoId: string?): Color3
	local text = nexoId or ""
	local hash = 0

	for index = 1, #text do
		hash = (hash * 31 + string.byte(text, index)) % 100000
	end

	return ASSIGNED_HIGHLIGHT_COLORS[(hash % #ASSIGNED_HIGHLIGHT_COLORS) + 1]
end

function NexoSelectionController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._camera = Workspace.CurrentCamera
	self._nexoService = nil
	self._buildService = nil
	self._buildController = nil
	self._gameService = nil
	self._root = nil
	self._screenGui = nil
	self._snapshot = {
		phaseActive = false,
		remainingSeconds = NexoConfig.SelectionDurationSeconds,
		nexos = {},
	}
	self._resources = nil
	self._remainingSeconds = NexoConfig.SelectionDurationSeconds
	self._selectedNexoId = nil
	self._assignedNexoId = nil
	self._hoveredNexoId = nil
	self._lastTouchPosition = nil
	self._assignmentMessage = nil
	self._assignmentToken = 0
	self._selectedBillboards = {}
	self._selectionEnded = false
	self._isBuildingMode = false

	self._interactionMachine = StateMachine.new(NexoInteractionStates.Idle, AllowedInteractionTransitions)
	self._trove:Add(self._interactionMachine)

	self._highlight = Instance.new("Highlight")
	self._highlight.Name = "LocalNexoHoverHighlight"
	self._highlight.Enabled = false
	self._highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self._highlight.FillColor = Color3.fromRGB(255, 255, 255)
	self._highlight.FillTransparency = 0.82
	self._highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	self._highlight.OutlineTransparency = 0.08
	self._highlight.Parent = Workspace
	self._trove:Add(self._highlight)

	self._assignedHighlight = Instance.new("Highlight")
	self._assignedHighlight.Name = "AssignedNexoOutline"
	self._assignedHighlight.Enabled = false
	self._assignedHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self._assignedHighlight.FillTransparency = NexoConfig.AssignedHighlight.FillTransparency
	self._assignedHighlight.OutlineTransparency = NexoConfig.AssignedHighlight.OutlineTransparency
	self._assignedHighlight.Parent = Workspace
	self._trove:Add(self._assignedHighlight)

	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
	end))
end

function NexoSelectionController:KnitStart()
	self._nexoService = Knit.GetService("NexoService")
	self._buildService = Knit.GetService("BuildService")
	self._gameService = Knit.GetService("GameService")
	self._buildController = Knit.GetController("BuildController")
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
		self:_render()
	end))

	self._trove:Add(self._nexoService.NexoAssigned:Connect(function(payload)
		self:_showAssignment(payload)
	end))

	self._trove:Add(self._nexoService.NexoSelectionEnded:Connect(function(snapshotEnded)
		if snapshotEnded ~= nil then
			self:_setSnapshot(snapshotEnded)
		end

		self._selectionEnded = true
		self:_closeSelectionMenu(false)
		self:_clearHover()
		self:_render()
	end))

	self._trove:Add(self._buildService.ResourcesChanged:Connect(function(resources)
		self._resources = resources
		if self:_isNexoBuildMenuOpen() then
			self:_render()
		end
	end))

	self._trove:Add(self._gameService.PlayerStateChanged:Connect(function(_oldState: string, newState: string)
		self:_setBuildingMode(newState == PlayerStates.Building)
	end))

	local state = self._gameService:GetPlayerState()
	self:_setBuildingMode(state == PlayerStates.Building)

	self._trove:Add(RunService.RenderStepped:Connect(function()
		self:_updateHover()
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

function NexoSelectionController:_mountUi()
	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NexoSelectionGui"
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

	self:_render()
end

function NexoSelectionController:_setSnapshot(snapshot)
	self._snapshot = snapshot
	if typeof(snapshot.remainingSeconds) == "number" then
		self._remainingSeconds = snapshot.remainingSeconds
	end

	if snapshot.phaseActive == false and self._remainingSeconds <= 0 then
		self._selectionEnded = true
	end

	self:_syncAssignedNexoFromSnapshot()
	self:_applySnapshotVisuals()
	self:_applyHighlight()
	self:_applyAssignedHighlight()
	self:_render()
end

function NexoSelectionController:_syncAssignedNexoFromSnapshot()
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

function NexoSelectionController:_render()
	if self._root == nil then
		return
	end

	local selectionMenuVisible = self._selectedNexoId ~= nil
	local buildMenuVisible = self:_isNexoBuildMenuOpen()
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
		SelectionMenu = React.createElement(NexoSelectionMenu, {
			visible = selectionMenuVisible,
			nexoId = self._selectedNexoId,
			snapshot = self._snapshot,
			localUserId = LOCAL_PLAYER.UserId,
			onSelect = function()
				self:_claimSelectedNexo()
			end,
			onClose = function()
				self:_closeSelectionMenu(true)
			end,
		}),
		BuildMenu = React.createElement(NexoBuildMenu, {
			visible = buildMenuVisible,
			resources = self._resources,
			onClose = function()
				self:_closeNexoBuildMenu()
			end,
			onSelectBuilding = function(buildingType: string)
				self:_selectBuildingFromNexo(buildingType)
			end,
		}),
	}))
end

function NexoSelectionController:_handleInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		if self._selectedNexoId ~= nil then
			self:_closeSelectionMenu(true)
			return
		end

		if self:_isNexoBuildMenuOpen() then
			self:_closeNexoBuildMenu()
			return
		end
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

	if self._isBuildingMode then
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

	if pointerPosition == nil or self:_isPointerOverNexoUi(pointerPosition) then
		return
	end

	if self._snapshot.phaseActive == true then
		self:_handleSelectionPointer(pointerPosition)
	else
		self:_handleBuildMenuPointer(pointerPosition)
	end
end

function NexoSelectionController:_handleSelectionPointer(pointerPosition: Vector2)
	if self._selectedNexoId ~= nil or self._assignedNexoId ~= nil then
		return
	end

	local record = self:_getNexoAtPointer(pointerPosition)
	if record == nil or record.state ~= NexoConfig.States.Available then
		return
	end

	self:_openSelectionMenu(record.id)
end

function NexoSelectionController:_handleBuildMenuPointer(pointerPosition: Vector2)
	if not self:_canOpenNexoBuildMenu() then
		return
	end

	local record = self:_getNexoAtPointer(pointerPosition)
	if record == nil or record.id ~= self._assignedNexoId then
		return
	end

	self:_openNexoBuildMenu()
end

function NexoSelectionController:_openSelectionMenu(nexoId: string)
	if self._nexoService == nil then
		return
	end

	self._selectedNexoId = nexoId
	self:_render()

	local result = self._nexoService:PreviewNexo(nexoId)
	if result ~= nil and result.ok ~= true and result.reason ~= "Taken" then
		self._selectedNexoId = nil
		self:_render()
		return
	end
end

function NexoSelectionController:_closeSelectionMenu(release: boolean)
	local nexoId = self._selectedNexoId
	self._selectedNexoId = nil

	if release and nexoId ~= nil and self._nexoService ~= nil then
		self._nexoService:ReleaseNexo(nexoId)
	end

	self:_render()
end

function NexoSelectionController:_claimSelectedNexo()
	if self._selectedNexoId == nil or self._nexoService == nil then
		return
	end

	local result = self._nexoService:ClaimNexo(self._selectedNexoId)
	if result ~= nil and result.ok == true then
		self:_closeSelectionMenu(false)
	end
end

function NexoSelectionController:_openNexoBuildMenu()
	if not self:_canOpenNexoBuildMenu() then
		return
	end

	self:_refreshResources()
	self:_setInteractionState(NexoInteractionStates.NexoMenuOpen, {
		NexoId = self._assignedNexoId,
	})
	self:_render()
end

function NexoSelectionController:_closeNexoBuildMenu()
	if not self:_isNexoBuildMenuOpen() then
		return
	end

	self:_setInteractionState(NexoInteractionStates.Idle)
	self:_render()
end

function NexoSelectionController:_selectBuildingFromNexo(buildingType: string)
	self:_setInteractionState(NexoInteractionStates.BuildPlacement, {
		NexoId = self._assignedNexoId,
		BuildingType = buildingType,
	})
	self:_render()

	if self._buildController ~= nil then
		self._buildController:SetSelectedBuildingType(buildingType)
	end
end

function NexoSelectionController:_showAssignment(payload)
	if payload ~= nil and typeof(payload.nexoId) == "string" then
		self._assignedNexoId = payload.nexoId
		self:_applyAssignedHighlight()
	end

	local displayName = if payload ~= nil and typeof(payload.displayName) == "string"
		then payload.displayName
		else "NEXO"
	self._assignmentToken += 1
	local token = self._assignmentToken
	self._assignmentMessage = `SE TE ASIGNO EL NEXO {string.upper(displayName)}`
	self:_render()

	task.delay(NexoConfig.AssignmentMessageSeconds, function()
		if self._destroyed or self._assignmentToken ~= token then
			return
		end

		self._assignmentMessage = nil
		self:_render()
	end)
end

function NexoSelectionController:_setInteractionState(state: string, context: any?)
	if self._interactionMachine:GetState() == state then
		return
	end

	self._interactionMachine:TransitionTo(state, context)
	self:_applyAssignedHighlight()
end

function NexoSelectionController:_isNexoBuildMenuOpen(): boolean
	return self._interactionMachine:GetState() == NexoInteractionStates.NexoMenuOpen
end

function NexoSelectionController:_canOpenNexoBuildMenu(): boolean
	return self._selectionEnded
		and self._snapshot.phaseActive ~= true
		and self._assignedNexoId ~= nil
		and not self._isBuildingMode
end

function NexoSelectionController:_setBuildingMode(isBuildingMode: boolean)
	if self._isBuildingMode == isBuildingMode then
		return
	end

	self._isBuildingMode = isBuildingMode
	if isBuildingMode then
		self:_closeNexoBuildMenu()
		self:_setInteractionState(NexoInteractionStates.BuildPlacement)
	else
		self:_setInteractionState(NexoInteractionStates.Idle)
	end
end

function NexoSelectionController:_refreshResources()
	if self._buildService == nil then
		return
	end

	local resources = self._buildService:GetResources()
	if resources ~= nil then
		self._resources = resources
	end
end

function NexoSelectionController:_getPointerPosition(): Vector2?
	if self._lastTouchPosition ~= nil then
		return self._lastTouchPosition
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	if mouseLocation.X >= 0 and mouseLocation.Y >= 0 then
		return mouseLocation
	end

	return nil
end

function NexoSelectionController:_isPointerOverNexoUi(pointerPosition: Vector2): boolean
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		return false
	end

	return WorldInput.IsPointerBlocked(playerGui, pointerPosition)
end

function NexoSelectionController:_isPointerOverNexoBuildPanel(pointerPosition: Vector2): boolean
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		return false
	end

	for _, guiObject in playerGui:GetGuiObjectsAtPosition(pointerPosition.X, pointerPosition.Y) do
		local screenGui = guiObject:FindFirstAncestorOfClass("ScreenGui")
		if screenGui == nil or screenGui.Name ~= "NexoSelectionGui" then
			continue
		end

		if guiObject.Name == "NexoBuildPanel" or guiObject:FindFirstAncestor("NexoBuildPanel") ~= nil then
			return true
		end
	end

	return false
end

function NexoSelectionController:_getNexoAtPointer(pointerPosition: Vector2)
	if self._camera == nil or self._snapshot.nexos == nil then
		return nil
	end

	local includeInstances = {}
	for _, record in self._snapshot.nexos do
		if record.instance ~= nil then
			table.insert(includeInstances, record.instance)
		end

		if record.hexPart ~= nil then
			table.insert(includeInstances, record.hexPart)
		end
	end

	if #includeInstances <= 0 then
		return nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = includeInstances

	local ray = self._camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE, raycastParams)
	if result == nil then
		return nil
	end

	for _, record in self._snapshot.nexos do
		if instanceContains(record.instance, result.Instance) or instanceContains(record.hexPart, result.Instance) then
			return record
		end
	end

	return nil
end

function NexoSelectionController:_updateHover()
	if self._destroyed or self._isBuildingMode or self:_isNexoBuildMenuOpen() then
		self:_clearHover()
		return
	end

	local pointerPosition = self:_getPointerPosition()
	if pointerPosition == nil or self:_isPointerOverNexoUi(pointerPosition) then
		self:_clearHover()
		return
	end

	if self._snapshot.phaseActive == true then
		if self._assignedNexoId ~= nil or self._selectedNexoId ~= nil then
			self:_clearHover()
			return
		end

		local record = self:_getNexoAtPointer(pointerPosition)
		local nextHoveredId = if record ~= nil then record.id else nil
		if nextHoveredId ~= self._hoveredNexoId then
			self._hoveredNexoId = nextHoveredId
			self:_applyHighlight()
		end

		return
	end

	if not self:_canOpenNexoBuildMenu() then
		self:_clearHover()
		return
	end

	local record = self:_getNexoAtPointer(pointerPosition)
	local isHoveringAssigned = record ~= nil and record.id == self._assignedNexoId
	self:_setInteractionState(
		if isHoveringAssigned then NexoInteractionStates.NexoHovered else NexoInteractionStates.Idle
	)
end

function NexoSelectionController:_clearHover()
	if self._hoveredNexoId == nil and not self._highlight.Enabled then
		return
	end

	self._hoveredNexoId = nil
	self:_applyHighlight()
end

function NexoSelectionController:_applyHighlight()
	local record = getRecordById(self._snapshot, self._hoveredNexoId)
	if record == nil or record.state == NexoConfig.States.Taken then
		self._highlight.Adornee = nil
		self._highlight.Enabled = false
		return
	end

	self._highlight.Adornee = record.instance
	self._highlight.Enabled = record.instance ~= nil

	if record.state == NexoConfig.States.Selected and record.selectedByUserId ~= LOCAL_PLAYER.UserId then
		self._highlight.FillColor = colors.Amber
		self._highlight.OutlineColor = colors.Amber
		self._highlight.FillTransparency = 0.9
		self._highlight.OutlineTransparency = 0.25
	else
		self._highlight.FillColor = Color3.fromRGB(255, 255, 255)
		self._highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		self._highlight.FillTransparency = 0.82
		self._highlight.OutlineTransparency = 0.08
	end
end

function NexoSelectionController:_applyAssignedHighlight()
	local record = getRecordById(self._snapshot, self._assignedNexoId)
	if record == nil or record.instance == nil then
		self._assignedHighlight.Adornee = nil
		self._assignedHighlight.Enabled = false
		return
	end

	local color = getStableColorForNexo(record.id)
	local state = self._interactionMachine:GetState()
	local fillTransparency = if state == NexoInteractionStates.NexoHovered
			or state == NexoInteractionStates.NexoMenuOpen
		then NexoConfig.AssignedHighlight.HoverFillTransparency
		else NexoConfig.AssignedHighlight.FillTransparency

	self._assignedHighlight.Adornee = record.instance
	self._assignedHighlight.Enabled = true
	self._assignedHighlight.FillColor = color
	self._assignedHighlight.OutlineColor = color
	self._assignedHighlight.FillTransparency = fillTransparency
	self._assignedHighlight.OutlineTransparency = NexoConfig.AssignedHighlight.OutlineTransparency
end

function NexoSelectionController:_applySnapshotVisuals()
	local seen = {}

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

	for nexoId in self._selectedBillboards do
		if seen[nexoId] ~= true then
			self:_removeSelectedBillboard(nexoId)
		end
	end
end

function NexoSelectionController:_ensureSelectedBillboard(record)
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

function NexoSelectionController:_removeSelectedBillboard(nexoId: string)
	local billboard = self._selectedBillboards[nexoId]
	if billboard ~= nil then
		billboard:Destroy()
	end

	self._selectedBillboards[nexoId] = nil
end

function NexoSelectionController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._highlight:Destroy()
	self._assignedHighlight:Destroy()

	for nexoId in self._selectedBillboards do
		self:_removeSelectedBillboard(nexoId)
	end

	self._trove:Destroy()
end

return NexoSelectionController
