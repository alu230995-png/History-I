local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local Text = require(script.Parent:WaitForChild("Text"))

local colors = UITheme.Colors
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
	local backgroundColor = props.backgroundColor or (if enabled then colors.PanelFacet else colors.PanelDisabled)
	local size = props.Size
		or if props.fullWidth == true
			then UDim2.new(1, 0, 0, UIHelpers.value(height))
			else UDim2.fromOffset(UIHelpers.value(width or sizes.ButtonWideWidth), UIHelpers.value(height))
	local children = {
		Corner = React.createElement("UICorner", {
			CornerRadius = props.radius or radii.Control,
		}),
		Stroke = React.createElement(
			"UIStroke",
			{
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = if enabled then Color3.new(1, 1, 1) else colors.Stroke,
				Thickness = UIHelpers.value(props.strokeThickness or strokes.Thin),
				Transparency = if enabled
					then props.strokeTransparency or transparency.Stroke
					else transparency.Disabled,
			},
			if enabled
				then {
					StrokeGradient = React.createElement("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, colors.PanelFacet),
							ColorSequenceKeypoint.new(0.5, props.gradientAccent or accent),
							ColorSequenceKeypoint.new(1, colors.PanelFacet),
						}),
						Rotation = props.gradientRotation or -32,
					}),
				}
				else nil
		),
		LowPolyGradient = React.createElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, if enabled then colors.PanelPressed else colors.PanelFacetCold),
				ColorSequenceKeypoint.new(0.42, backgroundColor),
				ColorSequenceKeypoint.new(0.7, props.gradientAccent or accent),
				ColorSequenceKeypoint.new(1, if enabled then colors.PanelRaised else colors.PanelFacetDark),
			}),
			Rotation = props.gradientRotation or -32,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, if enabled then transparency.Facet else transparency.Disabled),
				NumberSequenceKeypoint.new(0.58, transparency.PanelLight),
				NumberSequenceKeypoint.new(1, if enabled then transparency.FacetStrong else transparency.Disabled),
			}),
		}),
		ButtonText = React.createElement(Text, {
			Size = UDim2.fromScale(1, 1),
			variant = "Button",
			Text = props.label or props.Text or "",
			TextColor3 = props.TextColor3 or (if enabled then colors.Text else colors.MutedText),
			TextSize = props.TextSize or textSizes.Button,
			TextScaled = props.TextScaled == true,
			TextWrapped = props.TextWrapped ~= false,
			TextTruncate = props.TextTruncate,
			TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
			TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
			ZIndex = if props.ZIndex then props.ZIndex + 1 else 2,
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

	if props.aspectRatio ~= nil then
		children.AspectRatio = React.createElement("UIAspectRatioConstraint", {
			AspectRatio = props.aspectRatio,
			DominantAxis = props.DominantAxis or Enum.DominantAxis.Height,
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
		ZIndex = props.ZIndex,
		AutoButtonColor = enabled,
		Active = enabled,
		Text = "", -- Make text empty so the gradient doesn't tint it!
		[React.Event.Activated] = if enabled then props.onActivated or props.activated else nil,
	}, children)
end

return TacticalButton
