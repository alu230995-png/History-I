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
local UITheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local NexoSelectionMenu =
	require(script.Parent.Parent:WaitForChild("Menus"):WaitForChild("NexoSelectionMenu"):WaitForChild("index"))
local NexoTimerUI = require(script.Parent.Parent:WaitForChild("UIs"):WaitForChild("NexoTimerUI"):WaitForChild("index"))

local NexoSelectionController = Knit.CreateController({
	Name = "NexoSelectionController",
})

local LOCAL_PLAYER = Players.LocalPlayer
local MAX_RAY_DISTANCE = 500
local SELECTED_BILLBOARD_SIZE = UDim2.fromOffset(46, 22)

local colors = UITheme.Colors

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

local function getNexoParts(instance: Instance?): { BasePart }
	local parts = {}
	if instance == nil then
		return parts
	end

	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end

	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function guiObjectBlocksWorldInput(guiObject: GuiObject): boolean
	if guiObject:IsA("GuiButton") or guiObject:IsA("TextBox") then
		return true
	end

	if guiObject.Active then
		return true
	end

	return guiObject.BackgroundTransparency < 1
end

function NexoSelectionController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._camera = Workspace.CurrentCamera
	self._nexoService = nil
	self._root = nil
	self._screenGui = nil
	self._snapshot = {
		phaseActive = false,
		remainingSeconds = NexoConfig.SelectionDurationSeconds,
		nexos = {},
	}
	self._remainingSeconds = NexoConfig.SelectionDurationSeconds
	self._selectedNexoId = nil
	self._hoveredNexoId = nil
	self._lastTouchPosition = nil
	self._assignmentMessage = nil
	self._assignmentToken = 0
	self._selectedBillboards = {}
	self._originalVisuals = {}

	self._highlight = Instance.new("Highlight")
	self._highlight.Name = "LocalNexoHighlight"
	self._highlight.Enabled = false
	self._highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self._highlight.FillColor = Color3.fromRGB(255, 255, 255)
	self._highlight.FillTransparency = 0.82
	self._highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	self._highlight.OutlineTransparency = 0.08
	self._highlight.Parent = Workspace
	self._trove:Add(self._highlight)

	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
	end))
end

function NexoSelectionController:KnitStart()
	self._nexoService = Knit.GetService("NexoService")
	self:_mountUi()

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

	self._trove:Add(self._nexoService.NexoSelectionEnded:Connect(function()
		self:_closeMenu(false)
		self:_clearHover()
		self:_render()
	end))

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

	local selectedRecord = getRecordById(snapshot, self._selectedNexoId)
	if selectedRecord ~= nil and selectedRecord.state == NexoConfig.States.Taken then
		self._highlight.Enabled = false
	end

	self:_applySnapshotVisuals()
	self:_applyHighlight()
	self:_render()
end

function NexoSelectionController:_render()
	if self._root == nil then
		return
	end

	local menuVisible = self._selectedNexoId ~= nil
	self._root:render(React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Timer = React.createElement(NexoTimerUI, {
			visible = self._snapshot.phaseActive == true,
			segundosRestantes = self._remainingSeconds,
			assignmentMessage = self._assignmentMessage,
		}),
		Menu = React.createElement(NexoSelectionMenu, {
			visible = menuVisible,
			nexoId = self._selectedNexoId,
			snapshot = self._snapshot,
			localUserId = LOCAL_PLAYER.UserId,
			onSelect = function()
				self:_claimSelectedNexo()
			end,
			onClose = function()
				self:_closeMenu(true)
			end,
		}),
	}))
end

function NexoSelectionController:_handleInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape and self._selectedNexoId ~= nil then
		self:_closeMenu(true)
		return
	end

	if self._snapshot.phaseActive ~= true or self._selectedNexoId ~= nil then
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

	local record = self:_getNexoAtPointer(pointerPosition)
	if record == nil or record.state ~= NexoConfig.States.Available then
		return
	end

	self:_openMenu(record.id)
end

function NexoSelectionController:_openMenu(nexoId: string)
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

function NexoSelectionController:_closeMenu(release: boolean)
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
		self:_closeMenu(false)
	end
end

function NexoSelectionController:_showAssignment(payload)
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

	for _, guiObject in playerGui:GetGuiObjectsAtPosition(pointerPosition.X, pointerPosition.Y) do
		local screenGui = guiObject:FindFirstAncestorOfClass("ScreenGui")
		if
			screenGui ~= nil
			and (screenGui.Name == "NexoSelectionGui" or screenGui.Name == "BuildingMenuGui" or screenGui.Name == "BuildControlsGui")
			and guiObjectBlocksWorldInput(guiObject)
		then
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
		if instanceContains(record.instance, result.Instance) then
			return record
		end
	end

	return nil
end

function NexoSelectionController:_updateHover()
	if self._destroyed or self._snapshot.phaseActive ~= true or self._selectedNexoId ~= nil then
		self:_clearHover()
		return
	end

	local pointerPosition = self:_getPointerPosition()
	if pointerPosition == nil or self:_isPointerOverNexoUi(pointerPosition) then
		self:_clearHover()
		return
	end

	local record = self:_getNexoAtPointer(pointerPosition)
	local nextHoveredId = if record ~= nil then record.id else nil
	if nextHoveredId ~= self._hoveredNexoId then
		self._hoveredNexoId = nextHoveredId
		self:_applyHighlight()
	end
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

function NexoSelectionController:_applySnapshotVisuals()
	local seen = {}

	for _, record in self._snapshot.nexos do
		seen[record.id] = true

		if record.state == NexoConfig.States.Taken then
			self:_tintNexo(record)
		else
			self:_restoreNexo(record)
		end

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

function NexoSelectionController:_tintNexo(record)
	for _, part in getNexoParts(record.instance) do
		if self._originalVisuals[part] == nil then
			self._originalVisuals[part] = {
				Color = part.Color,
				Transparency = part.Transparency,
				Material = part.Material,
			}
		end

		part.Color = colors.Red
		part.Transparency = math.max(part.Transparency, 0.18)
		part.Material = Enum.Material.Slate
	end
end

function NexoSelectionController:_restoreNexo(record)
	for _, part in getNexoParts(record.instance) do
		local original = self._originalVisuals[part]
		if original ~= nil then
			part.Color = original.Color
			part.Transparency = original.Transparency
			part.Material = original.Material
			self._originalVisuals[part] = nil
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

	for nexoId in self._selectedBillboards do
		self:_removeSelectedBillboard(nexoId)
	end

	for part, original in self._originalVisuals do
		if part.Parent ~= nil then
			part.Color = original.Color
			part.Transparency = original.Transparency
			part.Material = original.Material
		end
	end

	table.clear(self._originalVisuals)
	self._trove:Destroy()
end

return NexoSelectionController
