local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local IconFrame = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("IconFrame"))
local Panel = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Panel"))
local ProgressBar = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("ProgressBar"))
local TacticalButton = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("TacticalButton"))
local Text = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Text"))
local UIHelpers = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("UIHelpers"))

local px = UITheme.sp
local colors = UITheme.Colors
local radii = UITheme.Radii
local sizes = UITheme.Sizes
local spacing = UITheme.Spacing
local textSizes = UITheme.TextSizes
local transparency = UITheme.Transparency

local function CompactStat(props)
	local compact = props.compact == true

	return React.createElement("Frame", {
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, px(if compact then 22 else 26)),
		BackgroundTransparency = 1,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(spacing.Sm)),
		}),
		Indicator = React.createElement("Frame", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(px(4), px(if compact then 12 else 15)),
			BackgroundColor3 = props.accent or colors.Stroke,
			BorderSizePixel = 0,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = radii.Circle,
			}),
		}),
		Label = React.createElement(Text, {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, 0), -- Force automatic width to avoid stretching out
			AutomaticSize = Enum.AutomaticSize.XY,
			variant = "Label",
			Text = props.label or "",
			TextColor3 = colors.Text, -- Brighter and high visibility
			TextSize = if compact then textSizes.Small else textSizes.Button,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Value = React.createElement(Text, {
			LayoutOrder = 3,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			variant = "Mono",
			Text = props.value or "",
			TextColor3 = colors.Text,
			TextSize = if compact then textSizes.Small else textSizes.Button,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

local function SeparatorLine(layoutOrder: number)
	return React.createElement("Frame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, px(1)),
		BackgroundColor3 = colors.Stroke,
		BackgroundTransparency = 0.45, -- Highly visible crisp gray separator
		BorderSizePixel = 0,
	})
end

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

	return React.createElement("Frame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, px(if compact then 30 else 36)),
		BackgroundTransparency = 1,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(spacing.Xxs)),
		}),
		Header = React.createElement("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, px(if compact then 14 else 18)),
			BackgroundTransparency = 1,
		}, {
			Label = React.createElement(Text, {
				Size = UDim2.fromScale(0.5, 1),
				variant = "Label",
				Text = string.upper(displayName),
				TextColor3 = colors.Text, -- Brighter and high visibility
				TextSize = if compact then textSizes.Small else textSizes.Button,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Value = React.createElement(Text, {
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.5, 1),
				variant = "Mono",
				Text = `{hp} / {maxHp}`,
				TextColor3 = accent,
				TextSize = if compact then textSizes.Small else textSizes.Button,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}),
		Track = React.createElement(ProgressBar, {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, px(if compact then 4 else 5)),
			progress = ratio,
			fillColor = accent,
		}),
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

local function rosterDiplomacyActions(props)
	local state = props.state
	if state == nil or state.userId ~= props.userId then
		return nil
	end

	local compact = props.compact == true
	local pendingBreakEndsAt = state.pendingBreakEndsAt
	local actionLabel = state.actionLabel or "ALIANZA"
	local actionEnabled = state.actionEnabled == true
	if typeof(pendingBreakEndsAt) == "number" then
		local remainingSeconds = math.max(0, math.ceil(pendingBreakEndsAt - os.clock()))
		actionLabel = `ROMPIENDO {remainingSeconds}s`
		actionEnabled = false
	end

	return React.createElement(Panel, {
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(px(if compact then 132 else 152), 0),
		backgroundColor = colors.Panel,
		backgroundTransparency = transparency.PanelSoft,
		strokeColor = if state.isAllied then colors.Red else colors.Amber,
		strokeTransparency = transparency.StrokeStrong,
		padding = {
			Y = spacing.Xl,
			X = spacing.Xl,
		},
		layout = Enum.FillDirection.Vertical,
		gap = spacing.Lg,
		Active = true,
		children = {
			Action = React.createElement(TacticalButton, {
				LayoutOrder = 1,
				fullWidth = true,
				height = sizes.MinTouch,
				label = actionLabel,
				accent = if state.actionKind == "Break" or state.actionKind == "BreakPending"
					then colors.Red
					else colors.Green,
				enabled = actionEnabled,
				TextSize = if compact then textSizes.ButtonSmall else textSizes.Button,
				onActivated = function()
					if props.onAction ~= nil then
						props.onAction(props.userId)
					end
				end,
			}),
			Close = React.createElement(TacticalButton, {
				LayoutOrder = 2,
				fullWidth = true,
				height = sizes.MinTouch,
				label = "CERRAR",
				accent = colors.Stroke,
				TextSize = if compact then textSizes.ButtonSmall else textSizes.Button,
				onActivated = props.onClose,
			}),
		},
	})
end

local function playerPip(props)
	local playerCard = props.playerCard
	local compact = props.compact == true
	local accent = getRosterColor(props.diplomacySnapshot, playerCard.userId)
	local image = if typeof(playerCard.thumbnail) == "string" then playerCard.thumbnail else ""
	local avatarSize = if compact then sizes.AvatarCompact else sizes.Avatar
	local imageSize = if compact then sizes.AvatarImageCompact else sizes.AvatarImage
	local isLocalPlayer = playerCard.userId == props.localUserId
	local canSelect = not isLocalPlayer
	local selected = props.rosterDiplomacy ~= nil and props.rosterDiplomacy.userId == playerCard.userId

	return React.createElement("Frame", {
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(px(if selected then (if compact then 132 else 152) else avatarSize), 0),
		BackgroundTransparency = transparency.Clear,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(spacing.Md)),
		}),
		Button = React.createElement("TextButton", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(px(avatarSize), px(avatarSize)),
			BackgroundTransparency = transparency.Clear,
			BorderSizePixel = 0,
			AutoButtonColor = canSelect,
			Active = canSelect,
			Text = "",
			[React.Event.Activated] = if canSelect and props.onSelect ~= nil
				then function()
					props.onSelect(playerCard.userId)
				end
				else nil,
		}, {
			Avatar = React.createElement(IconFrame, {
				Size = UDim2.fromScale(1, 1),
				backgroundColor = if selected then colors.PanelFacet else colors.PanelRaised,
				backgroundTransparency = transparency.Solid,
				strokeColor = accent,
				strokeThickness = if selected then UITheme.Strokes.Avatar + 1 else UITheme.Strokes.Avatar,
				strokeTransparency = if selected then transparency.Solid else transparency.PanelLight,
				radius = radii.Circle,
				image = image,
				imageColor = colors.Text,
				iconSize = imageSize,
				iconRadius = radii.Circle,
			}),
		}),
		Actions = rosterDiplomacyActions({
			userId = playerCard.userId,
			state = props.rosterDiplomacy,
			compact = compact,
			onAction = props.onAction,
			onClose = props.onClose,
		}),
	})
