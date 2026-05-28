local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages:WaitForChild("React"))

local BuildingConfig = require(Shared:WaitForChild("Constants"):WaitForChild("BuildingConfig"))
local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local SelectionConfig = require(Shared:WaitForChild("Constants"):WaitForChild("SelectionConfig"))
local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local ProgressBar = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("ProgressBar"))
local TacticalButton = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("TacticalButton"))
local Text = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Text"))
local UIHelpers = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("UIHelpers"))
local UnitChip = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("UnitChip"))

local px = UITheme.sp
local colors = UITheme.Colors
local radii = UITheme.Radii
local sizes = UITheme.Sizes
local spacing = UITheme.Spacing
local textSizes = UITheme.TextSizes
local transparency = UITheme.Transparency
local panelConfig = SelectionConfig.Panel
local zIndexes = table.freeze({
	Overlay = 10,
	Panel = 11,
	Background = 1,
	Content = 2,
})

local function commandButton(
	label: string,
	order: number,
	accent: Color3,
	enabled: boolean,
	activated,
	compact: boolean?
)
	return React.createElement(TacticalButton, {
		LayoutOrder = order,
		width = if compact then sizes.CommandButtonCompactWidth else sizes.CommandButtonWidth,
		height = if compact then sizes.ButtonCompactHeight else panelConfig.MinTouchSize or sizes.MinTouch,
		label = label,
		accent = accent,
		enabled = enabled,
		backgroundColor = if enabled then colors.PanelFacet else colors.PanelDisabled,
		backgroundTransparency = transparency.Solid,
		gradientAccent = if enabled then accent else colors.PanelFacetCold,
		strokeTransparency = if enabled then transparency.StrokeStrong else transparency.Disabled,
		ZIndex = zIndexes.Content,
		TextSize = if compact then textSizes.Tiny + UITheme.Spacing.Hairline else textSizes.ButtonSmall,
		onActivated = activated,
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

local function unitCard(unit, order: number, onDeselect, compact: boolean?)
	local definition = ManpowerConfig.GetUnit(unit.UnitType)
	local displayName = if definition ~= nil then definition.DisplayName else unit.UnitType

	return React.createElement(UnitChip, {
		LayoutOrder = order,
		compact = compact,
		size = if compact then sizes.UnitChipCompact else sizes.UnitChip,
		iconSize = if compact then sizes.IconCompact else sizes.IconLarge,
		label = displayName,
		icon = if definition ~= nil
			then definition.Icon or ManpowerConfig.PlaceholderIcon
			else ManpowerConfig.PlaceholderIcon,
		TextSize = if compact then textSizes.Micro else textSizes.Unit,
		onActivated = function()
			onDeselect(unit.UnitId)
		end,
	})
end

local function unitStrip(units, onDeselect, compact: boolean?)
	if #units <= 0 then
		return nil
	end

	local children = {
		Grid = React.createElement("UIGridLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = if compact then spacing.Md else spacing.Lg,
			CellPadding = UDim2.fromOffset(
				if compact then px(spacing.Md) else px(spacing.Lg),
				if compact then px(spacing.Md) else px(spacing.Lg)
			),
			CellSize = if compact
				then UDim2.fromOffset(px(sizes.UnitChipCompact), px(sizes.UnitChipCompact))
				else UDim2.fromOffset(px(sizes.UnitChip), px(sizes.UnitChip)),
		}),
	}

	local visibleCount = math.min(#units, if compact then spacing.Sm else spacing.Lg)
	for index = 1, visibleCount do
		local unit = units[index]
		children[unit.UnitId] = unitCard(unit, index, onDeselect, compact)
	end

	if #units > visibleCount then
		children.Overflow = React.createElement("Frame", {
			LayoutOrder = spacing.Xl,
			Size = if compact
				then UDim2.fromOffset(px(sizes.UnitChipCompact), px(sizes.UnitChipCompact))
				else UDim2.fromOffset(px(sizes.UnitChip), px(sizes.UnitChip)),
			BackgroundColor3 = colors.PanelRaised,
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
				Text = `+{#units - visibleCount}`,
				TextSize = textSizes.Title,
			}),
		})
	end

	return React.createElement("Frame", {
		LayoutOrder = 4,
		Size = UDim2.new(
			1,
			0,
			0,
			if compact then px(sizes.UnitChip + spacing.Xxs) else px(sizes.UnitCardHeight + spacing.Panel)
		),
		BackgroundTransparency = transparency.Clear,
	}, children)
end

local function getQueueEntry(queue, index: number)
	if queue == nil or type(queue.Entries) ~= "table" then
		return nil
	end

	return queue.Entries[index]
end

