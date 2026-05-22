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

local function MatchHud(props)
	local resources = props.resources
	local gold = getResourceNumber(resources, "Gold")
	local populationUsed = getResourceNumber(resources, "PopulationUsed")
	local populationCap = getResourceNumber(resources, "PopulationCap")

	return React.createElement("Frame", {
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
			MaxSize = Vector2.new(px(280), px(240)),
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
	})
end

return MatchHud
