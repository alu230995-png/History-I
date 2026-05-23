local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages:WaitForChild("React"))

local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local Panel = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Panel"))
local Text = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Text"))
local UnitChip = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("UnitChip"))

local px = UITheme.sp
local colors = UITheme.Colors
local sizes = UITheme.Sizes
local spacing = UITheme.Spacing
local textSizes = UITheme.TextSizes
local transparency = UITheme.Transparency

local function unitCard(unit, layoutOrder: number, onDeselect)
	local definition = ManpowerConfig.GetUnit(unit.UnitType)

	return React.createElement(UnitChip, {
		LayoutOrder = layoutOrder,
		size = sizes.UnitSelectionChip,
		iconSize = sizes.IconCardCompact,
		label = if definition ~= nil then definition.DisplayName else unit.UnitType,
		icon = if definition ~= nil
			then definition.Icon or ManpowerConfig.PlaceholderIcon
			else ManpowerConfig.PlaceholderIcon,
		TextSize = textSizes.Unit,
		onActivated = function()
			onDeselect(unit.UnitId)
		end,
	})
end

local function overflowCard(count: number, layoutOrder: number)
	return React.createElement("Frame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(px(sizes.UnitSelectionChip), px(sizes.UnitSelectionChip)),
		BackgroundColor3 = colors.PanelRaised,
		BackgroundTransparency = transparency.PanelLight,
		BorderSizePixel = 0,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UITheme.Radii.Control,
		}),
		Stroke = React.createElement("UIStroke", {
			Color = colors.Amber,
			Thickness = px(UITheme.Strokes.Thin),
			Transparency = transparency.StrokeStrong,
		}),
		Count = React.createElement(Text, {
			Size = UDim2.fromScale(1, 1),
			variant = "Title",
			Text = `+{count}`,
			TextSize = textSizes.Heading,
		}),
	})
end

local function UnitSelectionBar(props)
	local units = if type(props.units) == "table" then props.units else {}
	if #units <= 0 then
		return nil
	end

	local visibleCards = math.min(#units, 8)
	local overflowCount = 0
	if #units > 8 then
		visibleCards = 7
		overflowCount = #units - 7
	end

	local cards = {
		Grid = React.createElement("UIGridLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = 4,
			CellPadding = UDim2.fromOffset(px(spacing.Lg), px(spacing.Lg)),
			CellSize = UDim2.fromOffset(px(sizes.UnitSelectionChip), px(sizes.UnitSelectionChip)),
		}),
	}

	for index = 1, visibleCards do
		local unit = units[index]
		cards[unit.UnitId] = unitCard(unit, index, props.onDeselect)
	end

	if overflowCount > 0 then
		cards.Overflow = overflowCard(overflowCount, 8)
	end

	return React.createElement(Panel, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -px(spacing.Bottom)),
		Size = UDim2.fromOffset(px(sizes.UnitSelectionPanelWidth), px(sizes.UnitSelectionPanelHeight)),
		backgroundColor = colors.Panel,
		backgroundTransparency = transparency.PanelSoft,
		strokeColor = colors.Text,
		strokeTransparency = transparency.StrokeSoft,
		padding = spacing.XXl,
		Active = true,
		children = {
			Cards = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = transparency.Clear,
			}, cards),
		},
	})
end

return UnitSelectionBar