local function queueSlot(entry, order: number, compact: boolean?)
	local definition = if entry ~= nil then ManpowerConfig.GetUnit(entry.UnitType) else nil
	local progress = if entry ~= nil and typeof(entry.Progress) == "number" then math.clamp(entry.Progress, 0, 1) else 0
	local slotWidth = if compact then sizes.QueueSlotCompactWidth else sizes.QueueSlotWidth
	local slotHeight = if compact then sizes.QueueSlotCompactHeight else sizes.QueueSlotHeight

	return React.createElement("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(px(slotWidth), px(slotHeight)),
		BackgroundColor3 = if entry ~= nil then colors.PanelRaised else colors.Panel,
		BackgroundTransparency = if entry ~= nil then transparency.Panel else transparency.PanelDim,
		BorderSizePixel = 0,
	}, {
		AspectRatio = React.createElement("UIAspectRatioConstraint", {
			AspectRatio = UITheme.AspectRatios.QueueSlot,
			DominantAxis = Enum.DominantAxis.Height,
		}),
		Corner = React.createElement("UICorner", {
			CornerRadius = UITheme.Radii.Control,
		}),
		LowPolyGradient = React.createElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, colors.PanelFacetCold),
				ColorSequenceKeypoint.new(0.62, if entry ~= nil then colors.PanelRaised else colors.Panel),
				ColorSequenceKeypoint.new(1, colors.PanelFacetDark),
			}),
			Rotation = -30,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, transparency.Facet),
				NumberSequenceKeypoint.new(1, transparency.FacetStrong),
			}),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if entry ~= nil then colors.Green else colors.Stroke,
			Thickness = px(UITheme.Strokes.Thin),
			Transparency = if entry ~= nil then transparency.StrokeSoft else transparency.Scrim,
		}),
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, px(spacing.Sm)),
			Size = if compact
				then UDim2.fromOffset(px(sizes.IconTiny), px(sizes.IconTiny))
				else UDim2.fromOffset(px(sizes.IconSmall), px(sizes.IconSmall)),
			BackgroundTransparency = transparency.Clear,
			Image = if definition ~= nil
				then definition.Icon or ManpowerConfig.PlaceholderIcon
				else ManpowerConfig.PlaceholderIcon,
			ImageColor3 = if entry ~= nil then colors.Text else colors.Stroke,
			ImageTransparency = if entry ~= nil then transparency.Solid else transparency.Ghost,
			ScaleType = Enum.ScaleType.Fit,
		}),
		Progress = React.createElement(ProgressBar, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -px(spacing.Xs)),
			Size = UDim2.new(1, -px(spacing.XXl), 0, px(sizes.ProgressThin)),
			progress = progress,
			fillColor = if entry ~= nil and entry.Ready == true then colors.Green else colors.Amber,
		}),
	})
end

local function productionButton(unitType: string, order: number, queueFull: boolean, onQueueUnit, compact: boolean?)
	local definition = ManpowerConfig.GetUnit(unitType)
	if definition == nil then
		return nil
	end

	local canQueue = not queueFull
	local label = if compact
		then `+ {string.sub(definition.DisplayName, 1, sizes.Progress)}`
		else `+ {definition.DisplayName}`
	return commandButton(label, order, colors.Amber, canQueue, function()
		onQueueUnit(unitType)
	end, compact)
end

local function buildingProduction(props)
	local productionUnits = props.productionUnits
	if type(productionUnits) ~= "table" or #productionUnits <= 0 or not props.canEdit then
		return nil
	end

	local queue = props.queue
	local compact = props.compact == true
	local count = if queue ~= nil and typeof(queue.Count) == "number" then queue.Count else 0
	local capacity = if queue ~= nil and typeof(queue.Capacity) == "number"
		then queue.Capacity
		else ManpowerConfig.QueueCapacity
	local queueFull = count >= capacity
	local queueChildren = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, if compact then px(spacing.Md) else px(spacing.Lg)),
		}),
	}

	for index = 1, ManpowerConfig.QueueCapacity do
		queueChildren[`Slot{index}`] = queueSlot(getQueueEntry(queue, index), index, compact)
	end

	return React.createElement("Frame", {
		LayoutOrder = 5,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = transparency.Clear,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(spacing.Xl)),
		}),
		Header = React.createElement(Text, {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, px(textSizes.Value)),
			variant = "Mono",
			Text = `{props.title or "PRODUCCION"} {count}/{capacity}`,
			TextColor3 = colors.Text, -- Brighter and high visibility
			TextSize = textSizes.Small,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Buttons = (function()
			local children = {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, if compact then px(spacing.Md) else px(spacing.Xl)),
				}),
			}
			for index, unitType in productionUnits do
				children[unitType] = productionButton(unitType, index, queueFull, props.onQueueUnit, compact)
			end
			return React.createElement("Frame", {
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = transparency.Clear,
			}, children)
		end)(),
		Queue = React.createElement("Frame", {
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = transparency.Clear,
		}, queueChildren),
	})
