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
local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local PlayerStates = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStates"))
local StateMachine = require(Shared:WaitForChild("Classes"):WaitForChild("StateMachine"))

local BuildingMenu =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("BuildingMenu"):WaitForChild("index"))
local UITheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local WorldInput = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("WorldInput"))

local BuildingInteractionController = Knit.CreateController({
	Name = "BuildingInteractionController",
})

local LOCAL_PLAYER = Players.LocalPlayer
local MAX_RAY_DISTANCE = 500
local px = UITheme.sp

local InteractionStates = table.freeze({
	Idle = "Idle",
	Hovering = "Hovering",
	Selected = "Selected",
	MenuOpen = "MenuOpen",
})

local AllowedTransitions = table.freeze({
	Idle = table.freeze({
		Hovering = true,
		Selected = true,
		MenuOpen = true,
	}),
	Hovering = table.freeze({
		Idle = true,
		Selected = true,
		MenuOpen = true,
	}),
	Selected = table.freeze({
		Idle = true,
		Hovering = true,
		MenuOpen = true,
	}),
	MenuOpen = table.freeze({
		Idle = true,
		Hovering = true,
		Selected = true,
	}),
})

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

function BuildingInteractionController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._camera = Workspace.CurrentCamera
	self._placedFolder = nil
	self._buildService = nil
	self._buildController = nil
	self._gameService = nil
	self._manpowerService = nil
	self._isBuildingMode = false
	self._root = nil
	self._screenGui = nil
	self._hoveredBuilding = nil
	self._selectedBuilding = nil
	self._lastTouchPosition = nil
	self._barracksQueues = {}
	self._queueReceivedAt = {}
	self._queueBillboards = {}

	self._machine = StateMachine.new(InteractionStates.Idle, AllowedTransitions)
	self._trove:Add(self._machine)

	self._highlight = Instance.new("Highlight")
	self._highlight.Name = "LocalBuildingHighlight"
	self._highlight.Enabled = false
	self._highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self._highlight.FillColor = Color3.fromRGB(255, 255, 255)
	self._highlight.FillTransparency = 0.8
	self._highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	self._highlight.OutlineTransparency = 0.05
	self._highlight.Parent = Workspace
	self._trove:Add(self._highlight)

	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
	end))
end

function BuildingInteractionController:KnitStart()
	self._buildService = Knit.GetService("BuildService")
	self._buildController = Knit.GetController("BuildController")
	self._gameService = Knit.GetService("GameService")
	self._manpowerService = Knit.GetService("ManpowerService")
	self._placedFolder = Workspace:WaitForChild(BuildingConfig.PlacedFolderName, 10)
	self:_mountUi()

	self._trove:Add(self._gameService.PlayerStateChanged:Connect(function(_oldState: string, newState: string)
		self:_setBuildingMode(newState == PlayerStates.Building)
	end))
	self._trove:Add(self._manpowerService.QueueChanged:Connect(function(queue)
		self:_setQueueSnapshot(queue)
	end))
	self._trove:Add(self._buildService.BuildingDestroyed:Connect(function(payload)
		self:_handleBuildingDestroyed(payload)
	end))

	local state = self._gameService:GetPlayerState()
	self:_setBuildingMode(state == PlayerStates.Building)

	self._trove:Add(RunService.RenderStepped:Connect(function()
		self:_updateHover()
	end))

	self._trove:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if self._isBuildingMode then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pointerPosition = UserInputService:GetMouseLocation()
			self:_activateAtPointer(pointerPosition)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local pointerPosition = Vector2.new(input.Position.X, input.Position.Y)
			self._lastTouchPosition = pointerPosition
			self:_activateAtPointer(pointerPosition)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			self:_clearSelection()
		end
	end))

	self._trove:Add(UserInputService.InputChanged:Connect(function(input: InputObject, _gameProcessedEvent: boolean)
		if self._isBuildingMode then
			return
		end

		if input.UserInputType == Enum.UserInputType.Touch then
			self._lastTouchPosition = Vector2.new(input.Position.X, input.Position.Y)
		end
	end))

	self._trove:Add(UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessedEvent: boolean)
		if self._isBuildingMode then
			return
		end

		if input.UserInputType == Enum.UserInputType.Touch then
			self._lastTouchPosition = nil
		end
	end))

	task.spawn(function()
		while not self._destroyed do
			self:_updateQueueBillboards()
			self:_renderMenu()
			task.wait(0.25)
		end
	end)
end

