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
local GridConfig = require(Shared:WaitForChild("Constants"):WaitForChild("GridConfig"))
local PlayerStates = require(Shared:WaitForChild("Constants"):WaitForChild("PlayerStates"))
local HexUtils = require(Shared:WaitForChild("Utils"):WaitForChild("HexUtils"))

local BuildControls =
	require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("BuildControls"):WaitForChild("index"))
local WorldInput = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("WorldInput"))

type BuildTarget = {
	socketName: string,
	socketPosition: Vector3,
	hexPart: BasePart,
}

local BuildController = Knit.CreateController({
	Name = "BuildController",
})

local LOCAL_PLAYER = Players.LocalPlayer
local MAX_RAY_DISTANCE = 500
local SHADOW_MATERIAL = Enum.Material.ForceField

local function findTaggedHexPart(instance: Instance?): BasePart?
	local current = instance

	while current ~= nil and current ~= Workspace do
		if current:IsA("BasePart") and CollectionService:HasTag(current, GridConfig.BuildableHexTag) then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function getSocketPosition(socketPositions, socketName: string): Vector3
	if socketName == "Center" then
		return socketPositions.Center
	end

	local edgeIndex = HexUtils.getEdgeIndex(socketName)
	if edgeIndex == nil then
		return socketPositions.Center
	end

	return socketPositions.Edge[edgeIndex]
end

local function splitPath(path: string): { string }
	local parts = {}

	for segment in string.gmatch(path, "[^/%.]+") do
		table.insert(parts, segment)
	end

	return parts
end

local function resolvePath(path: any): Instance?
	if typeof(path) ~= "string" or path == "" then
		return nil
	end

	local segments = splitPath(path)
	local firstSegment = segments[1]
	if firstSegment == nil then
		return nil
	end

	local current = ({
		game = game,
		Game = game,
		ReplicatedStorage = ReplicatedStorage,
		Workspace = Workspace,
	})[firstSegment]

	if current == nil then
		local ok, service = pcall(function()
			return game:GetService(firstSegment)
		end)
		if ok then
			current = service
		end
	end

	if current == nil then
		return nil
	end

	for index = 2, #segments do
		current = (current :: Instance):FindFirstChild(segments[index])
		if current == nil then
			return nil
		end
	end

	return current :: Instance
end

local function getBuildingModelSource(buildingType: string, definition): Model?
	local source = resolvePath(definition.Path)
	if source == nil then
		warn(("[BuildController] Missing model path for %s: %s"):format(buildingType, tostring(definition.Path)))
		return nil
	end

	if not source:IsA("Model") then
		warn(
			("[BuildController] Building path for %s must point to a Model, got %s"):format(
				buildingType,
				source.ClassName
			)
		)
		return nil
	end

	return source
end

local function cloneBuildingModel(buildingType: string, definition): Model?
	local source = getBuildingModelSource(buildingType, definition)
	return if source ~= nil then source:Clone() else nil
end

local function getPlacementRotation(hexPart: BasePart, socketName: string, rotation: number, definition): number
	local placementMode = definition.PlacementMode or BuildingConfig.PlacementModes.Center

	if placementMode == BuildingConfig.PlacementModes.Edge then
		local placementRotation = (
			HexUtils.getEdgeYawDegreesFromPart(hexPart, socketName) + (definition.ModelYawOffset or 0)
		) % 360
		return placementRotation
	end

	if definition.RotationLocked == true then
		return 0
	end

	return rotation
end

local function getPlacementCFrame(target: BuildTarget, rotation: number, definition): CFrame
	local offset = definition.PivotOffset or Vector3.zero
	local pivotTopOffsetY = GridConfig.BuildingPivotTopOffsetY or 0
	local verticalOffset = BuildingConfig.Shadow.VerticalOffset or 0
	local placementRotation = getPlacementRotation(target.hexPart, target.socketName, rotation, definition)

	return CFrame.new(target.socketPosition + Vector3.new(0, pivotTopOffsetY + offset.Y + verticalOffset, 0))
		* CFrame.Angles(0, math.rad(placementRotation), 0)
end

local function normalizeRotation(rotation: number): number
	return (math.round(rotation / 60) * 60) % 360
end

