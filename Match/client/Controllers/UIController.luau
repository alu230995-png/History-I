local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local UIController = Knit.CreateController({
	Name = "UIController",
})

local DISABLED_CORE_GUI = {
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.EmotesMenu,
	Enum.CoreGuiType.Health,
}

function UIController:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()

	for _, coreGuiType in DISABLED_CORE_GUI do
		local ok, err = pcall(function()
			StarterGui:SetCoreGuiEnabled(coreGuiType, false)
		end)

		if not ok then
			warn(("[UIController] Failed to disable %s: %s"):format(tostring(coreGuiType), tostring(err)))
		end
	end

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
	end)

	self:_disableResetButton()
end

function UIController:_disableResetButton()
	local cancelled = false
	self._trove:Add(function()
		cancelled = true
	end)

	task.spawn(function()
		for _ = 1, 10 do
			if cancelled or self._destroyed then
				return
			end

			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)

			if ok then
				return
			end

			task.wait(0.5)
		end

		if not cancelled and not self._destroyed then
			warn("[UIController] Failed to disable reset button")
		end
	end)
end

function UIController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
end

return UIController
