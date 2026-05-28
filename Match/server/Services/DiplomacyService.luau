local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local DiplomacyConfig = require(Shared:WaitForChild("Constants"):WaitForChild("DiplomacyConfig"))

local DiplomacyService = Knit.CreateService({
	Name = "DiplomacyService",

	Client = {
		DiplomacySnapshotChanged = Knit.CreateSignal(),
	},
})

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function getColorIndex(seed: number): number
	local colorCount = #DiplomacyConfig.Colors
	return if colorCount > 0 then ((math.abs(seed) - 1) % colorCount) + 1 else 1
end

function DiplomacyService.Client:GetSnapshot(player: Player): any
	return self.Server:_createSnapshot(player)
end

function DiplomacyService.Client:RequestAlliance(player: Player, targetUserId: any): any
	return self.Server:RequestAlliance(player, targetUserId)
end

function DiplomacyService.Client:RespondAlliance(player: Player, inviteId: any, accepted: any): any
	return self.Server:RespondAlliance(player, inviteId, accepted == true)
end

function DiplomacyService.Client:RequestBreakAlliance(player: Player, targetUserId: any): any
	return self.Server:RequestBreakAlliance(player, targetUserId)
end

function DiplomacyService:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._alliances = {}
	self._allianceByUserId = {}
	self._invites = {}
	self._breaks = {}
	self._lastRequestAt = {}
	self._nextAllianceId = 0
	self._nextInviteId = 0
	self._nextColorSeed = 0
end

function DiplomacyService:KnitStart()
	self._trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self:_handlePlayerRemoving(player)
	end))
end

function DiplomacyService:AreAllied(firstUserId: number?, secondUserId: number?): boolean
	if not isFiniteNumber(firstUserId) or not isFiniteNumber(secondUserId) then
		return false
	end

	if firstUserId == secondUserId then
		return true
	end

	local firstAllianceId = self._allianceByUserId[firstUserId]
	return firstAllianceId ~= nil and firstAllianceId == self._allianceByUserId[secondUserId]
end

function DiplomacyService:AreHostile(firstUserId: number?, secondUserId: number?): boolean
	if not isFiniteNumber(firstUserId) or not isFiniteNumber(secondUserId) then
		return false
	end

	return not self:AreAllied(firstUserId, secondUserId)
end

function DiplomacyService:GetAllianceColorIndex(userId: number): number
	local alliance = self:_getAllianceForUserId(userId)
	return if alliance ~= nil then alliance.ColorIndex else getColorIndex(userId)
end

function DiplomacyService:RequestAlliance(player: Player, targetUserId: any): any
	if self:_isRateLimited(player) then
		return { ok = false, reason = "RateLimited" }
	end

	if not isFiniteNumber(targetUserId) then
		return { ok = false, reason = "InvalidTarget" }
	end

	targetUserId = math.floor(targetUserId)
	if targetUserId == player.UserId then
		return { ok = false, reason = "SelfTarget" }
	end

	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if targetPlayer == nil then
		return { ok = false, reason = "MissingTarget" }
	end

	if self:AreAllied(player.UserId, targetUserId) then
		return { ok = false, reason = "AlreadyAllied" }
	end

	local combinedCount = self:_getCombinedMemberCount(player.UserId, targetUserId)
	if combinedCount > DiplomacyConfig.MaxAllianceMembers then
		return { ok = false, reason = "AllianceFull" }
	end

	local existingInvite = self:_findInvite(player.UserId, targetUserId)
	if existingInvite ~= nil then
		return { ok = true, inviteId = existingInvite.Id }
	end

	self._nextInviteId += 1
	local inviteId = `AllianceInvite_{self._nextInviteId}`
	local invite = {
		Id = inviteId,
		FromUserId = player.UserId,
		ToUserId = targetUserId,
		ExpiresAt = os.clock() + DiplomacyConfig.InvitationTtlSeconds,
	}
	self._invites[inviteId] = invite
	self:_scheduleInviteExpiry(invite)
	self:_broadcastPlayers({ player, targetPlayer })

	return { ok = true, inviteId = inviteId }
end

function DiplomacyService:RespondAlliance(player: Player, inviteId: any, accepted: boolean): any
	if typeof(inviteId) ~= "string" then
		return { ok = false, reason = "InvalidInvite" }
	end

	local invite = self._invites[inviteId]
	if invite == nil or invite.ToUserId ~= player.UserId then
		return { ok = false, reason = "MissingInvite" }
	end

	self._invites[inviteId] = nil
	local fromPlayer = Players:GetPlayerByUserId(invite.FromUserId)
	if not accepted then
		self:_broadcastPlayers({ player, fromPlayer })
		return { ok = true, accepted = false }
	end

	if fromPlayer == nil then
		self:_broadcastPlayers({ player })
		return { ok = false, reason = "MissingRequester" }
	end

	local combinedCount = self:_getCombinedMemberCount(invite.FromUserId, invite.ToUserId)
	if combinedCount > DiplomacyConfig.MaxAllianceMembers then
		self:_broadcastPlayers({ player, fromPlayer })
		return { ok = false, reason = "AllianceFull" }
	end

	local alliance = self:_mergeAllianceMembers(invite.FromUserId, invite.ToUserId)
	self:_clearInvitesForMembers(alliance.Members)
	self:_broadcastAlliance(alliance)
	self:_broadcastPlayers({ player, fromPlayer })

	return { ok = true, accepted = true, allianceId = alliance.Id }
