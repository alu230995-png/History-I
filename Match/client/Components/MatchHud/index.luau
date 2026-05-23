local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local IconFrame = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("IconFrame"))
local Panel = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Panel"))
local ProgressBar = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("ProgressBar"))
local StatTile = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("StatTile"))
local Text = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Text"))
local UIHelpers = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("UIHelpers"))

local px = UITheme.sp
local colors = UITheme.Colors
local radii = UITheme.Radii
local sizes = UITheme.Sizes
local spacing = UITheme.Spacing
local textSizes = UITheme.TextSizes
local transparency = UITheme.Transparency

local function getResourceNumber(resources, key: string): number
	local value = if resources ~= nil then resources[key] else nil
	return if typeof(value) == "number" then math.floor(value) else 0
end

local function formatDate(clock): string
	if clock == nil then
		return "01.01.1905"
	end

	local year = if typeof(clock.year) == "number" then math.floor(clock.year) else 1905
	local month = if typeof(clock.month) == "number" then math.floor(clock.month) else 1
	local day = if typeof(clock.day) == "number" then math.floor(clock.day) else 1
	return `{string.format("%02d", day)}.{string.format("%02d", month)}.{year}`
end

local function findLocalNexo(snapshot, localUserId: number?)
	if snapshot == nil or type(snapshot.nexos) ~= "table" or typeof(localUserId) ~= "number" then
		return nil
	end

	for _, nexo in snapshot.nexos do
		if nexo.takenByUserId == localUserId then
			return nexo
		end
	end

	return nil
end

local function getHealthAccent(ratio: number): Color3
	if ratio <= 0.25 then
		return colors.Red
	end

	if ratio <= 0.55 then
		return colors.Amber
	end

	return colors.Green
end

local function nexoHealth(nexo, layoutOrder: number, compact: boolean?)
	if nexo == nil then
		return nil
	end

	local hp = if typeof(nexo.hp) == "number" then math.max(0, math.floor(nexo.hp)) else 0
	local maxHp = if typeof(nexo.maxHp) == "number" and nexo.maxHp > 0 then math.floor(nexo.maxHp) else 0
	local ratio = if maxHp > 0 then math.clamp(hp / maxHp, 0, 1) else 0
	local accent = getHealthAccent(ratio)
	local displayName = if typeof(nexo.displayName) == "string" and nexo.displayName ~= ""
		then nexo.displayName
		else "NEXO"

	return React.createElement(Panel, {
		LayoutOrder = layoutOrder,
		AutomaticSize = Enum.AutomaticSize.XY,
		backgroundColor = colors.PanelRaised,
		backgroundTransparency = transparency.PanelSoft,
		strokeColor = accent,
		strokeTransparency = transparency.StrokeSoft,
		radius = radii.Control,
		padding = {
			Y = if compact then spacing.Sm else spacing.Xl,
			X = if compact then spacing.Xl else spacing.Xs + spacing.Lg,
		},
		layout = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		gap = spacing.Sm,
		children = {
			Label = React.createElement(Text, {
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				variant = "Label",
				Text = string.upper(displayName),
				TextSize = if compact then textSizes.Tiny else textSizes.Small,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Value = React.createElement(Text, {
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				variant = "Value",
				Text = `{hp} / {maxHp}`,
				TextSize = if compact then textSizes.ButtonSmall else textSizes.Body,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Track = React.createElement(ProgressBar, {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, px(sizes.HealthTrack)),
				progress = ratio,
				fillColor = accent,
			}),
		},
	})
end

local function getAllianceForUser(snapshot, userId: number?)
	if snapshot == nil or type(snapshot.alliances) ~= "table" or typeof(userId) ~= "number" then
		return nil
	end

	for _, alliance in snapshot.alliances do
		if type(alliance.members) ~= "table" then
			continue
		end

		for _, memberUserId in alliance.members do
			if memberUserId == userId then
				return alliance
			end
		end
	end

	return nil
end

local function getRosterColor(snapshot, userId: number): Color3
	local palette = if snapshot ~= nil and type(snapshot.colors) == "table" then snapshot.colors else nil
	local paletteCount = if palette ~= nil then #palette else 0
	if paletteCount <= 0 then
		return colors.Stroke
	end

	local alliance = getAllianceForUser(snapshot, userId)
	local colorIndex = if alliance ~= nil and typeof(alliance.colorIndex) == "number"
		then alliance.colorIndex
		else ((math.abs(userId) - 1) % paletteCount) + 1

	return palette[((colorIndex - 1) % paletteCount) + 1]
end

local function playerPip(playerCard, diplomacySnapshot, layoutOrder: number, compact: boolean?)
	local accent = getRosterColor(diplomacySnapshot, playerCard.userId)
	local image = if typeof(playerCard.thumbnail) == "string" then playerCard.thumbnail else ""
	local avatarSize = if compact then sizes.AvatarCompact else sizes.Avatar
	local imageSize = if compact then sizes.AvatarImageCompact else sizes.AvatarImage

	return React.createElement(IconFrame, {
		LayoutOrder = layoutOrder,
		width = avatarSize,
		height = avatarSize,
		backgroundColor = colors.PanelRaised,
		backgroundTransparency = transparency.Solid,
		strokeColor = accent,
		strokeThickness = UITheme.Strokes.Avatar,
		strokeTransparency = transparency.PanelLight,
		radius = radii.Circle,
		image = image,
		imageColor = colors.Text,
		iconSize = imageSize,
		iconRadius = radii.Circle,
	})
end

local function topRoster(props)
	local compact = props.compact == true
	local children = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(if compact then spacing.Md else spacing.XXl)),
		}),
	}

	local playerCards = if type(props.playerCards) == "table" then props.playerCards else {}
	for index = 1, #playerCards do
		children[`Player{index}`] = playerPip(playerCards[index], props.diplomacySnapshot, index, compact)
	end

	return React.createElement(Panel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, px(if compact then spacing.Lg else spacing.Wide)),
		AutomaticSize = Enum.AutomaticSize.XY,
		backgroundColor = colors.Panel,
		backgroundTransparency = transparency.PanelSoft,
		strokeColor = colors.Stroke,
		strokeTransparency = transparency.Stroke,
		padding = {
			Y = if compact then spacing.Md else spacing.Xl,
			X = if compact then spacing.Xl else spacing.Panel,
		},
		layout = Enum.FillDirection.Vertical,
		gap = if compact then spacing.Xs else spacing.Md,
		Active = false,
		children = {
			Clock = React.createElement(Text, {
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				variant = "Value",
				Text = formatDate(props.clock),
				TextColor3 = colors.Amber,
				TextSize = if compact then textSizes.Button else textSizes.Value,
			}),
			Score = React.createElement(Text, {
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				variant = "Title",
				Text = "3VS3",
				TextSize = if compact then textSizes.Small else textSizes.Button,
			}),
			Roster = React.createElement("Frame", {
				LayoutOrder = 3,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = transparency.Clear,
			}, children),
		},
	})