end

local function SelectionActionPanel(props)
	if props.visible ~= true then
		return nil
	end

	local units = if type(props.units) == "table" then props.units else {}
	local viewportSize = UIHelpers.getViewportSize(props)
	local compact = UIHelpers.isCompact(props)
	local panelWidth = if compact
		then math.max(
			px(sizes.CompactPanelMinWidth),
			math.min(px(sizes.CompactPanelWidth), viewportSize.X - px(spacing.Bottom + spacing.Xxs))
		)
		else px(panelConfig.Width)
	local selectedBuilding = props.building
	local hasUnits = #units > 0
	local hasBuilding = selectedBuilding ~= nil
	local hasNexoAction = props.canOpenNexoBuild == true
	local hp = if hasBuilding and typeof(selectedBuilding.HP) == "number" then selectedBuilding.HP else 0
	local maxHp = if hasBuilding
			and typeof(selectedBuilding.MaxHP) == "number"
			and selectedBuilding.MaxHP > 0
		then selectedBuilding.MaxHP
		else 1
	local buildingType = if hasBuilding then selectedBuilding.BuildingType or "BUILDING" else nil
	local definition = if buildingType ~= nil then BuildingConfig.GetBuilding(buildingType) else nil
	local productionUnits = if definition ~= nil then BuildingConfig.GetProductionUnits(buildingType) else nil
	local title = "COMANDO"
	if hasBuilding then
		title = string.upper(if definition ~= nil then definition.DisplayName else buildingType)
	elseif hasUnits then
		title = `TROPAS {#units}`
	elseif hasNexoAction then
		title = "NEXO"
	end

	local childrenList = {
		Title = React.createElement("Frame", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, px(textSizes.HudTitle)),
			BackgroundTransparency = transparency.Clear,
		}, {
			Text = React.createElement(Text, {
				Size = if hasBuilding then UDim2.fromScale(0.65, 1) else UDim2.fromScale(1, 1),
				variant = "Title",
				Text = title,
				TextColor3 = if hasBuilding then colors.Cyan else colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextScaled = compact,
			}),
			Hp = if hasBuilding
				then React.createElement(Text, {
					Position = UDim2.fromScale(0.65, 0),
					Size = UDim2.fromScale(0.35, 1),
					variant = "Mono",
					Text = `{math.floor(hp)}HP`,
					TextColor3 = if hp / maxHp <= 0.25
						then colors.Red
						elseif hp / maxHp <= 0.55 then colors.Amber
						else colors.Green,
					TextSize = if compact then textSizes.ButtonSmall else textSizes.Small,
					TextXAlignment = Enum.TextXAlignment.Right,
				})
				else nil,
		}),
	}

	local currentLayoutOrder = 2

	if hasUnits then
		childrenList.SepUnits = SeparatorLine(currentLayoutOrder)
		currentLayoutOrder += 1
		childrenList.Units = unitStrip(units, props.onDeselectUnit, compact)
		childrenList.Units.LayoutOrder = currentLayoutOrder
		currentLayoutOrder += 1
	end

	if hasBuilding then
		local production = buildingProduction({
			canEdit = selectedBuilding.CanEdit == true,
			queue = props.queue,
			compact = compact,
			title = "PRODUCCION",
			productionUnits = productionUnits,
			onQueueUnit = props.onQueueUnit,
		})
		if production ~= nil then
			childrenList.SepProd = SeparatorLine(currentLayoutOrder)
			currentLayoutOrder += 1
			childrenList.Production = production
			childrenList.Production.LayoutOrder = currentLayoutOrder
			currentLayoutOrder += 1
		end
	elseif hasNexoAction then
		local production = buildingProduction({
			canEdit = true,
			queue = props.queue,
			compact = compact,
			title = "NEXO",
			productionUnits = BuildingConfig.NexoProduction.Units,
			onQueueUnit = props.onQueueUnit,
		})
		if production ~= nil then
			childrenList.SepProd = SeparatorLine(currentLayoutOrder)
			currentLayoutOrder += 1
			childrenList.Production = production
			childrenList.Production.LayoutOrder = currentLayoutOrder
			currentLayoutOrder += 1
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = zIndexes.Overlay,
	}, {
		-- Sibling 1: Center Floating Tactical Command capsule (with gradient background decoupled!)
		ActionButtonsPanel = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = if compact
				then UDim2.new(0.5, 0, 1, -px(spacing.Bottom))
				else UDim2.new(0.5, 0, 1, -px(spacing.Bottom * 2)),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = zIndexes.Panel,
		}, {
			-- Background capsule with gradient, below the command content.
			Bg = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				ZIndex = zIndexes.Background,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = radii.Control,
				}),
				CommandGradient = React.createElement("UIGradient", {
					Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
					Rotation = 0,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1), -- Edge fully transparent
						NumberSequenceKeypoint.new(0.22, 0.55),
						NumberSequenceKeypoint.new(0.5, 0.42), -- Stronger in the middle without blacking out controls
						NumberSequenceKeypoint.new(0.78, 0.55),
						NumberSequenceKeypoint.new(1, 1), -- Edge fully transparent
					}),
				}),
			}),
			-- Content container with buttons, above the background capsule.
			Content = React.createElement("Frame", {
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = zIndexes.Content,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, px(spacing.Md)),
				}),
				Padding = React.createElement("UIPadding", {
					PaddingTop = UIHelpers.paddingValue(spacing.Sm),
					PaddingBottom = UIHelpers.paddingValue(spacing.Sm),
					PaddingLeft = UIHelpers.paddingValue(spacing.Loose),
					PaddingRight = UIHelpers.paddingValue(spacing.Loose),
				}),
				-- Slot 1: AREA
				Area = commandButton(
					if props.areaModeArmed then "AREA LISTA" else "AREA",
					1,
					colors.Amber,
					true,
					props.onArmArea,
					compact
				),
				-- Slot 2: MOVER / CONSTRUIR
				BuildOrMove = if hasBuilding
					then commandButton(
						"MOVER",
						2,
						colors.Amber,
						selectedBuilding.CanEdit == true,
						props.onMoveBuilding,
						compact
					)
					elseif hasNexoAction then commandButton(
						"CONSTRUIR",
						2,
						colors.Green,
						true,
						props.onOpenNexoBuild,
						compact
					)
					else nil,
				-- Slot 3: DESTRUIR
				Destroy = if hasBuilding
					then commandButton(
						"DESTRUIR",
						3,
						colors.Red,
						selectedBuilding.CanEdit == true,
						props.onDestroyBuilding,
						compact
					)
					else nil,
				-- Slot 4: LIMPIAR
				Clear = commandButton("LIMPIAR", 4, colors.Stroke, hasUnits or hasBuilding, props.onClear, compact),
			}),
		}),

		-- Sibling 2: Bottom-Right Information Panel (with gradient background decoupled!)
		SelectionInfoPanel = React.createElement("Frame", {
			AnchorPoint = if compact then Vector2.new(1, 1) else Vector2.new(1, 1),
			Position = if compact
				then UDim2.new(1, -px(spacing.Lg), 1, -px(spacing.Bottom))
				else UDim2.new(1, -px(panelConfig.RightOffset), 1, -px(panelConfig.BottomOffset)),
			Size = if compact then UDim2.fromOffset(panelWidth, 0) else UDim2.fromScale(0.36, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = zIndexes.Panel,
		}, {
			SizeConstraint = React.createElement("UISizeConstraint", {
				MinSize = if compact
					then Vector2.new(px(sizes.CompactPanelMinWidth), 0)
					else Vector2.new(px(sizes.UnitSelectionPanelWidth + spacing.Sm), 0),
				MaxSize = Vector2.new(
					panelWidth,
					if compact
						then math.max(px(sizes.CompactPanelMinHeight), viewportSize.Y - px(sizes.ButtonMediumWidth))
						else math.huge
				),
			}),
			-- Sibling 1: Background only, kept below the info content.
			Bg = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				ZIndex = zIndexes.Background,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = radii.Panel,
				}),
				InfoGradient = React.createElement("UIGradient", {
					Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
					Rotation = 0, -- Left to right fade-out
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.42), -- Visible backing without drowning text
						NumberSequenceKeypoint.new(0.65, 0.68), -- Smooth fade-out in the middle
						NumberSequenceKeypoint.new(1, 1), -- Fully transparent on the right
					}),
				}),
			}),
			-- Sibling 2: Content only, rendered above the background.
			Content = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = zIndexes.Content,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, px(spacing.Md)),
				}),
				Padding = React.createElement("UIPadding", {
					PaddingTop = UIHelpers.paddingValue(spacing.Panel),
					PaddingBottom = UIHelpers.paddingValue(spacing.Panel),
					PaddingLeft = UIHelpers.paddingValue(spacing.Panel),
					PaddingRight = UIHelpers.paddingValue(spacing.Panel),
				}),
				Children = React.createElement(React.Fragment, nil, childrenList),
			}),
		}),
	})
end

return SelectionActionPanel
