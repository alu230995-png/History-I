local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local NexoData = require(script.Parent:WaitForChild("data"))
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

local function actionButton(
	label: string,
	layoutOrder: number,
	accent: Color3,
	enabled: boolean,
	activated,
	compact: boolean
)
	return React.createElement(TacticalButton, {
		LayoutOrder = layoutOrder,
		Size = if compact
			then UDim2.new(1, 0, 0, px(sizes.ButtonHeight))
			else UDim2.fromOffset(
				px(sizes.ButtonWideWidth + sizes.ButtonMediumWidth / 2),
				px(sizes.ButtonHeight + spacing.Xxs)
			),
		label = label,
		accent = accent,
		enabled = enabled,
		TextSize = textSizes.Meta,
		onActivated = activated,
	})
end

local function NexoSelectionMenu(props)
	if not props.visible then
		return nil
	end

	local nexo = NexoData.getNexoData(props.nexoId, props.snapshot, props.localUserId)
	local viewportSize = UIHelpers.getViewportSize(props)
	local compact = UIHelpers.isCompact(props)
	local panelMaxWidth = if compact
		then math.max(
			px(sizes.NexoBuildCompactMinWidth + spacing.Xxs),
			math.min(
				px(sizes.NexoBuildCompactMaxWidth + spacing.Bottom),
				viewportSize.X - px(spacing.Bottom + spacing.Xxs)
			)
		)
		else px(sizes.NexoPanelWidth)

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.Scrim,
		BackgroundTransparency = transparency.Scrim,
		BorderSizePixel = 0,
		Active = true,
	}, {
		Panel = React.createElement(Panel, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if compact
				then UDim2.new(1, -px(spacing.Bottom + spacing.Xxs), 0, 0)
				else UDim2.fromOffset(
					px(sizes.NexoPanelWidth),
					px(sizes.UnitSelectionPanelWidth - sizes.ButtonCompactHeight)
				),
			AutomaticSize = if compact then Enum.AutomaticSize.Y else Enum.AutomaticSize.None,
			backgroundColor = colors.Panel,
			backgroundTransparency = transparency.PanelLight,
			strokeColor = if nexo.canSelect then colors.Green else colors.Red,
			strokeTransparency = transparency.StrokeStrong,
			padding = {
				Y = spacing.Modal,
				X = spacing.Modal,
			},
			layout = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			gap = spacing.Wide,
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(panelMaxWidth, viewportSize.Y - px(spacing.Modal + spacing.Loose)),
			}),
			children = {
				Title = React.createElement(Text, {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, px(textSizes.Timer + spacing.XXl)),
					variant = "Title",
					Text = string.upper(nexo.nombre),
					TextSize = textSizes.Heading,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
				Status = React.createElement(Text, {
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, px(spacing.Bottom)),
					variant = "Mono",
					Text = nexo.statusText,
					TextColor3 = if nexo.canSelect then colors.Amber else colors.Red,
					TextSize = textSizes.Button,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
				Lore = React.createElement(Text, {
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, px(sizes.UnitSelectionChip + spacing.Sm)),
					variant = "Body",
					Text = nexo.lore,
					TextSize = textSizes.Body,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
				Buttons = React.createElement("Frame", {
					LayoutOrder = 4,
					AutomaticSize = Enum.AutomaticSize.XY,
					Size = if compact then UDim2.fromScale(1, 0) else UDim2.fromScale(0, 0),
					BackgroundTransparency = transparency.Clear,
				}, {
					Layout = React.createElement("UIListLayout", {
						FillDirection = if compact then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, if compact then px(spacing.XXl) else px(spacing.Panel)),
					}),
					Select = actionButton("SELECCIONAR NEXO", 1, colors.Green, nexo.canSelect, props.onSelect, compact),
					Close = actionButton("CERRAR", 2, colors.Red, true, props.onClose, compact),
				}),
			},
		}),
	})
end

return NexoSelectionMenu