function BuildController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._buildingModeTrove = nil
	self._camera = Workspace.CurrentCamera
	self._buildService = nil
	self._gameService = nil
	self._isBuildingMode = false
	self._selectedBuildingType = nil
	self._movingBuilding = nil
	self._movingBuildingId = nil
	self._rotation = 0
	self._target = nil
	self._lastTouchPosition = nil
	self._lastMapPointerPosition = nil
	self._manualEdgeSocketName = nil
	self._manualEdgeTarget = nil
	self._resources = table.clone(BuildingConfig.StartingResources)
	self._hexSnapshotTarget = nil
	self._hexSnapshot = nil
	self._previewValid = false
	self._previewReason = "NoBuilding"
	self._lastUiSignature = nil
	self._root = nil
	self._screenGui = nil
	self._shadowModel = nil
	self._shadowBuildingType = nil

	self._shadowFolder = Instance.new("Folder")
	self._shadowFolder.Name = `{BuildingConfig.PreviewFolderName}_{LOCAL_PLAYER.UserId}`
	self._shadowFolder.Parent = Workspace
	self._trove:Add(self._shadowFolder)

	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
	end))
end

function BuildController:KnitStart()
	self._buildService = Knit.GetService("BuildService")
	self._gameService = Knit.GetService("GameService")
	self:_mountUi()
	self:_refreshResources()

	self._trove:Add(self._buildService.ResourcesChanged:Connect(function(resources)
		self._resources = resources
		self._hexSnapshotTarget = nil
		self:_updatePreview()
		self:_renderBuildUi()
	end))

	self._trove:Add(self._buildService.BuildingPlaced:Connect(function(payload)
		if self._target ~= nil and payload ~= nil and payload.hexPart == self._target.hexPart then
			self._hexSnapshotTarget = nil
		end
	end))

	self._trove:Add(self._buildService.BuildingMoved:Connect(function(payload)
		if self._target ~= nil and payload ~= nil and payload.hexPart == self._target.hexPart then
			self._hexSnapshotTarget = nil
		end
	end))

	self._trove:Add(self._buildService.BuildingDestroyed:Connect(function()
		self._hexSnapshotTarget = nil
	end))

	self._trove:Add(self._gameService.PlayerStateChanged:Connect(function(_oldState: string, newState: string)
		self:_setBuildingModeActive(newState == PlayerStates.Building)
	end))

	local state = self._gameService:GetPlayerState()
	self:_setBuildingModeActive(state == PlayerStates.Building)
end

function BuildController:SetSelectedBuildingType(buildingType: string?)
	if buildingType == nil then
		self:CancelPlacement()
		return
	end

	local normalized = BuildingConfig.NormalizeBuildingType(buildingType)
	if normalized == nil then
		warn(("[BuildController] Unknown building type %s"):format(tostring(buildingType)))
		return
	end

	local definition = BuildingConfig.Buildings[normalized]
	if definition == nil or getBuildingModelSource(normalized, definition) == nil then
		self:CancelPlacement()
		return
	end

	self._selectedBuildingType = normalized
	self._movingBuilding = nil
	self._movingBuildingId = nil
	self._rotation = 0
	self._target = nil
	self._manualEdgeSocketName = nil
	self._manualEdgeTarget = nil
	self._shadowBuildingType = nil
	self._previewValid = false
	self._previewReason = "NoTarget"

	local result = if self._gameService ~= nil then self._gameService:SetBuildingMode(true) else nil
	if result ~= nil and result.ok ~= true then
		warn(("[BuildController] Could not enter building mode: %s"):format(tostring(result.reason)))
		self._selectedBuildingType = nil
		self:_destroyShadow()
		self:_renderBuildUi()
		return
	end

	if result ~= nil and result.state == PlayerStates.Building then
		self:_setBuildingModeActive(true)
	end

	if self._isBuildingMode then
		self:_updateTarget()
		self:_updatePreview()
	end

	self:_renderBuildUi()
end

