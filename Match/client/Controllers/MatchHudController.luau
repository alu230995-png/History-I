local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("Knit"))
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))
local Trove = require(Packages:WaitForChild("Trove"))

local MatchHud = require(script.Parent.Parent:WaitForChild("Components"):WaitForChild("MatchHud"):WaitForChild("index"))
local WorldInput = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("WorldInput"))

local MatchHudController = Knit.CreateController({
	Name = "MatchHudController",
})

local LOCAL_PLAYER = Players.LocalPlayer

function MatchHudController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._resourceService = nil
	self._clockService = nil
	self._nexoService = nil
	self._diplomacyService = nil
	self._resources = nil
	self._clock = nil
	self._nexoSnapshot = nil
	self._diplomacySnapshot = nil
	self._playerCards = {}
	self._thumbnailByUserId = {}
	self._root = nil
	self._screenGui = nil
	self._camera = Workspace.CurrentCamera
	self._lastViewportSize = if self._camera ~= nil then self._camera.ViewportSize else Vector2.zero
end

function MatchHudController:KnitStart()
	self._resourceService = Knit.GetService("MatchResourceService")
	self._clockService = Knit.GetService("MatchClockService")
	self._nexoService = Knit.GetService("NexoService")
	self._diplomacyService = Knit.GetService("DiplomacyService")
	self:_mountUi()

	self._resources = self._resourceService:GetSnapshot()
	self._clock = self._clockService:GetSnapshot()
	self._nexoSnapshot = self._nexoService:GetSnapshot()
	self._diplomacySnapshot = self._diplomacyService:GetSnapshot()
	self:_refreshPlayerCards()
	self:_render()

	self._trove:Add(self._resourceService.ResourcesChanged:Connect(function(resources)
		self._resources = resources
		self:_render()
	end))
	self._trove:Add(self._clockService.ClockChanged:Connect(function(snapshot)
		self._clock = snapshot
		self:_render()
	end))
	self._trove:Add(self._nexoService.NexoSnapshotChanged:Connect(function(snapshot)
		self._nexoSnapshot = snapshot
		self:_render()
	end))
	self._trove:Add(self._diplomacyService.DiplomacySnapshotChanged:Connect(function(snapshot)
		self._diplomacySnapshot = snapshot
		self:_render()
	end))
	self._trove:Add(Players.PlayerAdded:Connect(function()
		self:_refreshPlayerCards()
	end))
	self._trove:Add(Players.PlayerRemoving:Connect(function()
		self:_refreshPlayerCards()
	end))
	self._trove:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self._camera = Workspace.CurrentCamera
		self._lastViewportSize = if self._camera ~= nil then self._camera.ViewportSize else Vector2.zero
		self:_render()
	end))
	self._trove:Add(RunService.RenderStepped:Connect(function()
		local viewportSize = if self._camera ~= nil then self._camera.ViewportSize else Vector2.zero
		if viewportSize ~= self._lastViewportSize then
			self._lastViewportSize = viewportSize
			self:_render()
		end
	end))
end

function MatchHudController:_mountUi()
	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MatchHudGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 40
	screenGui:SetAttribute(WorldInput.BehaviorAttribute, WorldInput.Behaviors.PassThrough)
	screenGui.Parent = playerGui
	self._screenGui = screenGui
	self._trove:Add(screenGui)

	local root = ReactRoblox.createRoot(screenGui)
	self._root = root
	self._trove:Add(function()
		root:unmount()
	end)
end

function MatchHudController:_refreshPlayerCards()
	local cards = {}
	for _, player in Players:GetPlayers() do
		local thumbnail = self._thumbnailByUserId[player.UserId]
		table.insert(cards, {
			userId = player.UserId,
			name = player.DisplayName,
			thumbnail = thumbnail,
		})

		if thumbnail == nil then
			task.spawn(function()
				local ok, content = pcall(function()
					return Players:GetUserThumbnailAsync(
						player.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size100x100
					)
				end)
				if ok and typeof(content) == "string" and not self._destroyed then
					self._thumbnailByUserId[player.UserId] = content
					self:_refreshPlayerCards()
				end
			end)
		end
	end

	self._playerCards = cards
	self:_render()
end

function MatchHudController:_render()
	if self._root == nil then
		return
	end

	self._root:render(React.createElement(MatchHud, {
		resources = self._resources,
		clock = self._clock,
		nexoSnapshot = self._nexoSnapshot,
		diplomacySnapshot = self._diplomacySnapshot,
		playerCards = self._playerCards,
		localUserId = LOCAL_PLAYER.UserId,
		viewportSize = self._lastViewportSize,
	}))
end

function MatchHudController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
end

return MatchHudController
