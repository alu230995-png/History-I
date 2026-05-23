local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages:WaitForChild("React"))

local BuildingConfig = require(Shared:WaitForChild("Constants"):WaitForChild("BuildingConfig"))
local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local IconFrame = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("IconFrame"))
local Panel = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Panel"))
local TacticalButton = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("TacticalButton"))
local Text = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Text"))
local UIHelpers = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("UIHelpers"))

local px = UITheme.sp
local colors = UITheme.Colors
local sizes = UITheme.Sizes
local spacing = UITheme.Spacing
local textSizes = UITheme.TextSizes
local transparency = UITheme.Transparency

local function getGold(resources): number
	if resources ~= nil and typeof(resources.Gold) == "number" then
		return resources.Gold
	end

	return 0
end

local function createBuildingItems()
	local items = {}

	for _, buildingType in BuildingConfig.MenuOrder do
		local definition = BuildingConfig.Buildings[buildingType]
		if definition ~= nil then
			table.insert(items, {
				Type = buildingType,
				DisplayName = definition.DisplayName or string.upper(buildingType),
				Gold = definition.Gold or 0,
				Icon = definition.Icon or UITheme.Assets.PlaceholderIcon,
			})
		end
	end

	return items
end

local BUILDING_ITEMS = table.freeze(createBuildingItems())

local function BuildingCard(props)
	local item = props.item
	local resources = props.resources
	local onSelect = props.onSelectBuilding
	local gold = getGold(resources)
	local canAfford = gold >= item.Gold
	local compact = props.compact == true
	local textColor = if canAfford then colors.Text else colors.MutedText

	return React.createElement("TextButton", {
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = if canAfford then colors.PanelRaised else colors.PanelDim,
		BackgroundTransparency = if canAfford then transparency.PanelLight else transparency.PanelDim,
		BorderSizePixel = 0,
		AutoButtonColor = canAfford,
		Text = "",
		Active = canAfford,
		[React.Event.Activated] = if canAfford
			then function()
				onSelect(item.Type)
			end
			else nil,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UITheme.Radii.Panel,
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if canAfford then colors.Stroke else colors.Red,
			Thickness = px(UITheme.Strokes.Thin),
			Transparency = if canAfford then transparency.StrokeSoft else transparency.StrokeStrong,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(spacing.Panel)),
			PaddingBottom = UDim.new(0, px(spacing.Panel)),
			PaddingLeft = UDim.new(0, px(spacing.Panel)),
			PaddingRight = UDim.new(0, px(spacing.Panel)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(spacing.XXl)),
		}),
		Name = React.createElement(Text, {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, if compact then px(spacing.Bottom + spacing.Xxs) else px(sizes.AvatarImage)),
			variant = "Title",
			Text = string.upper(item.DisplayName),
			TextColor3 = textColor,
			TextSize = if compact then textSizes.ButtonSmall else textSizes.Button,
			TextWrapped = true,
		}),
		IconContainer = React.createElement(IconFrame, {
			LayoutOrder = 2,
			width = if compact then sizes.IconContainerCompactWidth else sizes.IconContainerWidth,
			height = if compact then sizes.IconContainerCompactHeight else sizes.IconContainerHeight,
			backgroundColor = colors.Panel,
			backgroundTransparency = transparency.PanelMuted,
			strokeColor = colors.Stroke,
			strokeTransparency = transparency.StrokeMuted,
			image = item.Icon,
			imageColor = textColor,
			imageTransparency = if canAfford then transparency.Solid else transparency.IconDisabled,
			iconSize = if compact then sizes.IconCardCompact else sizes.IconCard,
		}),
		Price = React.createElement(Text, {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, if compact then px(textSizes.Heading) else px(spacing.Bottom)),
			variant = "Value",
			Text = `{item.Gold} ORO`,
			TextColor3 = if canAfford then colors.Amber else colors.Red,
			TextSize = if compact then textSizes.ButtonSmall else textSizes.Meta,
		}),
	})
end

