local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local colors = UITheme.Colors
local sizes = UITheme.Sizes
local strokes = UITheme.Strokes
local transparency = UITheme.Transparency

local function IconFrame(props)
	return React.createElement("Frame", {
		LayoutOrder = props.LayoutOrder,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size or UDim2.fromOffset(
			UIHelpers.value(props.width or sizes.IconContainerWidth),
			UIHelpers.value(props.height or sizes.IconContainerHeight)
		),
		BackgroundColor3 = props.backgroundColor or colors.Panel,
		BackgroundTransparency = props.backgroundTransparency or transparency.PanelMuted,
		BorderSizePixel = 0,
	}, {
		Corner = if props.radius ~= nil
			then React.createElement("UICorner", {
				CornerRadius = props.radius,
			})
			else nil,
		Stroke = if props.stroke == false
			then nil
			else React.createElement("UIStroke", {
				Color = props.strokeColor or colors.Stroke,
				Thickness = UIHelpers.value(props.strokeThickness or strokes.Thin),
				Transparency = props.strokeTransparency or transparency.StrokeMuted,
			}),
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = props.IconSize or UDim2.fromOffset(
				UIHelpers.value(props.iconSize or sizes.IconCard),
				UIHelpers.value(props.iconSize or sizes.IconCard)
			),
			BackgroundTransparency = transparency.Clear,
			Image = props.image or UITheme.Assets.PlaceholderIcon,
			ImageColor3 = props.imageColor or colors.Text,
			ImageTransparency = props.imageTransparency or transparency.Solid,
			ScaleType = Enum.ScaleType.Fit,
		}, {
			IconCorner = if props.iconRadius ~= nil
				then React.createElement("UICorner", {
					CornerRadius = props.iconRadius,
				})
				else nil,
		}),
	})
end

return IconFrame