function BuildingInteractionController:_setBuildingMode(isBuildingMode: boolean)
	if self._isBuildingMode == isBuildingMode then
		return
	end

	self._isBuildingMode = isBuildingMode
	if isBuildingMode then
		self._hoveredBuilding = nil
		self:_clearSelection()
	end
end

function BuildingInteractionController:_mountUi()
	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BuildingMenuGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 35
	screenGui.Parent = playerGui
	self._screenGui = screenGui

	local root = ReactRoblox.createRoot(screenGui)
	self._root = root
	self._trove:Add(function()
		root:unmount()
	end)
	self._trove:Add(screenGui)

	self:_renderMenu()
end

function BuildingInteractionController:_isPointerOverInteractionUi(pointerPosition: Vector2): boolean
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		return false
	end

	return WorldInput.IsPointerBlocked(playerGui, pointerPosition)
end

function BuildingInteractionController:_getPointerPosition(): Vector2?
	if self._lastTouchPosition ~= nil then
		return self._lastTouchPosition
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	if mouseLocation.X >= 0 and mouseLocation.Y >= 0 then
		return mouseLocation
	end

	return nil
end

function BuildingInteractionController:_getBuildingAtPointer(pointerPosition: Vector2): Model?
	if self._camera == nil or self._placedFolder == nil then
		return nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { self._placedFolder }

	local ray = self._camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE, raycastParams)
	if result == nil then
		return nil
	end

	return findBuildingModel(result.Instance, self._placedFolder)
end

function BuildingInteractionController:_updateHover()
	if self._destroyed then
		return
	end

	if self._isBuildingMode then
		return
	end

	local pointerPosition = self:_getPointerPosition()
	if pointerPosition == nil or self:_isPointerOverInteractionUi(pointerPosition) then
		return
	end

	local hoveredBuilding = self:_getBuildingAtPointer(pointerPosition)
	if hoveredBuilding ~= self._hoveredBuilding then
		self._hoveredBuilding = hoveredBuilding
		self:_refreshState()
	end
end

function BuildingInteractionController:_activateAtPointer(pointerPosition: Vector2)
	if self._isBuildingMode then
		return
	end

	if self:_isPointerOverInteractionUi(pointerPosition) then
		return
	end

	local building = self:_getBuildingAtPointer(pointerPosition)
	if building == nil then
		self:_clearSelection()
		return
	end

	self._selectedBuilding = building
	self._machine:TransitionTo(InteractionStates.MenuOpen, {
		Building = building,
	})

	self:_applyHighlight()
	self:_refreshSelectedBarracksQueue()
	self:_renderMenu()
end

function BuildingInteractionController:_clearSelection()
	self._selectedBuilding = nil
	self:_refreshState()
	self:_renderMenu()
end

function BuildingInteractionController:_refreshState()
	if self._selectedBuilding ~= nil then
		if self._machine:GetState() ~= InteractionStates.MenuOpen then
			self._machine:TransitionTo(InteractionStates.Selected, {
				Building = self._selectedBuilding,
			})
		end
	elseif self._hoveredBuilding ~= nil then
		self._machine:TransitionTo(InteractionStates.Hovering, {
			Building = self._hoveredBuilding,
		})
	else
		self._machine:TransitionTo(InteractionStates.Idle)
	end

	self:_applyHighlight()
	self:_renderMenu()
end

function BuildingInteractionController:_getHighlightedBuilding(): Model?
	if self._selectedBuilding ~= nil then
		return self._selectedBuilding
	end

	return self._hoveredBuilding
end

function BuildingInteractionController:_getActiveBuilding(): Model?
	return self._selectedBuilding
end

function BuildingInteractionController:_applyHighlight()
	local highlightedBuilding = self:_getHighlightedBuilding()
	self._highlight.Adornee = highlightedBuilding
	self._highlight.Enabled = highlightedBuilding ~= nil
end

function BuildingInteractionController:_destroyActiveBuilding()
	local building = self:_getActiveBuilding()
	if building == nil or self._buildService == nil then
		return
	end

	local buildingId = building:GetAttribute("BuildingId")
	if typeof(buildingId) ~= "string" then
		return
	end

	local result = self._buildService:RequestDestroy({
		buildingId = buildingId,
	})

	if result ~= nil and result.ok == true then
		self._hoveredBuilding = nil
		self:_clearSelection()
	end
end