end

local function MatchHud(props)
	local viewportSize = UIHelpers.getViewportSize(props)
	local compact = viewportSize.X <= UITheme.Breakpoints.CompactWidth
		or viewportSize.Y <= UITheme.Breakpoints.CompactHeight
	local resources = props.resources
	local gold = getResourceNumber(resources, "Gold")
	local populationUsed = getResourceNumber(resources, "PopulationUsed")
	local populationCap = getResourceNumber(resources, "PopulationCap")
	local localNexo = findLocalNexo(props.nexoSnapshot, props.localUserId)

	local leftPanel = React.createElement(Panel, {
		AnchorPoint = Vector2.new(0, 0),
		Position = if compact
			then UDim2.fromOffset(px(spacing.XXl), px(sizes.ButtonLargeHeight))
			else UDim2.fromOffset(px(spacing.Wide), px(sizes.UnitSelectionChip + spacing.Sm)),
		AutomaticSize = Enum.AutomaticSize.XY,
		backgroundColor = colors.Panel,
		backgroundTransparency = transparency.PanelMuted,
		strokeColor = colors.Stroke,
		strokeTransparency = transparency.StrokeStrong,
		padding = if compact then spacing.Lg else spacing.XXl,
		layout = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		gap = if compact then spacing.Sm else spacing.Lg,
		Active = false,
		SizeConstraint = React.createElement("UISizeConstraint", {
			MinSize = if compact
				then Vector2.new(px(sizes.HudCompactMinWidth), 0)
				else Vector2.new(px(sizes.HudMinWidth), 0),
			MaxSize = if compact
				then Vector2.new(px(sizes.HudCompactMaxWidth), px(sizes.HudCompactMaxHeight))
				else Vector2.new(px(sizes.HudMaxWidth), px(sizes.HudMaxHeight)),
		}),
		children = {
			Money = React.createElement(StatTile, {
				LayoutOrder = 1,
				label = "DINERO",
				value = tostring(gold),
				accent = colors.Amber,
				compact = compact,
			}),
			Population = React.createElement(StatTile, {
				LayoutOrder = 2,
				label = "POBLACION",
				value = `{populationUsed} / {populationCap}`,
				accent = colors.Green,
				compact = compact,
			}),
			Date = React.createElement(StatTile, {
				LayoutOrder = 3,
				label = "FECHA",
				value = formatDate(props.clock),
				accent = colors.Stroke,
				compact = compact,
			}),
			Nexo = nexoHealth(localNexo, 4, compact),
		},
	})

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = transparency.Clear,
		BorderSizePixel = 0,
		Active = false,
	}, {
		TopRoster = topRoster({
			clock = props.clock,
			playerCards = props.playerCards,
			diplomacySnapshot = props.diplomacySnapshot,
			compact = compact,
		}),
		LeftPanel = leftPanel,
	})
end

return MatchHud
