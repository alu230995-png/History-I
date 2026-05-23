local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local colors = UITheme.Colors
local fonts = UITheme.Fonts
local radii = UITheme.Radii
local sizes = UITheme.Sizes
local spacing = UITheme.Spacing
local strokes = UITheme.Strokes
local textSizes = UITheme.TextSizes
local transparency = UITheme.Transparency

local function TacticalButton(props)
	local enabled = props.enabled ~= false
	local accent = props.accent or colors.Stroke
	local height = props.height or sizes.ButtonHeight
	local width = props.width
	local backgroundColor = props.backgroundColor or (if enabled then colors.PanelRaised else colors.PanelDisabled)
	local textColor = props.TextColor3 or (if enabled then colors.Text else colors.MutedText)
	local size = props.Size
		or if props.fullWidth == true
			then UDim2.new(1, 0, 0, UIHelpers.value(height))
			else UDim2.fromOffset(UIHelpers.value(width or sizes.ButtonWideWidth), UIHelpers.value(height))
	local children = {
		Corner = React.createElement("UICorner", {
			CornerRadius = props.radius or radii.Control,
		}),
		Stroke = React.createElement("UIStroke", {
			Color = accent,
			Thickness = UIHelpers.value(props.strokeThickness or strokes.Thin),
			Transparency = if enabled then props.strokeTransparency or transparency.Stroke else transparency.Disabled,
		}),
	}

	if props.padding ~= false then
		local horizontalPadding = props.paddingX or spacing.Loose
		children.Padding = React.createElement("UIPadding", {
			PaddingLeft = UIHelpers.udim(horizontalPadding),
			PaddingRight = UIHelpers.udim(horizontalPadding),
		})
	end

	if props.minWidth ~= nil or props.maxWidth ~= nil or props.minHeight ~= nil or props.maxHeight ~= nil then
		children.SizeConstraint = React.createElement("UISizeConstraint", {
			MinSize = Vector2.new(UIHelpers.value(props.minWidth or 0), UIHelpers.value(props.minHeight or height)),
			MaxSize = Vector2.new(
				UIHelpers.value(props.maxWidth or width or sizes.ButtonWideWidth),
				UIHelpers.value(props.maxHeight or height)
			),
		})
	end

	return React.createElement("TextButton", {
		LayoutOrder = props.LayoutOrder,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		AutomaticSize = props.AutomaticSize,
		Size = size,
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = props.backgroundTransparency or transparency.Solid,
		BorderSizePixel = 0,
		AutoButtonColor = enabled,
		Active = enabled,
		Font = props.Font or fonts.Heading,
		Text = props.label or props.Text or "",
		TextColor3 = textColor,
		TextSize = UIHelpers.value(props.TextSize or textSizes.Button),
		TextWrapped = props.TextWrapped ~= false,
		TextTruncate = props.TextTruncate,
		TextXAlignment = props.TextXAlignment,
		TextYAlignment = props.TextYAlignment,
		[React.Event.Activated] = if enabled then props.onActivated or props.activated else nil,
	}, children)
end

return TacticalButton