function BuildingInteractionController:_moveActiveBuilding()
	local building = self:_getActiveBuilding()
	if building == nil or self._buildController == nil then
		return
	end

	local result = self._buildController:StartMovingBuilding(building)
	if result == nil or result.ok == true then
		self._hoveredBuilding = nil
		self:_clearSelection()
	end
end

function BuildingInteractionController:_renderMenu()
	if self._root == nil then
		return
	end

	local state = self._machine:GetState()
	local activeBuilding = self:_getActiveBuilding()
	local visible = activeBuilding ~= nil and (state == InteractionStates.MenuOpen or state == InteractionStates.Selected)
	local buildingType = if activeBuilding ~= nil then activeBuilding:GetAttribute("BuildingType") else nil
	local hp = if activeBuilding ~= nil then activeBuilding:GetAttribute("HP") else nil
	local maxHp = if activeBuilding ~= nil then activeBuilding:GetAttribute("MaxHP") else nil
	local ownerUserId = if activeBuilding ~= nil then activeBuilding:GetAttribute("OwnerUserId") else nil
	local canEdit = ownerUserId == LOCAL_PLAYER.UserId
	local buildingId = if activeBuilding ~= nil then activeBuilding:GetAttribute("BuildingId") else nil
	local queue = if typeof(buildingId) == "string" then self:_getQueueForDisplay(buildingId) else nil

	self._root:render(React.createElement(BuildingMenu, {
		visible = visible,
		buildingType = buildingType,
		hp = hp,
		maxHp = maxHp,
		canEdit = canEdit,
		queue = queue,
		onMove = function()
			self:_moveActiveBuilding()
		end,
		onDestroy = function()
			self:_destroyActiveBuilding()
		end,
		onClose = function()
			self:_clearSelection()
			self:_renderMenu()
		end,
		onQueueUnit = function(unitType: string)
			self:_queueSelectedUnit(unitType)
		end,
	}))
end

function BuildingInteractionController:_refreshSelectedBarracksQueue()
	local building = self._selectedBuilding
	if building == nil or self._manpowerService == nil then
		return
	end

	if building:GetAttribute("BuildingType") ~= "Cuartel" or building:GetAttribute("OwnerUserId") ~= LOCAL_PLAYER.UserId then
		return
	end

	local buildingId = building:GetAttribute("BuildingId")
	if typeof(buildingId) ~= "string" then
		return
	end

	local result = self._manpowerService:GetBarracksQueue(buildingId)
	if result ~= nil and result.ok == true and result.queue ~= nil then
		self:_setQueueSnapshot(result.queue)
	end
end

function BuildingInteractionController:_queueSelectedUnit(unitType: string)
	local building = self._selectedBuilding
	if building == nil or self._manpowerService == nil then
		return
	end

	local buildingId = building:GetAttribute("BuildingId")
	if typeof(buildingId) ~= "string" then
		return
	end

	local result = self._manpowerService:RequestQueueUnit({
		buildingId = buildingId,
		unitType = unitType,
	})
	if result ~= nil and result.queue ~= nil then
		self:_setQueueSnapshot(result.queue)
	end
end

function BuildingInteractionController:_setQueueSnapshot(queue)
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
	self:_renderMenu()
end

function BuildingInteractionController:_getQueueForDisplay(buildingId: string)
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

function BuildingInteractionController:_ensureQueueBillboard(buildingId: string)
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

	self._queueBillboards[buildingId] = {
		Billboard = billboard,
		Label = label,
		Fill = fill,
	}
end

function BuildingInteractionController:_updateQueueBillboards()
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

function BuildingInteractionController:_removeQueueBillboard(buildingId: string)
	local billboardState = self._queueBillboards[buildingId]
	if billboardState ~= nil then
		billboardState.Billboard:Destroy()
	end

	self._queueBillboards[buildingId] = nil
end

function BuildingInteractionController:_handleBuildingDestroyed(payload)
	if type(payload) ~= "table" or typeof(payload.BuildingId) ~= "string" then
		return
	end

	self._barracksQueues[payload.BuildingId] = nil
	self._queueReceivedAt[payload.BuildingId] = nil
	self:_removeQueueBillboard(payload.BuildingId)

	if self._selectedBuilding ~= nil and self._selectedBuilding:GetAttribute("BuildingId") == payload.BuildingId then
		self:_clearSelection()
	end
end

function BuildingInteractionController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	for buildingId in self._queueBillboards do
		self:_removeQueueBillboard(buildingId)
	end
	self._trove:Destroy()
end

return BuildingInteractionController
