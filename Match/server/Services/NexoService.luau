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
	RootPart: BasePart,
	HexPart: BasePart,
	TerritoryState: string?,
	DisplayName: string,
	Lore: string,
	State: string,
	IsActive: boolean,
	HP: number,
	MaxHP: number,
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

local function getNexoRootPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end

	if not instance:IsA("Model") then
		return instance:FindFirstChildWhichIsA("BasePart", true)
	end

	local namedRoot = instance:FindFirstChild(NexoConfig.RootPartName, true)
	if namedRoot ~= nil and namedRoot:IsA("BasePart") then
		return namedRoot
	end

	return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
end

local function getHexState(hexPart: BasePart): string?
	local state = hexPart:GetAttribute(NexoConfig.HexStateAttribute)
	return if typeof(state) == "string" and state ~= "" then state else nil
end

local function isPositiveFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value > 0 and value == value and math.abs(value) < math.huge
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
	self._selectionStarted = false
	self._random = Random.new()
	self._buildService = nil
	self._gameService = nil
	self._resourceService = nil
end

function NexoService:KnitStart()
	self._buildService = Knit.GetService("BuildService")
	self._gameService = Knit.GetService("GameService")
	self._resourceService = Knit.GetService("MatchResourceService")

	self._trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self:_handlePlayerRemoving(player)
	end))

	self._trove:Add(Players.PlayerAdded:Connect(function()
		task.defer(function()
			if self._destroyed or self._selectionStarted or #self._nexoOrder <= 0 then
				return
			end

			self:StartNexoSelection()
		end)
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
			local rootPart = getNexoRootPart(instance)
			if rootPart == nil then
				warn(("[NexoService] Nexo %s has no root BasePart"):format(instance:GetFullName()))
				continue
			end

			local hexPart = self:_resolveHexPartBelow(rootPart, taggedHexes)
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
				RootPart = rootPart,
				HexPart = hexPart,
				TerritoryState = getHexState(hexPart),
				DisplayName = displayName,
				Lore = getLore(displayName, instance),
				State = NexoConfig.States.Available,
				IsActive = false,
				HP = NexoConfig.HP,
				MaxHP = NexoConfig.HP,
				SelectedByUserId = nil,
				TakenByUserId = nil,
			}
			instance:SetAttribute("HP", NexoConfig.HP)
			instance:SetAttribute("MaxHP", NexoConfig.HP)
			instance:SetAttribute("NexoActive", false)
		end
	end

	print(("[Server] Tags leidos: %d"):format(#allTags))
	print(("[Server] Nexos encontrados: %d -> %s"):format(#self._nexoOrder, table.concat(foundNames, ", ")))
	print(("[Server] Hexagonos bloqueados: %s"):format(table.concat(blockedCoords, ", ")))
	self:_broadcastSnapshot()
end

function NexoService:StartNexoSelection(): boolean
	if self._selectionStarted then
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
	self._selectionStarted = true
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

	if record.HP <= 0 then
		return { ok = false, reason = "Destroyed" }
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

	if record.HP <= 0 then
		return { ok = false, reason = "Destroyed" }
	end

	if record.State == NexoConfig.States.Selected and record.SelectedByUserId ~= player.UserId then
		return { ok = false, reason = "SelectedByOther" }
	end

	self:_assignRecordToPlayer(player, record, false)
	self:_broadcastSnapshot()

	return { ok = true }
end

function NexoService:GetAssignedRecord(player: Player): NexoRecord?
	local nexoId = self._assignedByPlayer[player]
	return if nexoId ~= nil then self._nexos[nexoId] else nil
end

function NexoService:HasActiveNexo(player: Player): boolean
	local record = self:GetAssignedRecord(player)
	return record ~= nil and record.IsActive and record.HP > 0
end

function NexoService:GetActiveTerritoryState(player: Player): (string?, string?)
	local record = self:GetAssignedRecord(player)
	if record == nil or not record.IsActive or record.HP <= 0 then
		return nil, "NoActiveNexo"
	end

	if record.TerritoryState == nil then
		return nil, "MissingNexoState"
	end

	return record.TerritoryState, nil
end

function NexoService:DamageAssignedNexo(player: Player, damage: any): { ok: boolean, reason: string?, hp: number? }
	local record = self:GetAssignedRecord(player)
	if record == nil then
		return { ok = false, reason = "MissingNexo" }
	end

	return self:_damageRecord(record, damage)
end

function NexoService:DamageNexo(target: any, damage: any): { ok: boolean, reason: string?, hp: number? }
	local record = nil
	if typeof(target) == "string" then
		record = self._nexos[target]
	elseif typeof(target) == "Instance" then
		for _, nexoId in self._nexoOrder do
			local current = self._nexos[nexoId] :: NexoRecord
			if target == current.Instance or target == current.RootPart or target:IsDescendantOf(current.Instance) then
				record = current
				break
			end
		end
	end

	if record == nil then
		return { ok = false, reason = "MissingNexo" }
	end

	return self:_damageRecord(record, damage)
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
			rootPart = record.RootPart,
			hexPart = record.HexPart,
			territoryState = record.TerritoryState,
			displayName = record.DisplayName,
			lore = record.Lore,
			state = record.State,
			active = record.IsActive,
			hp = record.HP,
			maxHp = record.MaxHP,
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
	record.IsActive = record.HP > 0
	self._assignedByPlayer[player] = record.Id
	self._previewByPlayer[player] = nil
	record.Instance:SetAttribute("NexoActive", record.IsActive)

	if self._resourceService ~= nil then
		self._resourceService:SetNexoActive(player, record.IsActive)
	end

	self.Client.NexoAssigned:Fire(player, {
		nexoId = record.Id,
		displayName = record.DisplayName,
		automatic = automatic,
	})
end

function NexoService:_damageRecord(record: NexoRecord, damage: any): { ok: boolean, reason: string?, hp: number? }
	if not isPositiveFiniteNumber(damage) then
		return { ok = false, reason = "InvalidDamage" }
	end

	if record.HP <= 0 then
		return { ok = true, hp = 0 }
	end

	record.HP = math.max(0, record.HP - damage)
	record.Instance:SetAttribute("HP", record.HP)

	if record.HP <= 0 then
		self:_deactivateRecord(record)
	end

	self:_broadcastSnapshot()
	return { ok = true, hp = record.HP }
end

function NexoService:_deactivateRecord(record: NexoRecord)
	if not record.IsActive then
		return
	end

	record.IsActive = false
	record.Instance:SetAttribute("NexoActive", false)

	local userId = record.TakenByUserId
	if userId == nil then
		return
	end

	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return
	end

	if self._resourceService ~= nil then
		self._resourceService:SetNexoActive(player, false)
	end

	if self._gameService ~= nil then
		self._gameService:DefeatPlayer(player, {
			Reason = "NexoDestroyed",
			NexoId = record.Id,
		})
	end
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
			if
				previewRecord ~= nil
				and previewRecord.State == NexoConfig.States.Selected
				and previewRecord.SelectedByUserId == player.UserId
			then
				preferredRecord = previewRecord
			end
		end

		local record = preferredRecord or self:_pickRecord(self:_getAvailableRecords())
		if record == nil then
			warn(("[NexoService] No available Nexo for %s during automatic assignment"):format(player.Name))
			continue
		end

		self:_assignRecordToPlayer(player, record, true)
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