function BuildController:StartMovingBuilding(building: Model?): { ok: boolean, reason: string? }
	if typeof(building) ~= "Instance" or not building:IsA("Model") then
		return { ok = false, reason = "InvalidBuilding" }
	end

	local buildingId = building:GetAttribute("BuildingId")
	local normalized = BuildingConfig.NormalizeBuildingType(building:GetAttribute("BuildingType"))
	if typeof(buildingId) ~= "string" or normalized == nil then
		return { ok = false, reason = "InvalidBuilding" }
	end

	local definition = BuildingConfig.Buildings[normalized]
	if definition == nil or getBuildingModelSource(normalized, definition) == nil then
		return { ok = false, reason = "MissingBuildingModel" }
	end

	self._selectedBuildingType = normalized
	self._movingBuilding = building
	self._movingBuildingId = buildingId
	self._rotation = 0
	self._target = nil
	self._manualEdgeSocketName = nil
	self._manualEdgeTarget = nil
	self._shadowBuildingType = nil
	self._previewValid = false
	self._previewReason = "NoTarget"

	local result = if self._gameService ~= nil then self._gameService:SetBuildingMode(true) else nil
	if result ~= nil and result.ok ~= true then
		warn(("[BuildController] Could not enter moving mode: %s"):format(tostring(result.reason)))
		self._selectedBuildingType = nil
		self._movingBuilding = nil
		self._movingBuildingId = nil
		self:_destroyShadow()
		self:_renderBuildUi()
		return {
			ok = false,
			reason = result.reason,
		}
	end

	if result ~= nil and result.state == PlayerStates.Building then
		self:_setBuildingModeActive(true)
	end

	if self._isBuildingMode then
		self:_updateTarget()
		self:_updatePreview()
	end

	self:_renderBuildUi()
	return { ok = true }
end

function BuildController:CancelPlacement()
	self._selectedBuildingType = nil
	self._movingBuilding = nil
	self._movingBuildingId = nil
	self._target = nil
	self._manualEdgeSocketName = nil
	self._manualEdgeTarget = nil
	self._previewValid = false
	self._previewReason = "Cancelled"
	self._hexSnapshotTarget = nil
	self:_destroyShadow()

	if self._gameService ~= nil then
		self._gameService:SetBuildingMode(false)
	end

	self:_setBuildingModeActive(false)
	self:_renderBuildUi()
end

function BuildController:RotateSelectedBuilding(direction: number?)
	if self._selectedBuildingType == nil or not BuildingConfig.CanRotate(self._selectedBuildingType) then
		return
	end

	local definition = BuildingConfig.Buildings[self._selectedBuildingType]
	local placementMode = if definition ~= nil then definition.PlacementMode else BuildingConfig.PlacementModes.Center

	if placementMode == BuildingConfig.PlacementModes.Edge then
		self:_rotateEdgeTarget(direction or 1)
		return
	end

	local rotationStep = if direction ~= nil and direction < 0 then -60 else 60
	self:SetRotation(self._rotation + rotationStep)
end

function BuildController:SetRotation(rotation: number)
	if typeof(rotation) ~= "number" or rotation ~= rotation or math.abs(rotation) == math.huge then
		return
	end

	self._rotation = normalizeRotation(rotation)
	self:_updatePreview()
	self:_renderBuildUi()
end

function BuildController:GetCurrentTarget(): BuildTarget?
	return self._target
end

function BuildController:RequestBuildAtCurrentTarget(): { ok: boolean, reason: string? }
	if self._selectedBuildingType == nil or self._target == nil or self._buildService == nil then
		return { ok = false, reason = "NoTarget" }
	end

	self:_updatePreview()
	if not self._previewValid then
		return { ok = false, reason = self._previewReason }
	end

	local target = self._target :: BuildTarget
	local result = nil
	if self._movingBuildingId ~= nil then
		result = self._buildService:RequestMove({
			buildingId = self._movingBuildingId,
			hexPart = target.hexPart,
			socketName = target.socketName,
			rotation = self._rotation,
		})
	else
		result = self._buildService:RequestBuild({
			hexPart = target.hexPart,
			socketName = target.socketName,
			buildingType = self._selectedBuildingType,
			rotation = self._rotation,
		})
	end

	if result ~= nil and result.resources ~= nil then
		self._resources = result.resources
	end

	if result ~= nil and result.ok then
		self._hexSnapshotTarget = nil
		self:CancelPlacement()
	else
		self._previewReason = if result ~= nil and result.reason ~= nil then result.reason else "Rejected"
		self._previewValid = false
		self:_applyShadowValidity(false)
		self:_renderBuildUi()
	end

	return result
end

function BuildController:_mountUi()
	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BuildControlsGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 30
	screenGui.Parent = playerGui
	self._screenGui = screenGui

	local root = ReactRoblox.createRoot(screenGui)
	self._root = root
	self._trove:Add(function()
		root:unmount()
	end)
	self._trove:Add(screenGui)

	self:_renderBuildUi(true)
end