end

function DiplomacyService:RequestBreakAlliance(player: Player, targetUserId: any): any
	if self:_isRateLimited(player) then
		return { ok = false, reason = "RateLimited" }
	end

	if not isFiniteNumber(targetUserId) then
		return { ok = false, reason = "InvalidTarget" }
	end

	targetUserId = math.floor(targetUserId)
	if not self:AreAllied(player.UserId, targetUserId) or player.UserId == targetUserId then
		return { ok = false, reason = "NotAllied" }
	end

	local allianceId = self._allianceByUserId[player.UserId]
	local alliance = if allianceId ~= nil then self._alliances[allianceId] else nil
	if alliance == nil then
		return { ok = false, reason = "MissingAlliance" }
	end

	local breakId = `{allianceId}:{player.UserId}`
	local current = self._breaks[breakId]
	if current ~= nil then
		return { ok = true, breakId = breakId, endsAt = current.EndsAt }
	end

	local breakRecord = {
		Id = breakId,
		AllianceId = allianceId,
		RequesterUserId = player.UserId,
		TargetUserId = targetUserId,
		EndsAt = os.clock() + DiplomacyConfig.AllianceBreakDelaySeconds,
	}
	self._breaks[breakId] = breakRecord
	self:_scheduleBreak(breakRecord)
	self:_broadcastAlliance(alliance)

	return { ok = true, breakId = breakId, endsAt = breakRecord.EndsAt }
end

function DiplomacyService:_getAllianceForUserId(userId: number)
	local allianceId = self._allianceByUserId[userId]
	return if allianceId ~= nil then self._alliances[allianceId] else nil
end

function DiplomacyService:_getMemberSet(userId: number): { [number]: boolean }
	local alliance = self:_getAllianceForUserId(userId)
	if alliance == nil then
		return { [userId] = true }
	end

	local members = {}
	for memberUserId in alliance.Members do
		members[memberUserId] = true
	end
	return members
end

function DiplomacyService:_getCombinedMemberCount(firstUserId: number, secondUserId: number): number
	local members = self:_getMemberSet(firstUserId)
	for memberUserId in self:_getMemberSet(secondUserId) do
		members[memberUserId] = true
	end

	local count = 0
	for _ in members do
		count += 1
	end
	return count
end

function DiplomacyService:_mergeAllianceMembers(firstUserId: number, secondUserId: number)
	local members = self:_getMemberSet(firstUserId)
	for memberUserId in self:_getMemberSet(secondUserId) do
		members[memberUserId] = true
	end

	local firstAlliance = self:_getAllianceForUserId(firstUserId)
	local secondAlliance = self:_getAllianceForUserId(secondUserId)
	local alliance = firstAlliance or secondAlliance or self:_createAlliance()

	if firstAlliance ~= nil and firstAlliance ~= alliance then
		self:_deleteAlliance(firstAlliance)
	end
	if secondAlliance ~= nil and secondAlliance ~= alliance then
		self:_deleteAlliance(secondAlliance)
	end

	table.clear(alliance.Members)
	for memberUserId in members do
		alliance.Members[memberUserId] = true
		self._allianceByUserId[memberUserId] = alliance.Id
	end

	return alliance
end

function DiplomacyService:_createAlliance()
	self._nextAllianceId += 1
	self._nextColorSeed += 1
	local alliance = {
		Id = `Alliance_{self._nextAllianceId}`,
		ColorIndex = getColorIndex(self._nextColorSeed),
		Members = {},
	}
	self._alliances[alliance.Id] = alliance
	return alliance
end

function DiplomacyService:_deleteAlliance(alliance)
	self._alliances[alliance.Id] = nil
	for memberUserId in alliance.Members do
		if self._allianceByUserId[memberUserId] == alliance.Id then
			self._allianceByUserId[memberUserId] = nil
		end
	end
end

function DiplomacyService:_removeUserFromAlliance(userId: number)
	local alliance = self:_getAllianceForUserId(userId)
	if alliance == nil then
		return
	end

	alliance.Members[userId] = nil
	self._allianceByUserId[userId] = nil

	local remainingCount = 0
	local remainingUserId = nil
	for memberUserId in alliance.Members do
		remainingCount += 1
		remainingUserId = memberUserId
	end

	if remainingCount <= 1 then
		if remainingUserId ~= nil then
			self._allianceByUserId[remainingUserId] = nil
		end
		self._alliances[alliance.Id] = nil
	end
end

function DiplomacyService:_findInvite(fromUserId: number, toUserId: number)
	for _, invite in self._invites do
		if invite.FromUserId == fromUserId and invite.ToUserId == toUserId then
			return invite
		end
	end
	return nil
