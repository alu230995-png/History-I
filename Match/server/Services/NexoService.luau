local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local GridConfig = require(Shared:WaitForChild("Constants"):WaitForChild("GridConfig"))
local NexoConfig = require(Shared:WaitForChild("Constants"):WaitForChild("NexoConfig"))

local NexoService = Knit.CreateService({
	Name = "NexoService",

	Client = {
		NexoSnapshotChanged = Knit.CreateSignal(),
		NexoTimerChanged = Knit.CreateSignal(),
		NexoAssigned = Knit.CreateSignal(),
		NexoSelectionEnded = Knit.CreateSignal(),
	},
})

type NexoRecord = {
	Id: string,
	Tag: string,
	Instance: Instance,
	HexPart: BasePart,
	DisplayName: string,
	Lore: string,
	State: string,
	SelectedByUserId: number?,
	TakenByUserId: number?,
}

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

local function getInstancePosition(instance: Instance): Vector3?
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end

	if instance:IsA("BasePart") then
		return instance.Position
	end

	local part = instance:FindFirstChildWhichIsA("BasePart", true)
	return if part ~= nil then part.Position else nil
end

local function formatDisplayName(tag: string, instance: Instance): string
	local attributeName = instance:GetAttribute("DisplayName")
	if typeof(attributeName) == "string" and attributeName ~= "" then
		return attributeName
	end

	local name = if tag == NexoConfig.TagKeyword and instance.Name ~= "" then instance.Name else tag
	name = string.gsub(name, "_", " ")
	name = string.gsub(name, "(%l)(%u)", "%1 %2")

	return name
end

local function getLore(displayName: string, instance: Instance): string
	local lore = instance:GetAttribute("Lore")
	if typeof(lore) == "string" and lore ~= "" then
		return lore
	end

	return NexoConfig.GetDefaultLore(displayName)
end

local function createNexoId(tag: string, instance: Instance, index: number): string
	local attributeId = instance:GetAttribute("NexoId")
	if typeof(attributeId) == "string" and attributeId ~= "" then
		return attributeId
	end

	return `{tag}_{index}`
end

function NexoService.Client:GetSnapshot(_player: Player): any
	return self.Server:_createSnapshot()
end

function NexoService.Client:PreviewNexo(player: Player, nexoId: any): { ok: boolean, reason: string? }
	return self.Server:PreviewNexo(player, nexoId)
end

function NexoService.Client:ReleaseNexo(player: Player, nexoId: any): { ok: boolean, reason: string? }
	return self.Server:ReleaseNexo(player, nexoId)
end

function NexoService.Client:ClaimNexo(player: Player, nexoId: any): { ok: boolean, reason: string? }
	return self.Server:ClaimNexo(player, nexoId)
end

function NexoService:KnitInit()
	self._destroyed = false
	self._trove = Trove.new()
	self._nexos = {}
	self._nexoOrder = {}
	self._assignedByPlayer = {}
	self._previewByPlayer = {}
	self._remainingSeconds = NexoConfig.SelectionDurationSeconds
	self._phaseActive = false
	self._phaseToken = 0
	self._random = Random.new()
	self._buildService = nil
	self._gameService = nil
end

function NexoService:KnitStart()
	self._buildService = Knit.GetService("BuildService")
	self._gameService = Knit.GetService("GameService")

	self._trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self:_handlePlayerRemoving(player)
	end))

	task.defer(function()
		task.wait(0.2)
		if self._destroyed then
			return
		end

		self:DiscoverNexos()
		self:StartNexoSelection()
	end)
end

