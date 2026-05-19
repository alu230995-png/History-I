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
local PlayerStates = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStates"))
local StateMachine = require(Shared:WaitForChild("Classes"):WaitForChild("StateMachine"))

local BuildingMenu = require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("BuildingMenu"))

local BuildingInteractionController = Knit.CreateController({
	Name = "BuildingInteractionController",
})

local LOCAL_PLAYER = Players.LocalPlayer
local MAX_RAY_DISTANCE = 500

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
	self._gameService = nil
	self._isBuildingMode = false
	self._root = nil
	self._screenGui = nil
	self._hoveredBuilding = nil
	self._selectedBuilding = nil
	self._lastTouchPosition = nil

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
	self._gameService = Knit.GetService("GameService")
	self._placedFolder = Workspace:WaitForChild(BuildingConfig.PlacedFolderName, 10)
	self:_mountUi()

	self._trove:Add(self._gameService.PlayerStateChanged:Connect(function(_oldState: string, newState: string)
		self:_setBuildingMode(newState == PlayerStates.Building)
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

	for _, guiObject in playerGui:GetGuiObjectsAtPosition(pointerPosition.X, pointerPosition.Y) do
		local screenGui = guiObject:FindFirstAncestorOfClass("ScreenGui")
		if screenGui ~= nil and (screenGui.Name == "BuildingMenuGui" or screenGui.Name == "BuildControlsGui") then
			return true
		end
	end

	return false
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

	if building:GetAttribute("Interactable") == true then
		self._machine:TransitionTo(InteractionStates.MenuOpen, {
			Building = building,
		})
	else
		self._machine:TransitionTo(InteractionStates.Selected, {
			Building = building,
		})
	end

	self:_applyHighlight()
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
end

function BuildingInteractionController:_getHighlightedBuilding(): Model?
	if self._selectedBuilding ~= nil then
		return self._selectedBuilding
	end

	return self._hoveredBuilding
end

function BuildingInteractionController:_applyHighlight()
	local highlightedBuilding = self:_getHighlightedBuilding()
	self._highlight.Adornee = highlightedBuilding
	self._highlight.Enabled = highlightedBuilding ~= nil
end

function BuildingInteractionController:_renderMenu()
	if self._root == nil then
		return
	end

	local state = self._machine:GetState()
	local selectedBuilding = self._selectedBuilding
	local visible = state == InteractionStates.MenuOpen and selectedBuilding ~= nil
	local buildingType = if selectedBuilding ~= nil then selectedBuilding:GetAttribute("BuildingType") else nil
	local hp = if selectedBuilding ~= nil then selectedBuilding:GetAttribute("HP") else nil
	local maxHp = if selectedBuilding ~= nil then selectedBuilding:GetAttribute("MaxHP") else nil

	self._root:render(React.createElement(BuildingMenu, {
		visible = visible,
		buildingType = buildingType,
		hp = hp,
		maxHp = maxHp,
		onClose = function()
			self._machine:TransitionTo(InteractionStates.Selected, {
				Building = self._selectedBuilding,
			})
			self:_renderMenu()
		end,
	}))
end

function BuildingInteractionController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
end

return BuildingInteractionController