function BuildController:_setBuildingModeActive(isActive: boolean)
	if self._isBuildingMode == isActive then
		return
	end

	self._isBuildingMode = isActive

	if self._buildingModeTrove ~= nil then
		self._buildingModeTrove:Destroy()
		self._buildingModeTrove = nil
	end

	if not isActive then
		self._selectedBuildingType = nil
		self._movingBuilding = nil
		self._movingBuildingId = nil
		self._lastTouchPosition = nil
		self._lastMapPointerPosition = nil
		self._target = nil
		self:_destroyShadow()
		self:_renderBuildUi()
		return
	end

	self._buildingModeTrove = Trove.new()
	self._trove:Add(self._buildingModeTrove)
	self:_bindBuildingInputs(self._buildingModeTrove)
	self:_updateTarget()
	self:_updatePreview()
	self:_renderBuildUi()
end

function BuildController:_bindBuildingInputs(trove)
	trove:Add(RunService.RenderStepped:Connect(function()
		self:_updateTarget()
		self:_updatePreview()
	end))

	trove:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType == Enum.UserInputType.Touch then
			local touchPosition = Vector2.new(input.Position.X, input.Position.Y)
			if self:_isPointerOverBuildUi(touchPosition) then
				return
			end

			self._lastTouchPosition = touchPosition
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local mousePosition = UserInputService:GetMouseLocation()
			if self:_isPointerOverBuildUi(mousePosition) then
				return
			end

			self:_updateTarget()
			self:RequestBuildAtCurrentTarget()
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:CancelPlacement()
			return
		end

		if input.KeyCode == Enum.KeyCode.E then
			self:RotateSelectedBuilding(1)
		elseif input.KeyCode == Enum.KeyCode.Q then
			self:RotateSelectedBuilding(-1)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			self:CancelPlacement()
		end
	end))

	trove:Add(UserInputService.InputChanged:Connect(function(input: InputObject, _gameProcessedEvent: boolean)
		if input.UserInputType == Enum.UserInputType.Touch then
			local touchPosition = Vector2.new(input.Position.X, input.Position.Y)
			if self:_isPointerOverBuildUi(touchPosition) then
				return
			end

			self._lastTouchPosition = touchPosition
		end
	end))

	trove:Add(UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessedEvent: boolean)
		if input.UserInputType == Enum.UserInputType.Touch then
			return
		end
	end))
end

function BuildController:_isPointerOverBuildUi(pointerPosition: Vector2): boolean
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if playerGui == nil or not playerGui:IsA("PlayerGui") then
		return false
	end

	return WorldInput.IsPointerBlocked(playerGui, pointerPosition)
end

function BuildController:_renderBuildUi(force: boolean?)
	if self._root == nil then
		return
	end

	local definition = if self._selectedBuildingType ~= nil
		then BuildingConfig.Buildings[self._selectedBuildingType]
		else nil
	local target = self._target
	local visible = self._isBuildingMode and self._selectedBuildingType ~= nil
	local canRotate = visible and BuildingConfig.CanRotate(self._selectedBuildingType)
	local socketName = if target ~= nil then target.socketName else self._previewReason
	local buildingName = if definition ~= nil then definition.DisplayName else nil
	if buildingName ~= nil and self._movingBuildingId ~= nil then
		buildingName = `MOVER {buildingName}`
	end
	local signature = table.concat({
		tostring(visible),
		tostring(self._selectedBuildingType),
		tostring(self._movingBuildingId),
		tostring(self._previewValid),
		tostring(self._previewReason),
		tostring(canRotate),
		tostring(socketName),
		tostring(self._rotation),
	}, "|")

	if not force and signature == self._lastUiSignature then
		return
	end
	self._lastUiSignature = signature

	self._root:render(React.createElement(BuildControls, {
		visible = visible,
		valid = self._previewValid,
		canConfirm = self._previewValid,
		canRotate = canRotate,
		buildingName = buildingName,
		socketName = socketName,
		onRotate = function()
			self:RotateSelectedBuilding(1)
		end,
		onConfirm = function()
			self:RequestBuildAtCurrentTarget()
		end,
		onCancel = function()
			self:CancelPlacement()
		end,
	}))
end

function BuildController:_refreshResources()
	if self._buildService == nil then
		return
	end

	local resources = self._buildService:GetResources()
	if resources ~= nil then
		self._resources = resources
	end
end

function BuildController:_getPointerPosition(): Vector2?
	if self._lastTouchPosition ~= nil then
		return self._lastTouchPosition
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	if mouseLocation.X >= 0 and mouseLocation.Y >= 0 then
		return mouseLocation
	end

	return nil
