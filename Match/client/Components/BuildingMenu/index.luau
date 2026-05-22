local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages:WaitForChild("React"))

local ManpowerConfig = require(Shared:WaitForChild("Constants"):WaitForChild("ManpowerConfig"))
local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local colors = UITheme.Colors

local function actionButton(label: string, layoutOrder: number, accent: Color3, enabled: boolean, activated)
	return React.createElement("TextButton", {
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(px(112), px(44)),
		BackgroundColor3 = if enabled then colors.PanelRaised else Color3.fromRGB(38, 40, 40),
		BorderSizePixel = 0,
		AutoButtonColor = enabled,
		Active = enabled,
		Font = Enum.Font.GothamBold,
		Text = label,
		TextColor3 = if enabled then colors.Text else colors.MutedText,
		TextSize = px(12),
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
		Size = UDim2.fromOffset(px(128), px(92)),
		BackgroundColor3 = if canQueue then colors.PanelRaised else Color3.fromRGB(34, 36, 36),
		BackgroundTransparency = if canQueue then 0.02 else 0.12,
		BorderSizePixel = 0,
		AutoButtonColor = canQueue,
		Active = canQueue,
		Text = "",
		[React.Event.Activated] = if canQueue then activated else nil,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(3)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if canQueue then colors.Amber else colors.Stroke,
			Thickness = px(1),
			Transparency = if canQueue then 0.16 else 0.45,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(7)),
			PaddingBottom = UDim.new(0, px(7)),
			PaddingLeft = UDim.new(0, px(7)),
			PaddingRight = UDim.new(0, px(7)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(4)),
		}),
		Icon = React.createElement("ImageLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(px(30), px(30)),
			BackgroundTransparency = 1,
			Image = definition.Icon or ManpowerConfig.PlaceholderIcon,
			ImageColor3 = textColor,
			ScaleType = Enum.ScaleType.Fit,
		}),
		Name = React.createElement("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, px(25)),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = definition.DisplayName,
			TextColor3 = textColor,
			TextSize = px(10),
			TextWrapped = true,
		}),
		Cost = React.createElement("TextLabel", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, px(14)),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = `{definition.Gold or 0} ORO | {definition.TrainingTime or 0}S`,
			TextColor3 = if canQueue then colors.Amber else colors.MutedText,
			TextSize = px(10),
		}),
	})
end

local function queueSlot(entry, layoutOrder: number)
	local unitDefinition = if entry ~= nil then ManpowerConfig.GetUnit(entry.UnitType) else nil
	local progress = if entry ~= nil and typeof(entry.Progress) == "number" then entry.Progress else 0
	local slotText = if unitDefinition ~= nil then unitDefinition.DisplayName else "VACIO"

	return React.createElement("Frame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(px(60), px(60)),
		BackgroundColor3 = if entry ~= nil then colors.PanelRaised else colors.Panel,
		BackgroundTransparency = if entry ~= nil then 0.02 else 0.18,
		BorderSizePixel = 0,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(3)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if entry ~= nil then colors.Green else colors.Stroke,
			Thickness = px(1),
			Transparency = if entry ~= nil then 0.18 else 0.42,
		}),
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, px(5)),
			Size = UDim2.fromOffset(px(25), px(25)),
			BackgroundTransparency = 1,
			Image = if unitDefinition ~= nil
				then unitDefinition.Icon or ManpowerConfig.PlaceholderIcon
				else ManpowerConfig.PlaceholderIcon,
			ImageColor3 = if entry ~= nil then colors.Text else colors.Stroke,
			ImageTransparency = if entry ~= nil then 0 else 0.5,
			ScaleType = Enum.ScaleType.Fit,
		}),
		Label = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -px(10)),
			Size = UDim2.new(1, -px(6), 0, px(16)),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = slotText,
			TextColor3 = if entry ~= nil then colors.MutedText else colors.Stroke,
			TextSize = px(8),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		ProgressBack = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -px(4)),
			Size = UDim2.new(1, -px(8), 0, px(4)),
			BackgroundColor3 = colors.Panel,
			BorderSizePixel = 0,
		}, {
			Fill = React.createElement("Frame", {
				Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1),
				BackgroundColor3 = if entry ~= nil and entry.Ready == true then colors.Green else colors.Amber,
				BorderSizePixel = 0,
			}),
		}),
	})
end

local function barracksPanel(props)
	if not props.isBarracks or not props.canEdit then
		return nil
	end

	local queue = props.queue
	local count = if queue ~= nil and typeof(queue.Count) == "number" then queue.Count else 0
	local capacity = if queue ~= nil and typeof(queue.Capacity) == "number" then queue.Capacity else ManpowerConfig.QueueCapacity
	local queueFull = count >= capacity
	local queueChildren = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(6)),
		}),
	}

	for index = 1, ManpowerConfig.QueueCapacity do
		queueChildren[`Slot{index}`] = queueSlot(getQueueEntry(queue, index), index)
	end

	return React.createElement("Frame", {
		LayoutOrder = 4,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(7)),
		}),
		Header = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(px(272), px(18)),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = `PRODUCCION {count} / {capacity}`,
			TextColor3 = colors.MutedText,
			TextSize = px(11),
		}),
		Production = React.createElement("Frame", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, px(8)),
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
			BackgroundTransparency = 1,
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

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -px(92)),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Active = true,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(4)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = colors.Stroke,
			Thickness = px(1),
			Transparency = 0.05,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(10)),
			PaddingBottom = UDim.new(0, px(10)),
			PaddingLeft = UDim.new(0, px(12)),
			PaddingRight = UDim.new(0, px(12)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(8)),
		}),
		Title = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(px(272), px(22)),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = string.upper(buildingType),
			TextColor3 = colors.Text,
			TextSize = px(15),
			TextWrapped = true,
		}),
		Health = React.createElement("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(px(272), px(18)),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = `HP {healthText}`,
			TextColor3 = colors.MutedText,
			TextSize = px(13),
		}),
		Actions = React.createElement("Frame", {
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, px(8)),
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
	})
end

return BuildingMenu