end

local function topRoster(props)
	local compact = props.compact == true
	local children = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(if compact then spacing.Md else spacing.XXl)),
		}),
	}

	local playerCards = if type(props.playerCards) == "table" then props.playerCards else {}
	for index = 1, #playerCards do
		children[`Player{index}`] = playerPip({
			LayoutOrder = index,
			playerCard = playerCards[index],
			diplomacySnapshot = props.diplomacySnapshot,
			rosterDiplomacy = props.rosterDiplomacy,
			localUserId = props.localUserId,
			compact = compact,
			onSelect = props.onSelectPlayer,
			onAction = props.onAction,
			onClose = props.onClose,
		})
	end

	return React.createElement(Panel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, px(if compact then spacing.Sm else spacing.Wide)),
		AutomaticSize = Enum.AutomaticSize.XY,
		backgroundColor = colors.Panel,
		backgroundTransparency = transparency.PanelSoft,
		strokeColor = colors.Amber, -- Glowing Amber stroke to highlight current match status/timer
		strokeTransparency = transparency.StrokeStrong,
		gradientMid = colors.PanelFacetCold,
		padding = {
			Y = if compact then spacing.Xs else spacing.Sm,
			X = if compact then spacing.Lg else spacing.Wide,
		},
		layout = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		gap = if compact then spacing.Md else spacing.XXl,
		Active = false,
		children = {
			Score = React.createElement(Text, {
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				variant = "Mono",
				Text = "3VS3",
				TextColor3 = colors.Amber,
				TextSize = if compact then textSizes.ButtonSmall else textSizes.Button,
			}),
			Separator = React.createElement("Frame", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(px(1), px(if compact then 12 else 16)),
				BackgroundColor3 = colors.Stroke,
				BackgroundTransparency = transparency.StrokeMuted,
				BorderSizePixel = 0,
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
			then UDim2.fromOffset(px(spacing.Lg), px(sizes.ButtonCompactHeight + spacing.Loose))
			else UDim2.fromOffset(px(spacing.Wide), px(sizes.UnitSelectionChip + spacing.Sm)),
		AutomaticSize = Enum.AutomaticSize.XY,
		backgroundColor = Color3.fromRGB(0, 0, 0), -- Pure black background for the overlay
		backgroundTransparency = 0, -- Gradient will control the transparency!
		stroke = false, -- No border contour
		gradient = false, -- No default multi-color facet gradient
		padding = if compact then spacing.Md else spacing.XXl,
		layout = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		gap = if compact then spacing.Sm else spacing.Lg,
		Active = false,
		SizeConstraint = React.createElement("UISizeConstraint", {
			MinSize = if compact
				then Vector2.new(px(sizes.HudCompactMinWidth + 16), 0)
				else Vector2.new(px(sizes.HudMinWidth), 0),
			MaxSize = if compact
				then Vector2.new(px(sizes.HudCompactMaxWidth + 24), px(sizes.HudCompactMaxHeight))
				else Vector2.new(px(sizes.HudMaxWidth), px(sizes.HudMaxHeight)),
		}),
		children = {
			Money = React.createElement(CompactStat, {
				LayoutOrder = 1,
				label = "DINERO: ",
				value = tostring(gold),
				accent = colors.Amber,
				compact = compact,
			}),
			Sep1 = SeparatorLine(2),
			Population = React.createElement(CompactStat, {
				LayoutOrder = 3,
				label = "POBLACION: ",
				value = `{populationUsed}/{populationCap}`,
				accent = colors.Green,
				compact = compact,
			}),
			Sep2 = SeparatorLine(4),
			Date = React.createElement(CompactStat, {
				LayoutOrder = 5,
				label = "FECHA: ",
				value = formatDate(props.clock),
				accent = colors.Stroke,
				compact = compact,
			}),
			Sep3 = SeparatorLine(6),
			Nexo = nexoHealth(localNexo, 7, compact),

			HudGradient = React.createElement("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
				Rotation = 0,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.15), -- Nearly solid on the left edge (15% transparency)
					NumberSequenceKeypoint.new(0.65, 0.40), -- Smooth fade-out in the middle
					NumberSequenceKeypoint.new(1, 1), -- Fully transparent on the right
				}),
			}),
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
			rosterDiplomacy = props.rosterDiplomacy,
			localUserId = props.localUserId,
			compact = compact,
			onSelectPlayer = props.onSelectRosterPlayer,
			onAction = props.onRequestDiplomacyAction,
			onClose = props.onCloseRosterDiplomacy,
		}),
		LeftPanel = leftPanel,
	})
end

return MatchHud