end

function BuildController:_updateTarget()
	if not self._isBuildingMode then
		self:_setTarget(nil)
		return
	end

	if self._camera == nil then
		self:_setTarget(nil)
		return
	end

	local pointerPosition = self:_getPointerPosition()
	if pointerPosition == nil then
		self:_setTarget(nil)
		return
	end

	if self:_isPointerOverBuildUi(pointerPosition) then
		return
	end

	if self._lastMapPointerPosition ~= nil and (pointerPosition - self._lastMapPointerPosition).Magnitude > 2 then
		self._manualEdgeSocketName = nil
		self._manualEdgeTarget = nil
	end
	self._lastMapPointerPosition = pointerPosition

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { self._shadowFolder }

	local ray = self._camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * MAX_RAY_DISTANCE, raycastParams)
	if result == nil then
		self:_setTarget(nil)
		return
	end

	local hexPart = findTaggedHexPart(result.Instance)
	if hexPart == nil then
		self:_setTarget(nil)
		return
	end

	local placementMode = self:_getPlacementMode()
	local socketName = HexUtils.getNearestSocketForPlacementModeFromPart(result.Position, hexPart, placementMode)
	if placementMode == BuildingConfig.PlacementModes.Edge and self._manualEdgeTarget == hexPart then
		socketName = self._manualEdgeSocketName or socketName
	end

	local socketPositions = HexUtils.getSocketPositionsFromPart(hexPart)
	self:_setTarget({
		socketName = socketName,
		socketPosition = getSocketPosition(socketPositions, socketName),
		hexPart = hexPart,
	})
end

function BuildController:_getPlacementMode(): string
	if self._selectedBuildingType == nil then
		return BuildingConfig.PlacementModes.Center
	end

	return BuildingConfig.GetPlacementMode(self._selectedBuildingType) or BuildingConfig.PlacementModes.Center
end

function BuildController:_rotateEdgeTarget(direction: number)
	local target = self._target
	if target == nil then
		return
	end

	local nextSocketName = HexUtils.getNextEdgeSocketName(target.socketName, direction)
	local nextSocketPosition = HexUtils.getSocketPositionFromPart(target.hexPart, nextSocketName)

	self._manualEdgeSocketName = nextSocketName
	self._manualEdgeTarget = target.hexPart
	self:_setTarget({
		socketName = nextSocketName,
		socketPosition = nextSocketPosition,
		hexPart = target.hexPart,
	})
	self:_updatePreview()
end

function BuildController:_setTarget(target: BuildTarget?)
	local oldTarget = self._target
	self._target = target

	if target == nil then
		self._manualEdgeSocketName = nil
		self._manualEdgeTarget = nil
	end

	if oldTarget == nil and target == nil then
		return
	end

	if
		oldTarget == nil
		or target == nil
		or oldTarget.hexPart ~= target.hexPart
		or oldTarget.socketName ~= target.socketName
	then
		self:_renderBuildUi()
	end
end

function BuildController:_updatePreview()
	if not self._isBuildingMode or self._selectedBuildingType == nil then
		self._previewValid = false
		self._previewReason = "NoBuilding"
		self:_destroyShadow()
		self:_renderBuildUi()
		return
	end

	local definition = BuildingConfig.Buildings[self._selectedBuildingType]
	if definition == nil or self._target == nil then
		self._previewValid = false
		self._previewReason = if definition == nil then "InvalidBuilding" else "NoTarget"
		self:_hideShadow()
		self:_renderBuildUi()
		return
	end

	if not self:_ensureShadowModel(self._selectedBuildingType, definition) then
		self._previewValid = false
		self._previewReason = "MissingBuildingModel"
		self:_renderBuildUi()
		return
	end

	if self._shadowModel ~= nil then
		self._shadowModel:PivotTo(getPlacementCFrame(self._target, self._rotation, definition))
	end

	local ok, reason = self:_validateLocalPlacement(self._selectedBuildingType, definition, self._target)
	self._previewValid = ok
	self._previewReason = reason
	self:_applyShadowValidity(ok)
	self:_renderBuildUi()
end

