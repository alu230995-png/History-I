local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local colors = UITheme.Colors

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

local function stat(label: string, value: string, accent: Color3, layoutOrder: number)
	return React.createElement("Frame", {
		LayoutOrder = layoutOrder,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = colors.PanelRaised,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Active = false,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(3)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = accent,
			Thickness = px(1),
			Transparency = 0.18,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(6)),
			PaddingBottom = UDim.new(0, px(6)),
			PaddingLeft = UDim.new(0, px(9)),
			PaddingRight = UDim.new(0, px(9)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(2)),
		}),
		Label = React.createElement("TextLabel", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = label,
			TextColor3 = colors.MutedText,
			TextSize = px(10),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Value = React.createElement("TextLabel", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = value,
			TextColor3 = colors.Text,
			TextSize = px(16),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

local function nexoHealth(nexo, layoutOrder: number)
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
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = colors.PanelRaised,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Active = false,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(3)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = accent,
			Thickness = px(1),
			Transparency = 0.18,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(6)),
			PaddingBottom = UDim.new(0, px(7)),
			PaddingLeft = UDim.new(0, px(9)),
			PaddingRight = UDim.new(0, px(9)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(4)),
		}),
		Label = React.createElement("TextLabel", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = string.upper(displayName),
			TextColor3 = colors.MutedText,
			TextSize = px(10),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Value = React.createElement("TextLabel", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = `{hp} / {maxHp}`,
			TextColor3 = colors.Text,
			TextSize = px(14),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Track = React.createElement("Frame", {
			LayoutOrder = 3,
			BackgroundColor3 = colors.Panel,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, px(8)),
		}, {
			TrackCorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, px(2)),
			}),
			Fill = React.createElement("Frame", {
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(ratio, 1),
			}, {
				FillCorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, px(2)),
				}),
			}),
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

local function playerPip(playerCard, diplomacySnapshot, layoutOrder: number)
	local accent = getRosterColor(diplomacySnapshot, playerCard.userId)
	local image = if typeof(playerCard.thumbnail) == "string" then playerCard.thumbnail else ""

	return React.createElement("Frame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(px(38), px(38)),
		BackgroundColor3 = colors.PanelRaised,
		BorderSizePixel = 0,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = accent,
			Thickness = px(2),
			Transparency = 0.02,
		}),
		Face = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(px(32), px(32)),
			BackgroundTransparency = 1,
			Image = image,
			ImageColor3 = colors.Text,
		}, {
			FaceCorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
	})
end

local function topRoster(props)
	local children = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(8)),
		}),
	}

	local playerCards = if type(props.playerCards) == "table" then props.playerCards else {}
	for index = 1, #playerCards do
		children[`Player{index}`] = playerPip(playerCards[index], props.diplomacySnapshot, index)
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, px(12)),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Active = false,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(4)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = colors.Stroke,
			Thickness = px(1),
			Transparency = 0.12,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(7)),
			PaddingBottom = UDim.new(0, px(7)),
			PaddingLeft = UDim.new(0, px(10)),
			PaddingRight = UDim.new(0, px(10)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(5)),
		}),
		Clock = React.createElement("TextLabel", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = formatDate(props.clock),
			TextColor3 = colors.Amber,
			TextSize = px(16),
		}),
		Score = React.createElement("TextLabel", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = "3VS3",
			TextColor3 = colors.Text,
			TextSize = px(12),
		}),
		Roster = React.createElement("Frame", {
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, children),
	})
end

local function MatchHud(props)
	local resources = props.resources
	local gold = getResourceNumber(resources, "Gold")
	local populationUsed = getResourceNumber(resources, "PopulationUsed")
	local populationCap = getResourceNumber(resources, "PopulationCap")
	local localNexo = findLocalNexo(props.nexoSnapshot, props.localUserId)

	local leftPanel = React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(px(12), px(64)),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Active = false,
	}, {
		Width = React.createElement("UISizeConstraint", {
			MinSize = Vector2.new(px(154), px(0)),
			MaxSize = Vector2.new(px(280), px(320)),
		}),
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(4)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = colors.Stroke,
			Thickness = px(1),
			Transparency = 0.08,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(8)),
			PaddingBottom = UDim.new(0, px(8)),
			PaddingLeft = UDim.new(0, px(8)),
			PaddingRight = UDim.new(0, px(8)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(6)),
		}),
		Money = stat("DINERO", tostring(gold), colors.Amber, 1),
		Population = stat("POBLACION", `{populationUsed} / {populationCap}`, colors.Green, 2),
		Date = stat("FECHA", formatDate(props.clock), colors.Stroke, 3),
		Nexo = nexoHealth(localNexo, 4),
	})

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
	}, {
		TopRoster = topRoster(props),
		LeftPanel = leftPanel,
	})
end

return MatchHud
