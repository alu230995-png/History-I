local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages:WaitForChild("React"))

local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local colors = UITheme.Colors

local function unitCard(unit, layoutOrder: number, onDeselect)
	local definition = ManpowerConfig.GetUnit(unit.UnitType)

	return React.createElement("TextButton", {
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(px(60), px(60)),
		BackgroundColor3 = colors.PanelRaised,
		BackgroundTransparency = 0.03,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = "",
		[React.Event.Activated] = function()
			onDeselect(unit.UnitId)
		end,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(3)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = colors.Text,
			Thickness = px(1),
			Transparency = 0.08,
		}),
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(px(32), px(32)),
			BackgroundTransparency = 1,
			Image = if definition ~= nil
				then definition.Icon or ManpowerConfig.PlaceholderIcon
				else ManpowerConfig.PlaceholderIcon,
			ImageColor3 = colors.Text,
			ScaleType = Enum.ScaleType.Fit,
		}),
		Label = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -px(4)),
			Size = UDim2.new(1, -px(6), 0, px(12)),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = if definition ~= nil then definition.DisplayName else unit.UnitType,
			TextColor3 = colors.MutedText,
			TextSize = px(7),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
	})
end

local function overflowCard(count: number, layoutOrder: number)
	return React.createElement("Frame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(px(60), px(60)),
		BackgroundColor3 = colors.PanelRaised,
		BackgroundTransparency = 0.03,
		BorderSizePixel = 0,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(3)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = colors.Amber,
			Thickness = px(1),
			Transparency = 0.1,
		}),
		Count = React.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = `+{count}`,
			TextColor3 = colors.Text,
			TextSize = px(18),
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
			CellPadding = UDim2.fromOffset(px(6), px(6)),
			CellSize = UDim2.fromOffset(px(60), px(60)),
		}),
	}

	for index = 1, visibleCards do
		local unit = units[index]
		cards[unit.UnitId] = unitCard(unit, index, props.onDeselect)
	end

	if overflowCount > 0 then
		cards.Overflow = overflowCard(overflowCount, 8)
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -px(22)),
		Size = UDim2.fromOffset(px(282), px(146)),
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Active = true,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(4)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = colors.Text,
			Thickness = px(1),
			Transparency = 0.18,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(8)),
			PaddingBottom = UDim.new(0, px(8)),
			PaddingLeft = UDim.new(0, px(8)),
			PaddingRight = UDim.new(0, px(8)),
		}),
		Cards = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, cards),
	})
end

return UnitSelectionBar
