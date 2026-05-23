local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

local MenuCoordinatorController = Knit.CreateController({
	Name = "MenuCoordinatorController",
})

function MenuCoordinatorController:KnitInit()
	self._activeMenuId = nil
	self._closeCallback = nil
end

function MenuCoordinatorController:RequestOpen(menuId: string, closeCallback)
	if self._activeMenuId == menuId then
		self._closeCallback = closeCallback
		return true
	end

	self:CloseActive()
	self._activeMenuId = menuId
	self._closeCallback = closeCallback
	return true
end

function MenuCoordinatorController:Close(menuId: string)
	if self._activeMenuId ~= menuId then
		return
	end

	self._activeMenuId = nil
	self._closeCallback = nil
end

function MenuCoordinatorController:CloseActive()
	local closeCallback = self._closeCallback
	self._activeMenuId = nil
	self._closeCallback = nil

	if closeCallback ~= nil then
		closeCallback()
	end
end

function MenuCoordinatorController:IsOpen(menuId: string): boolean
	return self._activeMenuId == menuId
end

return MenuCoordinatorController
