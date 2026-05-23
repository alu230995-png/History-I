local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages:WaitForChild("React"))

local BuildingConfig = require(Shared:WaitForChild("Constants"):WaitForChild("BuildingConfig"))
local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local SelectionConfig = require(Shared:WaitForChild("Constants"):WaitForChild("SelectionConfig"))
local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local colors = UITheme.Colors
local panelConfig = SelectionConfig.Panel

local function getViewportSize(props): Vector2
	local viewportSize = props.viewportSize
	return if typeof(viewportSize) == "Vector2"
			and viewportSize.X > 0
			and viewportSize.Y > 0
		then viewportSize
		else Vector2.new(1280, 720)
end

local function commandButton(
	label: string,
	order: number,
	accent: Color3,
	enabled: boolean,
	activated,
	compact: boolean?
)
	return React.createElement("TextButton", {
		LayoutOrder = order,
		Size = if compact
			then UDim2.fromOffset(px(78), px(panelConfig.MinTouchSize))
			else UDim2.fromOffset(px(104), px(panelConfig.MinTouchSize)),
		BackgroundColor3 = if enabled then colors.PanelRaised else Color3.fromRGB(38, 40, 40),
		BorderSizePixel = 0,
		AutoButtonColor = enabled,
		Active = enabled,
		Font = Enum.Font.GothamBold,
		Text = label,
		TextColor3 = if enabled then colors.Text else colors.MutedText,
		TextSize = if compact then px(9) else px(11),
		TextWrapped = true,
		[React.Event.Activated] = if enabled then activated else nil,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(3)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = accent,
			Thickness = px(1),
			Transparency = if enabled then 0.12 else 0.5,
		}),
	})
end

local function unitCard(unit, order: number, onDeselect, compact: boolean?)
	local definition = ManpowerConfig.GetUnit(unit.UnitType)
	local displayName = if definition ~= nil then definition.DisplayName else unit.UnitType

	return React.createElement("TextButton", {
		LayoutOrder = order,
		Size = if compact then UDim2.fromOffset(px(42), px(42)) else UDim2.fromOffset(px(48), px(48)),
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
			Transparency = 0.12,
		}),
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = if compact then UDim2.fromOffset(px(23), px(23)) else UDim2.fromOffset(px(27), px(27)),
			BackgroundTransparency = 1,
			Image = if definition ~= nil
				then definition.Icon or ManpowerConfig.PlaceholderIcon
				else ManpowerConfig.PlaceholderIcon,
			ImageColor3 = colors.Text,
			ScaleType = Enum.ScaleType.Fit,
		}),
		Label = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -px(3)),
			Size = UDim2.new(1, -px(5), 0, px(11)),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = displayName,
			TextColor3 = colors.MutedText,
			TextSize = if compact then px(6) else px(7),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
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
			FillDirectionMaxCells = if compact then 5 else 6,
			CellPadding = UDim2.fromOffset(if compact then px(5) else px(6), if compact then px(5) else px(6)),
			CellSize = if compact then UDim2.fromOffset(px(42), px(42)) else UDim2.fromOffset(px(48), px(48)),
		}),
	}

	local visibleCount = math.min(#units, if compact then 4 else 6)
	for index = 1, visibleCount do
		local unit = units[index]
		children[unit.UnitId] = unitCard(unit, index, onDeselect, compact)
	end

	if #units > visibleCount then
		children.Overflow = React.createElement("Frame", {
			LayoutOrder = 7,
			Size = if compact then UDim2.fromOffset(px(42), px(42)) else UDim2.fromOffset(px(48), px(48)),
			BackgroundColor3 = colors.PanelRaised,
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
				Text = `+{#units - visibleCount}`,
				TextColor3 = colors.Text,
				TextSize = px(15),
			}),
		})
	end

	return React.createElement("Frame", {
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, if compact then px(46) else px(102)),
		BackgroundTransparency = 1,
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

	return React.createElement("Frame", {
		LayoutOrder = order,
		Size = if compact then UDim2.fromOffset(px(44), px(32)) else UDim2.fromOffset(px(54), px(36)),
		BackgroundColor3 = if entry ~= nil then colors.PanelRaised else colors.Panel,
		BackgroundTransparency = if entry ~= nil then 0.04 else 0.18,
		BorderSizePixel = 0,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(3)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if entry ~= nil then colors.Green else colors.Stroke,
			Thickness = px(1),
			Transparency = if entry ~= nil then 0.2 else 0.48,
		}),
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, px(4)),
			Size = if compact then UDim2.fromOffset(px(17), px(17)) else UDim2.fromOffset(px(20), px(20)),
			BackgroundTransparency = 1,
			Image = if definition ~= nil
				then definition.Icon or ManpowerConfig.PlaceholderIcon
				else ManpowerConfig.PlaceholderIcon,
			ImageColor3 = if entry ~= nil then colors.Text else colors.Stroke,
			ImageTransparency = if entry ~= nil then 0 else 0.55,
			ScaleType = Enum.ScaleType.Fit,
		}),
		Progress = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -px(3)),
			Size = UDim2.new(1, -px(8), 0, px(4)),
			BackgroundColor3 = colors.Panel,
			BorderSizePixel = 0,
		}, {
			Fill = React.createElement("Frame", {
				Size = UDim2.fromScale(progress, 1),
				BackgroundColor3 = if entry ~= nil and entry.Ready == true then colors.Green else colors.Amber,
				BorderSizePixel = 0,
			}),
		}),
	})
end

