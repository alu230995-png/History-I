local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
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

local function button(
	label: string,
	layoutOrder: number,
	accent: Color3,
	enabled: boolean,
	activated,
	compact: boolean?
)
	return React.createElement(TacticalButton, {
		LayoutOrder = layoutOrder,
		AutomaticSize = Enum.AutomaticSize.X,
		width = if compact then sizes.ButtonMediumWidth else sizes.ButtonBuildWidth,
		height = sizes.ButtonLargeHeight,
		minWidth = if compact then sizes.ButtonSmallWidth else sizes.ButtonBuildMinWidth,
		maxWidth = if compact then sizes.ButtonMediumWidth else sizes.ButtonBuildMaxWidth,
		maxHeight = sizes.ButtonMaxHeight,
		label = label,
		accent = accent,
		enabled = enabled,
		TextSize = if compact then textSizes.ButtonSmall else textSizes.Body,
		onActivated = activated,
	})
end

local function BuildControls(props)
	if not props.visible then
		return nil
	end

	local canConfirm = props.canConfirm == true
	local canRotate = props.canRotate == true
	local statusColor = if props.valid then colors.Green else colors.Red
	local title = props.buildingName or "BUILDING"
	local socketName = props.socketName or "NO TARGET"
	local viewportSize = UIHelpers.getViewportSize(props)
	local compact = UIHelpers.isCompact(props)
	local panelWidth = if compact
		then math.max(
			px(sizes.CompactPanelMinWidth),
			math.min(px(sizes.BuildControlsMobileWidth), viewportSize.X - px(spacing.Bottom + spacing.Xxs))
		)
		else px(sizes.PanelMaxTextWidth + spacing.Modal)

	return React.createElement(Panel, {
		AnchorPoint = if compact then Vector2.new(0.5, 0) else Vector2.new(0.5, 1),
		Position = if compact
			then UDim2.new(0.5, 0, 0, px(sizes.ButtonCompactHeight + spacing.Bottom))
			else UDim2.new(0.5, 0, 1, -px(spacing.Bottom)),
		Size = UDim2.fromOffset(panelWidth, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		backgroundColor = colors.Panel,
		backgroundTransparency = transparency.PanelSoft,
		strokeColor = statusColor,
		strokeTransparency = transparency.StrokeStrong,
		padding = {
			Y = spacing.XXl,
			X = spacing.Panel,
		},
		layout = Enum.FillDirection.Vertical,
		gap = spacing.Lg,
		Active = true,
		children = {
			Status = React.createElement(Text, {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, px(if compact then sizes.ButtonCompactHeight else textSizes.Heading)),
				variant = "Mono",
				Text = `{title}  |  {socketName}`,
				TextSize = if compact then textSizes.ButtonSmall else textSizes.Button,
				TextWrapped = true,
			}, {
				Width = React.createElement("UISizeConstraint", {
					MaxSize = Vector2.new(
						panelWidth,
						px(if compact then sizes.ButtonCompactHeight else sizes.ButtonHeight)
					),
				}),
			}),
			Buttons = React.createElement("Frame", {
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = transparency.Clear,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, px(if compact then spacing.Md else spacing.XXl)),
				}),
				Rotate = button("ROTAR", 1, colors.Amber, canRotate, props.onRotate, compact),
				Confirm = button("CONFIRMAR", 2, colors.Green, canConfirm, props.onConfirm, compact),
				Cancel = button("CANCELAR", 3, colors.Red, true, props.onCancel, compact),
			}),
		},
	})
end

return BuildControls
