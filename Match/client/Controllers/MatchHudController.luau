local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	self._resources = nil
	self._clock = nil
	self._root = nil
	self._screenGui = nil
end

function MatchHudController:KnitStart()
	self._resourceService = Knit.GetService("MatchResourceService")
	self._clockService = Knit.GetService("MatchClockService")
	self:_mountUi()

	self._resources = self._resourceService:GetSnapshot()
	self._clock = self._clockService:GetSnapshot()
	self:_render()

	self._trove:Add(self._resourceService.ResourcesChanged:Connect(function(resources)
		self._resources = resources
		self:_render()
	end))
	self._trove:Add(self._clockService.ClockChanged:Connect(function(snapshot)
		self._clock = snapshot
		self:_render()
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

function MatchHudController:_render()
	if self._root == nil then
		return
	end

	self._root:render(React.createElement(MatchHud, {
		resources = self._resources,
		clock = self._clock,
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
