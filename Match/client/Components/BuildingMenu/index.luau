local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages:WaitForChild("React"))

local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local IconFrame = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("IconFrame"))
local Panel = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Panel"))
local ProgressBar = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("ProgressBar"))
local TacticalButton = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("TacticalButton"))
local Text = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Text"))

local px = UITheme.sp
local colors = UITheme.Colors
local sizes = UITheme.Sizes
local spacing = UITheme.Spacing
local textSizes = UITheme.TextSizes
local transparency = UITheme.Transparency

local function actionButton(label: string, layoutOrder: number, accent: Color3, enabled: boolean, activated)
	return React.createElement(TacticalButton, {
		LayoutOrder = layoutOrder,
		width = sizes.ButtonLargeWidth + spacing.XXl,
		height = sizes.ButtonHeight,
		label = label,
		accent = accent,
		enabled = enabled,
		TextSize = textSizes.Button,
		onActivated = activated,
	})
end

local function getQueueEntry(queue, index: number)
	if queue == nil or type(queue.Entries) ~= "table" then
		return nil
	end

	return queue.Entries[index]
end

local function unitCard(unitType: string, layoutOrder: number, queueFull: boolean, activated)
	local definition = ManpowerConfig.GetUnit(unitType)
	if definition == nil then
		return nil
	end

	local canQueue = not queueFull
	local textColor = if canQueue then colors.Text else colors.MutedText

	return React.createElement("TextButton", {
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(px(sizes.UnitCardWidth), px(sizes.UnitCardHeight)),
		BackgroundColor3 = if canQueue then colors.PanelRaised else colors.PanelPressed,
		BackgroundTransparency = if canQueue then transparency.PanelLight else transparency.PanelMuted,
		BorderSizePixel = 0,
		AutoButtonColor = canQueue,
		Active = canQueue,
		Text = "",
		[React.Event.Activated] = if canQueue then activated else nil,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UITheme.Radii.Control,
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if canQueue then colors.Amber else colors.Stroke,
			Thickness = px(UITheme.Strokes.Thin),
			Transparency = if canQueue then transparency.StrokeSoft else transparency.StrokeMuted,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(spacing.Xl)),
			PaddingBottom = UDim.new(0, px(spacing.Xl)),
			PaddingLeft = UDim.new(0, px(spacing.Xl)),
			PaddingRight = UDim.new(0, px(spacing.Xl)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(spacing.Sm)),
		}),
		Icon = React.createElement(IconFrame, {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(px(sizes.IconButton), px(sizes.IconButton)),
			backgroundTransparency = transparency.Clear,
			stroke = false,
			image = definition.Icon or ManpowerConfig.PlaceholderIcon,
			imageColor = textColor,
			iconSize = sizes.IconButton,
		}),
		Name = React.createElement(Text, {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, px(textSizes.Timer + spacing.Md)),
			variant = "Button",
			Text = definition.DisplayName,
			TextColor3 = textColor,
			TextSize = textSizes.Small,
			TextWrapped = true,
		}),
		Cost = React.createElement(Text, {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, px(textSizes.Body)),
			variant = "Mono",
			Text = `{definition.Gold or 0} ORO | {definition.TrainingTime or 0}S`,
			TextColor3 = if canQueue then colors.Amber else colors.MutedText,
			TextSize = textSizes.Small,
		}),
	})
end

local function queueSlot(entry, layoutOrder: number)
	local unitDefinition = if entry ~= nil then ManpowerConfig.GetUnit(entry.UnitType) else nil
	local progress = if entry ~= nil and typeof(entry.Progress) == "number" then entry.Progress else 0
	local slotText = if unitDefinition ~= nil then unitDefinition.DisplayName else "VACIO"

	return React.createElement("Frame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(px(sizes.QueueSlot), px(sizes.QueueSlot)),
		BackgroundColor3 = if entry ~= nil then colors.PanelRaised else colors.Panel,
		BackgroundTransparency = if entry ~= nil then transparency.PanelLight else transparency.PanelDim,
		BorderSizePixel = 0,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UITheme.Radii.Control,
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if entry ~= nil then colors.Green else colors.Stroke,
			Thickness = px(UITheme.Strokes.Thin),
			Transparency = if entry ~= nil then transparency.StrokeSoft else transparency.StrokeMuted,
		}),
		Icon = React.createElement(IconFrame, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, px(spacing.Md)),
			Size = UDim2.fromOffset(px(sizes.IconMedium), px(sizes.IconMedium)),
			backgroundTransparency = transparency.Clear,
			stroke = false,
			image = if unitDefinition ~= nil
				then unitDefinition.Icon or ManpowerConfig.PlaceholderIcon
				else ManpowerConfig.PlaceholderIcon,
			imageColor = if entry ~= nil then colors.Text else colors.Stroke,
			imageTransparency = if entry ~= nil then transparency.Solid else transparency.Disabled,
			iconSize = sizes.IconMedium,
		}),
		Label = React.createElement(Text, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -px(spacing.Panel)),
			Size = UDim2.new(1, -px(spacing.Lg), 0, px(textSizes.Value)),
			variant = "Mono",
			Text = slotText,
			TextColor3 = if entry ~= nil then colors.MutedText else colors.Stroke,
			TextSize = textSizes.Tiny,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		ProgressBack = React.createElement(ProgressBar, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -px(spacing.Sm)),
			Size = UDim2.new(1, -px(spacing.XXl), 0, px(sizes.ProgressThin)),
			progress = math.clamp(progress, 0, 1),
			fillColor = if entry ~= nil and entry.Ready == true then colors.Green else colors.Amber,
		}),
	})
