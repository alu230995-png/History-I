local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))
local Trove = require(Packages:WaitForChild("Trove"))

local MatchClockConfig = require(Shared:WaitForChild("Constants"):WaitForChild("MatchClockConfig"))
local MatchStates = require(Shared:WaitForChild("Constants"):WaitForChild("MatchStates"))
local MatchDateUtils = require(Shared:WaitForChild("Utils"):WaitForChild("MatchDateUtils"))

local MatchClockService = Knit.CreateService({
	Name = "MatchClockService",

	Client = {
		ClockChanged = Knit.CreateSignal(),
	},
})

local function cloneClockSnapshot(snapshot)
	return {
		dayIndex = snapshot.dayIndex,
		year = snapshot.year,
		month = snapshot.month,
		day = snapshot.day,
		running = snapshot.running,
	}
end

function MatchClockService.Client:GetSnapshot(_player: Player): any
	return self.Server:GetSnapshot()
end

function MatchClockService:KnitInit()
	local startDate = MatchClockConfig.StartDate

	self._destroyed = false
	self._trove = Trove.new()
	self._tickToken = 0
	self._running = false
	self._dayIndex = 0
	self._year = startDate.Year
	self._month = startDate.Month
	self._day = startDate.Day
	self._gameService = nil
	self.Tick = Signal.new()
	self._trove:Add(self.Tick)
end

function MatchClockService:KnitStart()
	self._gameService = Knit.GetService("GameService")
	self._trove:Add(self._gameService:OnMatchStateChanged(function(transition)
		if transition.NewState == MatchStates.Playing then
			self:_startClock()
		elseif transition.OldState == MatchStates.Playing then
			self:_stopClock()
		end
	end))

	if self._gameService:GetMatchState() == MatchStates.Playing then
		self:_startClock()
	end
end

function MatchClockService:GetSnapshot(): any
	return cloneClockSnapshot({
		dayIndex = self._dayIndex,
		year = self._year,
		month = self._month,
		day = self._day,
		running = self._running,
	})
end

function MatchClockService:OnTick(callback)
	return self.Tick:Connect(callback)
end

function MatchClockService:_startClock()
	if self._running then
		return
	end

	self._running = true
	self._tickToken += 1
	local token = self._tickToken
	self:_broadcastSnapshot()

	task.spawn(function()
		while self._running and not self._destroyed and self._tickToken == token do
			task.wait(MatchClockConfig.TickSeconds)
			if not self._running or self._destroyed or self._tickToken ~= token then
				return
			end

			self:_advanceDay()
		end
	end)
end

function MatchClockService:_stopClock()
	if not self._running then
		return
	end

	self._running = false
	self._tickToken += 1
	self:_broadcastSnapshot()
end

function MatchClockService:_advanceDay()
	self._dayIndex += 1
	self._year, self._month, self._day = MatchDateUtils.AdvanceOneDay(self._year, self._month, self._day)

	local snapshot = self:GetSnapshot()
	self.Tick:Fire(snapshot)
	self.Client.ClockChanged:FireAll(snapshot)
end

function MatchClockService:_broadcastSnapshot()
	self.Client.ClockChanged:FireAll(self:GetSnapshot())
end

function MatchClockService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._running = false
	self._tickToken += 1
	self._trove:Destroy()
end

return MatchClockService
