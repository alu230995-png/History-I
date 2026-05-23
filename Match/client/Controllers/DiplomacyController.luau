local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))
local Trove = require(Packages:WaitForChild("Trove"))

local DiplomacyConfig = require(Shared:WaitForChild("Constants"):WaitForChild("DiplomacyConfig"))
local GameConstants = require(Shared:WaitForChild("Constants"):WaitForChild("GameConstants"))
local PlayerStates = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStates"))

local DiplomacyPanel =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("DiplomacyPanel"):WaitForChild("index"))
local WorldInput = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("WorldInput"))

local DiplomacyController = Knit.CreateController({
	Name = "DiplomacyController",
})

local LOCAL_PLAYER = Players.LocalPlayer

local function canUseDiplomacy(playerState: string?): boolean
	return playerState == PlayerStates.Playing
end

local function findControlRig(instance: Instance?, controlRigFolder: Instance?): Model?
	local current = instance
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("OwnerUserId") ~= nil then
			if controlRigFolder == nil or current:IsDescendantOf(controlRigFolder) then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

function DiplomacyController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._camera = Workspace.CurrentCamera
	self._controlRigFolder = nil
	self._diplomacyService = nil
	self._gameService = nil
	self._menuCoordinator = nil
	self._playerState = nil
	self._snapshot = nil
	self._selectedPlayer = nil
	self._root = nil
	self._screenGui = nil
	self._raycastParams = RaycastParams.new()
	self._raycastParams.FilterType = Enum.RaycastFilterType.Include
	self._raycastInclude = {}

	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
	end))
end

function DiplomacyController:KnitStart()
	self._diplomacyService = Knit.GetService("DiplomacyService")
	self._gameService = Knit.GetService("GameService")
	self._menuCoordinator = Knit.GetController("MenuCoordinatorController")
	self._controlRigFolder = Workspace:WaitForChild(GameConstants.ControlRig.FolderName, 10)
	self:_refreshRaycastFilter()
	self:_mountUi()

	self._snapshot = self._diplomacyService:GetSnapshot()
	self:_render()

	self._trove:Add(self._diplomacyService.DiplomacySnapshotChanged:Connect(function(snapshot)
		self._snapshot = snapshot
		self:_render()
	end))
	self._trove:Add(self._gameService.PlayerStateChanged:Connect(function(_oldState: string, newState: string)
		self._playerState = newState
		if not canUseDiplomacy(newState) then
			self:_clearSelection()
		end
	end))
	self._trove:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		self:_handleInputBegan(input, gameProcessedEvent)
	end))

	local state = self._gameService:GetPlayerState()
	self._playerState = state
end

function DiplomacyController:_mountUi()
	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DiplomacyGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 66
	screenGui.Parent = playerGui
	self._screenGui = screenGui
	self._trove:Add(screenGui)

	local root = ReactRoblox.createRoot(screenGui)
	self._root = root
	self._trove:Add(function()
		root:unmount()
	end)
end

function DiplomacyController:_refreshRaycastFilter()
	table.clear(self._raycastInclude)
	if self._controlRigFolder ~= nil then
		table.insert(self._raycastInclude, self._controlRigFolder)
	end
	self._raycastParams.FilterDescendantsInstances = self._raycastInclude
end

function DiplomacyController:_handleInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		self:_clearSelection()
		return
	end

	if not canUseDiplomacy(self._playerState) then
		return
	end

	local pointerPosition = nil
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		pointerPosition = UserInputService:GetMouseLocation()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		pointerPosition = Vector2.new(input.Position.X, input.Position.Y)
	else
		return
	end

	if pointerPosition == nil or self:_isPointerOverUi(pointerPosition) then
		return
	end

	local player = self:_getPlayerAtPointer(pointerPosition)
	if player == nil then
		self:_clearSelection()
		return
	end

	self._selectedPlayer = player
	self._menuCoordinator:RequestOpen(DiplomacyConfig.MenuIds.Diplomacy, function()
		self:_clearSelection()
	end)
	self:_render()
end

function DiplomacyController:_getPlayerAtPointer(pointerPosition: Vector2): Player?
	if self._camera == nil or self._controlRigFolder == nil then
		return nil
	end

	local ray = self._camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * DiplomacyConfig.TargetRayDistance, self._raycastParams)
	local rig = if result ~= nil then findControlRig(result.Instance, self._controlRigFolder) else nil
	local ownerUserId = if rig ~= nil then rig:GetAttribute("OwnerUserId") else nil
	if typeof(ownerUserId) ~= "number" or ownerUserId == LOCAL_PLAYER.UserId then
		return nil
	end

	return Players:GetPlayerByUserId(ownerUserId)