end

function DiplomacyService:_clearInvitesForMembers(members: { [number]: boolean })
	for inviteId, invite in self._invites do
		if members[invite.FromUserId] == true and members[invite.ToUserId] == true then
			self._invites[inviteId] = nil
		end
	end
end

function DiplomacyService:_scheduleInviteExpiry(invite)
	task.delay(DiplomacyConfig.InvitationTtlSeconds, function()
		if self._destroyed or self._invites[invite.Id] ~= invite or os.clock() < invite.ExpiresAt then
			return
		end

		self._invites[invite.Id] = nil
		self:_broadcastUsers({ invite.FromUserId, invite.ToUserId })
	end)
end

function DiplomacyService:_scheduleBreak(breakRecord)
	task.delay(DiplomacyConfig.AllianceBreakDelaySeconds, function()
		if self._destroyed or self._breaks[breakRecord.Id] ~= breakRecord or os.clock() < breakRecord.EndsAt then
			return
		end

		self._breaks[breakRecord.Id] = nil
		self:_removeUserFromAlliance(breakRecord.RequesterUserId)
		self:_broadcastAll()
	end)
end

function DiplomacyService:_isRateLimited(player: Player): boolean
	local now = os.clock()
	local lastRequest = self._lastRequestAt[player]
	self._lastRequestAt[player] = now
	return lastRequest ~= nil and now - lastRequest < DiplomacyConfig.RequestCooldownSeconds
end

function DiplomacyService:_createSnapshot(player: Player): any
	local alliances = {}
	for _, alliance in self._alliances do
		local members = {}
		for memberUserId in alliance.Members do
			table.insert(members, memberUserId)
		end
		table.insert(alliances, {
			id = alliance.Id,
			colorIndex = alliance.ColorIndex,
			members = members,
		})
	end

	local invites = {}
	for _, invite in self._invites do
		if invite.ToUserId == player.UserId then
			table.insert(invites, {
				id = invite.Id,
				fromUserId = invite.FromUserId,
				toUserId = invite.ToUserId,
				expiresAt = invite.ExpiresAt,
			})
		end
	end

	local breaks = {}
	for _, breakRecord in self._breaks do
		if self:AreAllied(player.UserId, breakRecord.RequesterUserId) then
			table.insert(breaks, {
				id = breakRecord.Id,
				allianceId = breakRecord.AllianceId,
				requesterUserId = breakRecord.RequesterUserId,
				targetUserId = breakRecord.TargetUserId,
				endsAt = breakRecord.EndsAt,
				remainingSeconds = math.max(0, math.ceil(breakRecord.EndsAt - os.clock())),
			})
		end
	end

	return {
		selfUserId = player.UserId,
		maxMembers = DiplomacyConfig.MaxAllianceMembers,
		colors = DiplomacyConfig.Colors,
		alliances = alliances,
		invites = invites,
		breaks = breaks,
	}
end

function DiplomacyService:_broadcastAll()
	for _, player in Players:GetPlayers() do
		self.Client.DiplomacySnapshotChanged:Fire(player, self:_createSnapshot(player))
	end
end

function DiplomacyService:_broadcastPlayers(players: { Player? })
	local seen = {}
	for index = 1, #players do
		local player = players[index]
		if player ~= nil and player.Parent ~= nil and seen[player] ~= true then
			seen[player] = true
			self.Client.DiplomacySnapshotChanged:Fire(player, self:_createSnapshot(player))
		end
	end
end

function DiplomacyService:_broadcastUsers(userIds: { number })
	local players = {}
	for index = 1, #userIds do
		local player = Players:GetPlayerByUserId(userIds[index])
		if player ~= nil then
			table.insert(players, player)
		end
	end
	self:_broadcastPlayers(players)
end

function DiplomacyService:_broadcastAlliance(alliance)
	if alliance == nil then
		self:_broadcastAll()
		return
	end

	local players = {}
	for memberUserId in alliance.Members do
		local player = Players:GetPlayerByUserId(memberUserId)
		if player ~= nil then
			table.insert(players, player)
		end
	end
	self:_broadcastPlayers(players)
end

function DiplomacyService:_handlePlayerRemoving(player: Player)
	self._lastRequestAt[player] = nil
	self:_removeUserFromAlliance(player.UserId)

	for inviteId, invite in self._invites do
		if invite.FromUserId == player.UserId or invite.ToUserId == player.UserId then
			self._invites[inviteId] = nil
		end
	end

	for breakId, breakRecord in self._breaks do
		if breakRecord.RequesterUserId == player.UserId or breakRecord.TargetUserId == player.UserId then
			self._breaks[breakId] = nil
		end
	end

	self:_broadcastAll()
end

function DiplomacyService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._trove:Destroy()
	table.clear(self._alliances)
	table.clear(self._allianceByUserId)
	table.clear(self._invites)
	table.clear(self._breaks)
	table.clear(self._lastRequestAt)
end

return DiplomacyService