end

local function barracksPanel(props)
	if not props.isBarracks or not props.canEdit then
		return nil
	end

	local queue = props.queue
	local count = if queue ~= nil and typeof(queue.Count) == "number" then queue.Count else 0
	local capacity = if queue ~= nil and typeof(queue.Capacity) == "number"
		then queue.Capacity
		else ManpowerConfig.QueueCapacity
	local queueFull = count >= capacity
	local queueChildren = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(spacing.Lg)),
		}),
	}

	for index = 1, ManpowerConfig.QueueCapacity do
		queueChildren[`Slot{index}`] = queueSlot(getQueueEntry(queue, index), index)
	end

	return React.createElement("Frame", {
		LayoutOrder = 4,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = transparency.Clear,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(spacing.Xl)),
		}),
		Header = React.createElement(Text, {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(px(sizes.PanelWidth), px(textSizes.Heading)),
			variant = "Mono",
			Text = `PRODUCCION {count} / {capacity}`,
			TextSize = textSizes.ButtonSmall,
		}),
		Production = React.createElement("Frame", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = transparency.Clear,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, px(spacing.XXl)),
			}),
			Infanteria = unitCard("InfanteriaLigera", 1, queueFull, function()
				props.onQueueUnit("InfanteriaLigera")
			end),
			Tanque = unitCard("Tanque", 2, queueFull, function()
				props.onQueueUnit("Tanque")
			end),
		}),
		Queue = React.createElement("Frame", {
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = transparency.Clear,
		}, queueChildren),
	})
end

local function BuildingMenu(props)
	if not props.visible then
		return nil
	end

	local buildingType = props.buildingType or "BUILDING"
	local canEdit = props.canEdit == true
	local hp = if typeof(props.hp) == "number" then props.hp else 0
	local maxHp = if typeof(props.maxHp) == "number" and props.maxHp > 0 then props.maxHp else 1
	local healthText = `{math.floor(hp)} / {math.floor(maxHp)}`
	local isBarracks = buildingType == "Cuartel"

	return React.createElement(Panel, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -px(sizes.ButtonMediumWidth - spacing.Sm)),
		AutomaticSize = Enum.AutomaticSize.XY,
		backgroundColor = colors.Panel,
		backgroundTransparency = transparency.Panel,
		strokeColor = colors.Stroke,
		strokeTransparency = transparency.StrokeStrong,
		padding = {
			Y = spacing.Panel,
			X = spacing.Wide,
		},
		layout = Enum.FillDirection.Vertical,
		gap = spacing.XXl,
		Active = true,
		children = {
			Title = React.createElement(Text, {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(px(sizes.PanelWidth), px(spacing.Bottom)),
				variant = "Title",
				Text = string.upper(buildingType),
				TextWrapped = true,
			}),
			Health = React.createElement(Text, {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(px(sizes.PanelWidth), px(textSizes.Heading)),
				variant = "Mono",
				Text = `HP {healthText}`,
				TextSize = textSizes.Meta,
			}),
			Actions = React.createElement("Frame", {
				LayoutOrder = 3,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = transparency.Clear,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, px(spacing.XXl)),
				}),
				Move = actionButton("MOVER", 1, colors.Amber, canEdit, props.onMove),
				Destroy = actionButton("DESTRUIR", 2, colors.Red, canEdit, props.onDestroy),
				Close = actionButton("CERRAR", 3, colors.Stroke, true, props.onClose),
			}),
			Barracks = barracksPanel({
				isBarracks = isBarracks,
				canEdit = canEdit,
				queue = props.queue,
				onQueueUnit = props.onQueueUnit,
			}),
		},
	})
end

return BuildingMenu
