local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Trove = require(Packages:WaitForChild("Trove"))

local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local StateMachine = require(Shared:WaitForChild("Classes"):WaitForChild("StateMachine"))

local Tropa = {}
Tropa.__index = Tropa

function Tropa.new(params)
	local self = setmetatable({}, Tropa)

	self.Id = params.Id
	self.NetId = params.NetId
	self.Owner = params.Owner
	self.Equipo = params.Owner
	self.UnitType = params.UnitType
	self.Definition = params.Definition
	self.Modelo = params.Definition
	self.HP = math.max(params.Definition.HP or 1, 1)
	self.Vida = self.HP
	self.MaxVida = self.HP
	self.Target = nil
	self.StateMachine = StateMachine.new(ManpowerConfig.UnitStates.Idle, ManpowerConfig.UnitStateTransitions)
	self.Trove = Trove.new()
	self._destroyed = false

	self.Trove:Add(self.StateMachine)

	return self
end

function Tropa:IsAlive(): boolean
	return not self._destroyed and self.HP > 0
end

function Tropa:SetTarget(target)
	self.Target = target
end

function Tropa:ClearTarget()
	self.Target = nil
end

function Tropa:RecibirDanio(damage: number): { hp: number, died: boolean }
	if self._destroyed or typeof(damage) ~= "number" or damage <= 0 then
		return {
			hp = self.HP,
			died = self.HP <= 0,
		}
	end

	self.HP = math.max(0, self.HP - damage)
	self.Vida = self.HP

	return {
		hp = self.HP,
		died = self.HP <= 0,
	}
end

function Tropa:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self.Target = nil
	self.Trove:Destroy()
end

return Tropa