function NexoService:DiscoverNexos()
	table.clear(self._nexos)
	table.clear(self._nexoOrder)

	if self._buildService ~= nil then
		self._buildService:RebuildBoardState()
	end

	local allTags = CollectionService:GetAllTags()
	local nexoTags = {}
	for _, tag in allTags do
		if string.find(tag, NexoConfig.TagKeyword) ~= nil then
			table.insert(nexoTags, tag)
		end
	end

	local taggedHexes = CollectionService:GetTagged(GridConfig.BuildableHexTag)
	local blockedHexKeys = {}
	local foundNames = {}
	local blockedCoords = {}
	local nextIndex = 0

	for _, tag in nexoTags do
		for _, instance in CollectionService:GetTagged(tag) do
			local hexPart = self:_resolveHexPartBelow(instance, taggedHexes)
			if hexPart == nil then
				warn(("[NexoService] Could not resolve hex below %s"):format(instance:GetFullName()))
				continue
			end

			local hexKey = hexPart:GetFullName()
			if blockedHexKeys[hexKey] == true then
				warn(("[NexoService] Ignoring duplicate Nexo on hex %s"):format(hexKey))
				continue
			end

			nextIndex += 1
			local displayName = formatDisplayName(tag, instance)
			local nexoId = createNexoId(tag, instance, nextIndex)
			local blocked = self._buildService ~= nil
				and self._buildService:BlockHexCenter(hexPart, NexoConfig.BlockReason, instance)

			if not blocked then
				warn(("[NexoService] Could not block hex for %s"):format(instance:GetFullName()))
				continue
			end

			blockedHexKeys[hexKey] = true
			table.insert(foundNames, `"{tag}"`)
			table.insert(blockedCoords, self:_formatHexCoord(hexPart))
			table.insert(self._nexoOrder, nexoId)
			self._nexos[nexoId] = {
				Id = nexoId,
				Tag = tag,
				Instance = instance,
				HexPart = hexPart,
				DisplayName = displayName,
				Lore = getLore(displayName, instance),
				State = NexoConfig.States.Available,
				SelectedByUserId = nil,
				TakenByUserId = nil,
			}
		end
	end

	print(("[Server] Tags leidos: %d"):format(#allTags))
	print(("[Server] Nexos encontrados: %d -> %s"):format(#self._nexoOrder, table.concat(foundNames, ", ")))
	print(("[Server] Hexagonos bloqueados: %s"):format(table.concat(blockedCoords, ", ")))
	self:_broadcastSnapshot()
end

function NexoService:StartNexoSelection(): boolean
	if self._phaseActive then
		return true
	end

	if #self._nexoOrder <= 0 then
		warn("[NexoService] NexoSelection not started because no Nexos were found")
		return false
	end

	if
		self._gameService ~= nil
		and not self._gameService:BeginNexoSelection({
			DurationSeconds = NexoConfig.SelectionDurationSeconds,
		})
	then
		warn("[NexoService] GameService rejected NexoSelection start")
		return false
	end

	self._phaseActive = true
	self._phaseToken += 1
	self._remainingSeconds = NexoConfig.SelectionDurationSeconds
	table.clear(self._assignedByPlayer)
	table.clear(self._previewByPlayer)

	self.Client.NexoTimerChanged:FireAll(self._remainingSeconds)
	self:_broadcastSnapshot()
	self:_startTimer(self._phaseToken)

	return true
end

function NexoService:PreviewNexo(player: Player, nexoId: any): { ok: boolean, reason: string? }
	if not self._phaseActive then
		return { ok = false, reason = "InactivePhase" }
	end

	if self._assignedByPlayer[player] ~= nil then
		return { ok = false, reason = "AlreadyAssigned" }
	end

	if typeof(nexoId) ~= "string" then
		return { ok = false, reason = "InvalidNexo" }
	end

	local record = self._nexos[nexoId] :: NexoRecord?
	if record == nil then
		return { ok = false, reason = "MissingNexo" }
	end

	if record.State == NexoConfig.States.Taken then
		return { ok = false, reason = "Taken" }
	end

	if record.State == NexoConfig.States.Selected and record.SelectedByUserId ~= player.UserId then
		return { ok = false, reason = "SelectedByOther" }
	end

	self:_releasePreviewForPlayer(player, nexoId)
	record.State = NexoConfig.States.Selected
	record.SelectedByUserId = player.UserId
	self._previewByPlayer[player] = nexoId
	self:_broadcastSnapshot()

	return { ok = true }
end

function NexoService:ReleaseNexo(player: Player, nexoId: any): { ok: boolean, reason: string? }
	if typeof(nexoId) ~= "string" then
		return { ok = false, reason = "InvalidNexo" }
	end

	local record = self._nexos[nexoId] :: NexoRecord?
	if record ~= nil and record.State == NexoConfig.States.Selected and record.SelectedByUserId == player.UserId then
		record.State = NexoConfig.States.Available
		record.SelectedByUserId = nil
	end

	if self._previewByPlayer[player] == nexoId then
		self._previewByPlayer[player] = nil
	end

	self:_broadcastSnapshot()
	return { ok = true }
end

function NexoService:ClaimNexo(player: Player, nexoId: any): { ok: boolean, reason: string? }
	if not self._phaseActive then
		return { ok = false, reason = "InactivePhase" }
	end

	if self._assignedByPlayer[player] ~= nil then
		return { ok = false, reason = "AlreadyAssigned" }
	end

	if typeof(nexoId) ~= "string" then
		return { ok = false, reason = "InvalidNexo" }
	end

	local record = self._nexos[nexoId] :: NexoRecord?
	if record == nil then
		return { ok = false, reason = "MissingNexo" }
	end

	if record.State == NexoConfig.States.Taken then
		return { ok = false, reason = "Taken" }
	end

	if record.State == NexoConfig.States.Selected and record.SelectedByUserId ~= player.UserId then
		return { ok = false, reason = "SelectedByOther" }
	end

	self:_assignRecordToPlayer(player, record, false)
	self:_broadcastSnapshot()

	return { ok = true }
end

function NexoService:_resolveHexPartBelow(instance: Instance, taggedHexes: { Instance }): BasePart?
	local directHex = findTaggedHexPart(instance)
	if directHex ~= nil then
		return directHex
	end

	local position = getInstancePosition(instance)
	if position == nil then
		return nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = taggedHexes

	local origin = position + Vector3.new(0, NexoConfig.HexRaycastHeight, 0)
	local direction = Vector3.new(0, -(NexoConfig.HexRaycastHeight + NexoConfig.HexRaycastDepth), 0)
	local result = Workspace:Raycast(origin, direction, raycastParams)

	return if result ~= nil then findTaggedHexPart(result.Instance) else nil
end

function NexoService:_formatHexCoord(hexPart: BasePart): string
	local q = hexPart:GetAttribute("Q")
	local r = hexPart:GetAttribute("R")

	if typeof(q) == "number" and typeof(r) == "number" then
		return `({q},{r})`
	end

	local axialQ = hexPart:GetAttribute("AxialQ")
	local axialR = hexPart:GetAttribute("AxialR")
	if typeof(axialQ) == "number" and typeof(axialR) == "number" then
		return `({axialQ},{axialR})`
	end

	return hexPart.Name
end

function NexoService:_createSnapshot(): any
	local nexos = {}

	for _, nexoId in self._nexoOrder do
		local record = self._nexos[nexoId] :: NexoRecord
		table.insert(nexos, {
			id = record.Id,
			tag = record.Tag,
			instance = record.Instance,
			hexPart = record.HexPart,
			displayName = record.DisplayName,
			lore = record.Lore,
			state = record.State,
			selectedByUserId = record.SelectedByUserId,
			takenByUserId = record.TakenByUserId,
		})
	end

	return {
		phaseActive = self._phaseActive,
		remainingSeconds = self._remainingSeconds,
		nexos = nexos,
	}
end

function NexoService:_broadcastSnapshot()
	self.Client.NexoSnapshotChanged:FireAll(self:_createSnapshot())
end

function NexoService:_releasePreviewForPlayer(player: Player, exceptNexoId: string?)
	local currentId = self._previewByPlayer[player]
	if currentId == nil or currentId == exceptNexoId then
		return
	end

	local record = self._nexos[currentId] :: NexoRecord?
	if record ~= nil and record.State == NexoConfig.States.Selected and record.SelectedByUserId == player.UserId then
		record.State = NexoConfig.States.Available
		record.SelectedByUserId = nil
	end

	self._previewByPlayer[player] = nil
end

function NexoService:_assignRecordToPlayer(player: Player, record: NexoRecord, automatic: boolean)
	record.State = NexoConfig.States.Taken
	record.SelectedByUserId = nil
	record.TakenByUserId = player.UserId
	self._assignedByPlayer[player] = record.Id
	self._previewByPlayer[player] = nil

	self.Client.NexoAssigned:Fire(player, {
		nexoId = record.Id,
		displayName = record.DisplayName,
		automatic = automatic,
	})
end

function NexoService:_startTimer(token: number)
	task.spawn(function()
		while self._phaseActive and self._phaseToken == token and self._remainingSeconds > 0 do
			task.wait(1)
			if not self._phaseActive or self._phaseToken ~= token then
				return
			end

			self._remainingSeconds -= 1
			self.Client.NexoTimerChanged:FireAll(self._remainingSeconds)
		end

		if self._phaseActive and self._phaseToken == token then
			self:_assignFallbacks()
			self:_finishSelection()
		end
	end)
end

function NexoService:_getAvailableRecords(): { NexoRecord }
	local available = {}

	for _, nexoId in self._nexoOrder do
		local record = self._nexos[nexoId] :: NexoRecord
		if record.State == NexoConfig.States.Available then
			table.insert(available, record)
		end
	end

	return available
end

function NexoService:_getAnyRecords(): { NexoRecord }
	local records = {}

	for _, nexoId in self._nexoOrder do
		table.insert(records, self._nexos[nexoId])
	end

	return records
end

function NexoService:_pickRecord(records: { NexoRecord }): NexoRecord?
	if #records <= 0 then
		return nil
	end

	return records[self._random:NextInteger(1, #records)]
end

function NexoService:_assignFallbacks()
	for _, player in Players:GetPlayers() do
		if self._assignedByPlayer[player] ~= nil then
			continue
		end

		local preferredRecord = nil
		local previewId = self._previewByPlayer[player]
		if previewId ~= nil then
			local previewRecord = self._nexos[previewId] :: NexoRecord?
			if previewRecord ~= nil and previewRecord.State ~= NexoConfig.States.Taken then
				preferredRecord = previewRecord
			end
		end

		local record = preferredRecord
			or self:_pickRecord(self:_getAvailableRecords())
			or self:_pickRecord(self:_getAnyRecords())
		if record == nil then
			continue
		end

		if record.State ~= NexoConfig.States.Taken then
			self:_assignRecordToPlayer(player, record, true)
		else
			self._assignedByPlayer[player] = record.Id
			self.Client.NexoAssigned:Fire(player, {
				nexoId = record.Id,
				displayName = record.DisplayName,
				automatic = true,
			})
		end
	end

	self:_broadcastSnapshot()
end

function NexoService:_finishSelection()
	if not self._phaseActive then
		return
	end

	self._phaseActive = false
	self._phaseToken += 1
	self:_broadcastSnapshot()

	if self._gameService ~= nil then
		self._gameService:FinishNexoSelection({
			Reason = "NexoSelectionComplete",
		})
	end

	self.Client.NexoSelectionEnded:FireAll(self:_createSnapshot())
end

function NexoService:_handlePlayerRemoving(player: Player)
	self:_releasePreviewForPlayer(player)
	self._assignedByPlayer[player] = nil
	self._previewByPlayer[player] = nil
	self:_broadcastSnapshot()
end

function NexoService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._phaseActive = false
	self._phaseToken += 1
	self._trove:Destroy()
end

return NexoService