end

function DiplomacyController:_isPointerOverUi(pointerPosition: Vector2): boolean
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	return if playerGui ~= nil and playerGui:IsA("PlayerGui")
		then WorldInput.IsPointerBlocked(playerGui, pointerPosition)
		else false
end

function DiplomacyController:_isAllied(userId: number): boolean
	local localAlliance = self:_getAllianceForUserId(LOCAL_PLAYER.UserId)
	local targetAlliance = self:_getAllianceForUserId(userId)
	return localAlliance ~= nil and localAlliance == targetAlliance
end

function DiplomacyController:_getAllianceForUserId(userId: number)
	if self._snapshot == nil or type(self._snapshot.alliances) ~= "table" then
		return nil
	end

	for _, alliance in self._snapshot.alliances do
		if type(alliance.members) ~= "table" then
			continue
		end
		for _, memberUserId in alliance.members do
			if memberUserId == userId then
				return alliance
			end
		end
	end

	return nil
end

function DiplomacyController:_isAllianceFullWith(userId: number): boolean
	local members = {
		[LOCAL_PLAYER.UserId] = true,
		[userId] = true,
	}

	for _, alliance in { self:_getAllianceForUserId(LOCAL_PLAYER.UserId), self:_getAllianceForUserId(userId) } do
		if alliance ~= nil and type(alliance.members) == "table" then
			for _, memberUserId in alliance.members do
				members[memberUserId] = true
			end
		end
	end

	local count = 0
	for _ in members do
		count += 1
	end
	local maxMembers = if self._snapshot ~= nil and typeof(self._snapshot.maxMembers) == "number"
		then self._snapshot.maxMembers
		else DiplomacyConfig.MaxAllianceMembers
	return count > maxMembers
end

function DiplomacyController:_getActionState()
	local selected = self._selectedPlayer
	if selected == nil then
		return "Alliance", "ALIANZA", false
	end

	if self:_isAllied(selected.UserId) then
		return "Break", "ROMPER", true
	end

	if self:_isAllianceFullWith(selected.UserId) then
		return "Alliance", "LLENO", false
	end

	return "Alliance", "ALIANZA", true
end

function DiplomacyController:_requestAction()
	local selected = self._selectedPlayer
	if selected == nil then
		return
	end

	if self:_isAllied(selected.UserId) then
		self._diplomacyService:RequestBreakAlliance(selected.UserId)
	else
		self._diplomacyService:RequestAlliance(selected.UserId)
	end
	self:_render()
end

function DiplomacyController:_respondInvite(inviteId: string, accepted: boolean)
	self._diplomacyService:RespondAlliance(inviteId, accepted)
end

function DiplomacyController:_clearSelection()
	self._selectedPlayer = nil
	if self._menuCoordinator ~= nil then
		self._menuCoordinator:Close(DiplomacyConfig.MenuIds.Diplomacy)
	end
	self:_render()
end

function DiplomacyController:_getPlayerName(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	return if player ~= nil then player.DisplayName else tostring(userId)
end

function DiplomacyController:_render()
	if self._root == nil then
		return
	end

	local actionKind, actionLabel, actionEnabled = self:_getActionState()
	local selected = if self._selectedPlayer ~= nil
		then {
			userId = self._selectedPlayer.UserId,
			name = self._selectedPlayer.DisplayName,
		}
		else nil
	local invites = if self._snapshot ~= nil and type(self._snapshot.invites) == "table"
		then self._snapshot.invites
		else {}

	self._root:render(React.createElement(DiplomacyPanel, {
		selectedPlayer = selected,
		actionKind = actionKind,
		actionLabel = actionLabel,
		actionEnabled = actionEnabled,
		invites = invites,
		getPlayerName = function(userId: number)
			return self:_getPlayerName(userId)
		end,
		onAction = function()
			self:_requestAction()
		end,
		onClose = function()
			self:_clearSelection()
		end,
		onAcceptInvite = function(inviteId: string)
			self:_respondInvite(inviteId, true)
		end,
		onRejectInvite = function(inviteId: string)
			self:_respondInvite(inviteId, false)
		end,
	}))
end

function DiplomacyController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
	table.clear(self._raycastInclude)
end

return DiplomacyController