local function productionButton(unitType: string, order: number, queueFull: boolean, onQueueUnit, compact: boolean?)
	local definition = ManpowerConfig.GetUnit(unitType)
	if definition == nil then
		return nil
	end

	local canQueue = not queueFull
	local label = if compact then `+ {string.sub(definition.DisplayName, 1, 8)}` else `+ {definition.DisplayName}`
	return commandButton(label, order, colors.Amber, canQueue, function()
		onQueueUnit(unitType)
	end, compact)
end

local function buildingProduction(props)
	if not props.isBarracks or not props.canEdit then
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
			Padding = UDim.new(0, if compact then px(5) else px(6)),
		}),
	}

	for index = 1, ManpowerConfig.QueueCapacity do
		queueChildren[`Slot{index}`] = queueSlot(getQueueEntry(queue, index), index, compact)
	end

	return React.createElement("Frame", {
		LayoutOrder = 5,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(7)),
		}),
		Header = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, px(16)),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = `PRODUCCION {count}/{capacity}`,
			TextColor3 = colors.MutedText,
			TextSize = px(10),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Buttons = React.createElement("Frame", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, if compact then px(5) else px(7)),
			}),
			Infantry = productionButton("InfanteriaLigera", 1, queueFull, props.onQueueUnit, compact),
			Tank = productionButton("Tanque", 2, queueFull, props.onQueueUnit, compact),
		}),
		Queue = React.createElement("Frame", {
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, queueChildren),
	})
end

local function SelectionActionPanel(props)
	if props.visible ~= true then
		return nil
	end

	local units = if type(props.units) == "table" then props.units else {}
	local viewportSize = getViewportSize(props)
	local compact = props.isMobile == true or viewportSize.X <= 720 or viewportSize.Y <= 520
	local panelWidth = if compact
		then math.max(px(254), math.min(px(276), viewportSize.X - px(24)))
		else px(panelConfig.Width)
	local selectedBuilding = props.building
	local hasUnits = #units > 0
	local hasBuilding = selectedBuilding ~= nil
	local hasNexoAction = props.canOpenNexoBuild == true
	local buildingType = if hasBuilding then selectedBuilding.BuildingType or "BUILDING" else nil
	local definition = if buildingType ~= nil then BuildingConfig.GetBuilding(buildingType) else nil
	local title = "COMANDO"
	if hasBuilding then
		title = string.upper(if definition ~= nil then definition.DisplayName else buildingType)
	elseif hasUnits then
		title = `TROPAS {#units}`
	elseif hasNexoAction then
		title = "NEXO"
	end

	local children = {
		Width = React.createElement("UISizeConstraint", {
			MinSize = if compact then Vector2.new(px(254), 0) else Vector2.new(px(286), 0),
			MaxSize = Vector2.new(
				panelWidth,
				if compact then math.max(px(240), viewportSize.Y - px(96)) else math.huge
			),
		}),
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(4)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if props.areaModeArmed then colors.Amber else colors.Stroke,
			Thickness = px(1),
			Transparency = if props.areaModeArmed then 0.05 else 0.16,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(10)),
			PaddingBottom = UDim.new(0, px(10)),
			PaddingLeft = UDim.new(0, if compact then px(8) else px(10)),
			PaddingRight = UDim.new(0, if compact then px(8) else px(10)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, if compact then px(6) else px(8)),
		}),
		Title = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, px(19)),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = title,
			TextColor3 = colors.Text,
			TextSize = if compact then px(12) else px(14),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Actions = React.createElement("Frame", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, if compact then px(5) else px(7)),
			}),
			Area = commandButton(
				if props.areaModeArmed then "AREA LISTA" else "AREA",
				1,
				colors.Amber,
				true,
				props.onArmArea,
				compact
			),
			Build = commandButton("CONSTRUIR", 2, colors.Green, hasNexoAction, props.onOpenNexoBuild, compact),
			Clear = commandButton("LIMPIAR", 3, colors.Stroke, hasUnits or hasBuilding, props.onClear, compact),
		}),
		Units = unitStrip(units, props.onDeselectUnit, compact),
	}

	if hasBuilding then
		local hp = if typeof(selectedBuilding.HP) == "number" then selectedBuilding.HP else 0
		local maxHp = if typeof(selectedBuilding.MaxHP) == "number" and selectedBuilding.MaxHP > 0
			then selectedBuilding.MaxHP
			else 1
		children.Health = React.createElement("TextLabel", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, px(16)),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = `HP {math.floor(hp)} / {math.floor(maxHp)}`,
			TextColor3 = colors.MutedText,
			TextSize = px(11),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		children.BuildingActions = React.createElement("Frame", {
			LayoutOrder = 4,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, px(7)),
			}),
			Move = commandButton(
				"MOVER",
				1,
				colors.Amber,
				selectedBuilding.CanEdit == true,
				props.onMoveBuilding,
				compact
			),
			Destroy = commandButton(
				"DESTRUIR",
				2,
				colors.Red,
				selectedBuilding.CanEdit == true,
				props.onDestroyBuilding,
				compact
			),
		})
		children.Production = buildingProduction({
			isBarracks = buildingType == "Cuartel",
			canEdit = selectedBuilding.CanEdit == true,
			queue = props.queue,
			compact = compact,
			onQueueUnit = props.onQueueUnit,
		})
	end

	return React.createElement("Frame", {
		AnchorPoint = if compact then Vector2.new(1, 0) else Vector2.new(1, 1),
		Position = if compact
			then UDim2.new(1, -px(12), 0, px(72))
			else UDim2.new(1, -px(panelConfig.RightOffset), 1, -px(panelConfig.BottomOffset)),
		Size = if compact then UDim2.fromOffset(panelWidth, 0) else UDim2.fromScale(0.42, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Active = true,
	}, children)
end

return SelectionActionPanel
