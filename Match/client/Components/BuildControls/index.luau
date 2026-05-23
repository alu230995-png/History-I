local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local Panel = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Panel"))
local TacticalButton = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("TacticalButton"))
local Text = require(script.Parent.Parent:WaitForChild("Primitives"):WaitForChild("Text"))

local px = UITheme.sp
local colors = UITheme.Colors
local sizes = UITheme.Sizes
local spacing = UITheme.Spacing
local textSizes = UITheme.TextSizes
local transparency = UITheme.Transparency

local function button(label: string, layoutOrder: number, accent: Color3, enabled: boolean, activated)
	return React.createElement(TacticalButton, {
		LayoutOrder = layoutOrder,
		AutomaticSize = Enum.AutomaticSize.X,
		width = sizes.ButtonBuildWidth,
		height = sizes.ButtonLargeHeight,
		minWidth = sizes.ButtonBuildMinWidth,
		maxWidth = sizes.ButtonBuildMaxWidth,
		maxHeight = sizes.ButtonMaxHeight,
		label = label,
		accent = accent,
		enabled = enabled,
		TextSize = textSizes.Body,
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

	return React.createElement(Panel, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -px(spacing.Bottom)),
		AutomaticSize = Enum.AutomaticSize.XY,
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
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(px(sizes.PanelWidth), px(textSizes.Heading)),
				variant = "Mono",
				Text = `{title}  |  {socketName}`,
				TextSize = textSizes.Button,
				TextWrapped = true,
			}, {
				Width = React.createElement("UISizeConstraint", {
					MaxSize = Vector2.new(px(sizes.PanelMaxTextWidth), px(sizes.ButtonCompactHeight - spacing.Sm)),
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
					Padding = UDim.new(0, px(spacing.XXl)),
				}),
				Rotate = button("ROTAR", 1, colors.Amber, canRotate, props.onRotate),
				Confirm = button("CONFIRMAR", 2, colors.Green, canConfirm, props.onConfirm),
				Cancel = button("CANCELAR", 3, colors.Red, true, props.onCancel),
			}),
		},
	})
end

return BuildControls