function BuildController:_validateLocalPlacement(
	buildingType: string,
	definition,
	target: BuildTarget
): (boolean, string)
	local terrainType = target.hexPart:GetAttribute("TerrainType")
	if typeof(terrainType) ~= "string" or terrainType == "" then
		terrainType = GridConfig.DefaultTerrainType
	end

	if not GridConfig.BuildableTerrains[terrainType] then
		return false, "BlockedTerrain"
	end

	if not BuildingConfig.IsSocketAllowed(buildingType, target.socketName) then
		return false, "SocketNotAllowed"
	end

	if self._movingBuildingId == nil then
		if self._resources.Gold < definition.Gold then
			return false, "NotEnoughGold"
		end

		if self._resources.PopulationUsed + definition.Population > self._resources.PopulationCap then
			return false, "NotEnoughPopulation"
		end
	end

	local snapshot = self:_getHexSnapshot(target)
	if snapshot == nil then
		return false, "MissingHex"
	end

	if snapshot.TerritoryAllowed ~= true then
		return false, snapshot.TerritoryReason or "OutOfNexoState"
	end

	local socketSnapshot = if snapshot ~= nil and snapshot.Sockets ~= nil
		then snapshot.Sockets[target.socketName]
		else nil
	if socketSnapshot ~= nil and socketSnapshot.Occupied == true then
		return false, "SocketOccupied"
	end

	if self:_shadowCollides(target.hexPart) then
		return false, "BlockedByCollision"
	end

	return true, "Valid"
end

function BuildController:_getHexSnapshot(target: BuildTarget): any?
	if self._buildService == nil then
		return nil
	end

	if target.hexPart == self._hexSnapshotTarget then
		return self._hexSnapshot
	end

	self._hexSnapshotTarget = target.hexPart
	self._hexSnapshot = self._buildService:GetHexSnapshot(target.hexPart)

	return self._hexSnapshot
end

function BuildController:_ensureShadowModel(buildingType: string, definition): boolean
	if self._shadowModel ~= nil and self._shadowBuildingType == buildingType then
		self._shadowModel.Parent = self._shadowFolder
		return true
	end

	self:_destroyShadow()

	local shadowModel = cloneBuildingModel(buildingType, definition)
	if shadowModel == nil then
		return false
	end

	shadowModel.Name = `{buildingType}_Shadow`
	shadowModel.Parent = self._shadowFolder
	self._shadowModel = shadowModel
	self._shadowBuildingType = buildingType

	self:_prepareShadowModel(shadowModel)
	return true
end

function BuildController:_prepareShadowModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("MeshPart") then
			if descendant.TextureID ~= "" then
				descendant:SetAttribute("OriginalTextureID", descendant.TextureID)
				descendant.TextureID = ""
			end
		end

		if descendant:IsA("Decal") or descendant:IsA("Texture") or descendant:IsA("SurfaceAppearance") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
			descendant.Material = SHADOW_MATERIAL
			descendant.Transparency = BuildingConfig.Shadow.Transparency
		end
	end
end

function BuildController:_applyShadowValidity(isValid: boolean)
	if self._shadowModel == nil then
		return
	end

	local color = if isValid then BuildingConfig.Shadow.ValidColor else BuildingConfig.Shadow.InvalidColor
	for _, descendant in self._shadowModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = color
		end
	end
end

function BuildController:_shadowCollides(placementHex: BasePart): boolean
	if self._shadowModel == nil then
		return false
	end

	local boxCFrame, boxSize = self._shadowModel:GetBoundingBox()
	if boxSize.Magnitude <= 0 then
		return false
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = if self._movingBuilding ~= nil
		then { self._shadowModel, placementHex, self._movingBuilding }
		else { self._shadowModel, placementHex }

	local placedFolder = Workspace:FindFirstChild(BuildingConfig.PlacedFolderName)
	for _, part in Workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams) do
		if part:IsDescendantOf(self._shadowModel) or part == placementHex then
			continue
		end

		if placedFolder ~= nil and part:IsDescendantOf(placedFolder) then
			continue
		end

		if CollectionService:HasTag(part, GridConfig.BuildableHexTag) then
			continue
		end

		if part.Transparency >= 1 and not part.CanCollide and not part.CanQuery then
			continue
		end

		return true
	end

	return false
end

function BuildController:_hideShadow()
	if self._shadowModel ~= nil then
		self._shadowModel.Parent = nil
	end
end

function BuildController:_destroyShadow()
	if self._shadowModel ~= nil then
		self._shadowModel:Destroy()
	end

	self._shadowModel = nil
	self._shadowBuildingType = nil
end

function BuildController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self:_destroyShadow()
	self._trove:Destroy()
end

return BuildController
