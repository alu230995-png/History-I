local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local ProgressBar = require(script.Parent:WaitForChild("ProgressBar"))
local Text = require(script.Parent:WaitForChild("Text"))

local colors = UITheme.Colors
local radii = UITheme.Radii
local sizes = UITheme.Sizes
local strokes = UITheme.Strokes
local textSizes = UITheme.TextSizes
local transparency = UITheme.Transparency

local function UnitChip(props)
	local enabled = props.enabled ~= false
	local compact = props.compact == true
	local chipSize = props.size or (if compact then sizes.UnitChipCompact else sizes.UnitChip)
	local iconSize = props.iconSize or (if compact then sizes.IconCompact else sizes.IconLarge)
	local progress = props.progress
	local textSize = props.TextSize or (if compact then textSizes.Micro else textSizes.Unit)

	return React.createElement("TextButton", {
		LayoutOrder = props.LayoutOrder,
		Size = props.Size or UDim2.fromOffset(UIHelpers.value(chipSize), UIHelpers.value(chipSize)),
		BackgroundColor3 = props.backgroundColor or colors.PanelRaised,
		BackgroundTransparency = props.backgroundTransparency or transparency.PanelLight,
		BorderSizePixel = 0,
		AutoButtonColor = enabled and props.onActivated ~= nil,
		Active = enabled and props.onActivated ~= nil,
		Text = "",
		[React.Event.Activated] = if enabled then props.onActivated else nil,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = props.radius or radii.Control,
		}),
		Stroke = React.createElement("UIStroke", {
			Color = props.strokeColor or colors.Text,
			Thickness = UIHelpers.value(props.strokeThickness or strokes.Thin),
			Transparency = props.strokeTransparency or transparency.Stroke,
		}),
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = props.iconPosition or UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(UIHelpers.value(iconSize), UIHelpers.value(iconSize)),
			BackgroundTransparency = transparency.Clear,
			Image = props.icon or UITheme.Assets.PlaceholderIcon,
			ImageColor3 = props.iconColor or colors.Text,
			ImageTransparency = props.iconTransparency or transparency.Solid,
			ScaleType = Enum.ScaleType.Fit,
		}),
		Label = React.createElement(Text, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = props.labelPosition or UDim2.new(0.5, 0, 1, -UIHelpers.value(UITheme.Spacing.Xs)),
			Size = UDim2.new(1, -UIHelpers.value(UITheme.Spacing.Lg), 0, UIHelpers.value(textSizes.Button)),
			variant = "Mono",
			Text = props.label or "",
			TextColor3 = props.labelColor or colors.MutedText,
			TextSize = textSize,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Progress = if progress ~= nil
			then React.createElement(ProgressBar, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -UIHelpers.value(UITheme.Spacing.Xs)),
				Size = UDim2.new(1, -UIHelpers.value(UITheme.Spacing.XXl), 0, UIHelpers.value(sizes.ProgressThin)),
				progress = progress,
				fillColor = props.progressColor or colors.Amber,
			})
			else nil,
	})
end

return UnitChip