local function NexoBuildMenu(props)
	if not props.visible then
		return nil
	end

	local viewportSize = UIHelpers.getViewportSize(props)
	local compact = UIHelpers.isCompact(props)
	local panelWidth = if compact
		then math.max(
			px(sizes.NexoBuildCompactMinWidth),
			math.min(px(sizes.NexoBuildCompactMaxWidth), viewportSize.X - px(spacing.Bottom + spacing.Xxs))
		)
		else px(sizes.NexoBuildPanelWidth)
	local panelHeight = if compact
		then math.max(
			px(sizes.NexoBuildCompactMinHeight),
			math.min(px(sizes.NexoBuildCompactMaxHeight), viewportSize.Y - px(sizes.ButtonWideWidth + spacing.Lg))
		)
		else px(sizes.NexoBuildPanelHeight)
	local headerHeight = if compact then px(sizes.ButtonCompactHeight + spacing.Xxs) else px(sizes.ButtonLargeHeight)
	local scrollHeight = math.max(
		px(sizes.ButtonBuildMaxWidth + spacing.Bottom),
		panelHeight - headerHeight - px(sizes.IconContainerCompactWidth + spacing.Sm)
	)
	local cellHeight = if compact then px(sizes.BuildingCardCompactHeight) else px(sizes.BuildingCardHeight)

	local children = {
		Grid = React.createElement("UIGridLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = if compact then 1 else 2,
			CellPadding = UDim2.fromOffset(px(spacing.XXl), if compact then px(spacing.Lg) else px(spacing.XXl)),
			CellSize = if compact
				then UDim2.new(1, -px(spacing.Lg), 0, cellHeight)
				else UDim2.new(0.5, -px(spacing.Sm), 0, cellHeight),
		}),
		Padding = React.createElement("UIPadding", {
			PaddingRight = UDim.new(0, px(spacing.Lg)),
		}),
	}

	for index, item in BUILDING_ITEMS do
		children[item.Type] = React.createElement(BuildingCard, {
			LayoutOrder = index,
			item = item,
			resources = props.resources,
			compact = compact,
			onSelectBuilding = props.onSelectBuilding,
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.Scrim,
		BackgroundTransparency = transparency.ScrimStrong,
		BorderSizePixel = 0,
		Active = true,
	}, {
		NexoBuildPanel = React.createElement(Panel, {
			AnchorPoint = if compact then Vector2.new(1, 0.5) else Vector2.new(0.5, 0.5),
			Position = if compact then UDim2.new(1, -px(spacing.Wide), 0.5, 0) else UDim2.fromScale(0.5, 0.5),
			Size = if compact
				then UDim2.fromOffset(panelWidth, panelHeight)
				else UDim2.new(1, -px(spacing.Bottom + spacing.Xxs), 0, px(sizes.NexoBuildPanelHeight)),
			backgroundColor = colors.Panel,
			backgroundTransparency = transparency.PanelLight,
			strokeColor = colors.Amber,
			strokeTransparency = transparency.StrokeStrong,
			padding = spacing.Loose,
			layout = Enum.FillDirection.Vertical,
			gap = spacing.Panel,
			SizeConstraint = React.createElement("UISizeConstraint", {
				MinSize = if compact
					then Vector2.new(px(sizes.NexoBuildCompactMinWidth), px(sizes.NexoBuildCompactMinHeight))
					else Vector2.new(
						px(sizes.UnitSelectionPanelWidth + spacing.Panel),
						px(sizes.NexoBuildPanelHeight)
					),
				MaxSize = if compact
					then Vector2.new(panelWidth, panelHeight)
					else Vector2.new(px(sizes.NexoBuildPanelWidth), px(sizes.NexoBuildPanelHeight)),
			}),
			children = {
				Header = React.createElement("Frame", {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, headerHeight),
					BackgroundTransparency = transparency.Clear,
				}, {
					Title = React.createElement(Text, {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.new(1, -px(sizes.ButtonLargeWidth + spacing.XXl), 1, 0),
						variant = "Title",
						Text = "NEXO",
						TextSize = textSizes.HudTitle,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Gold = React.createElement(Text, {
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, -px(sizes.ButtonLargeWidth + spacing.XXl), 0, px(textSizes.Heading)),
						variant = "Mono",
						Text = `{getGold(props.resources)} ORO`,
						TextColor3 = colors.Amber,
						TextSize = textSizes.Button,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Close = React.createElement(TacticalButton, {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						width = if compact then sizes.ButtonSmallWidth else sizes.ButtonMediumWidth,
						height = if compact then sizes.ButtonCompactHeight else sizes.ButtonHeight,
						label = "CERRAR",
						accent = colors.Red,
						TextSize = if compact then textSizes.ButtonSmall else textSizes.Button,
						onActivated = props.onClose,
					}),
				}),
				Scroll = React.createElement("ScrollingFrame", {
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, scrollHeight),
					BackgroundTransparency = transparency.Clear,
					BorderSizePixel = 0,
					Active = true,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.fromScale(0, 0),
					ScrollBarThickness = px(spacing.Sm),
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ScrollingEnabled = true,
				}, children),
			},
		}),
	})
end

return NexoBuildMenu
