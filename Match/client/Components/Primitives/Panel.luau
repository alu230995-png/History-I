local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local colors = UITheme.Colors
local aspectRatios = UITheme.AspectRatios
local radii = UITheme.Radii
local spacing = UITheme.Spacing
local strokes = UITheme.Strokes
local transparency = UITheme.Transparency

local function makePadding(padding)
	if padding == false then
		return nil
	end

	if type(padding) == "table" then
		return React.createElement("UIPadding", {
			PaddingTop = UIHelpers.paddingValue(padding.Top or padding.Y or padding.All),
			PaddingBottom = UIHelpers.paddingValue(padding.Bottom or padding.Y or padding.All),
			PaddingLeft = UIHelpers.paddingValue(padding.Left or padding.X or padding.All),
			PaddingRight = UIHelpers.paddingValue(padding.Right or padding.X or padding.All),
		})
	end

	return React.createElement("UIPadding", {
		PaddingTop = UIHelpers.paddingValue(padding or spacing.Panel),
		PaddingBottom = UIHelpers.paddingValue(padding or spacing.Panel),
		PaddingLeft = UIHelpers.paddingValue(padding or spacing.Panel),
		PaddingRight = UIHelpers.paddingValue(padding or spacing.Panel),
	})
end

local function makeLayout(props)
	if props.layout == nil then
		return nil
	end

	return React.createElement("UIListLayout", {
		FillDirection = props.layout,
		HorizontalAlignment = props.HorizontalAlignment or Enum.HorizontalAlignment.Center,
		VerticalAlignment = props.VerticalAlignment or Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UIHelpers.udim(props.gap or spacing.XXl),
	})
end

local function mergeChildren(props, children)
	local panelChildren = {}

	if props.SizeConstraint ~= nil then
		panelChildren.SizeConstraint = props.SizeConstraint
	end

	if props.corner ~= false then
		panelChildren.Corner = React.createElement("UICorner", {
			CornerRadius = props.radius or radii.Panel,
		})
	end

	if props.stroke ~= false then
		panelChildren.Stroke = React.createElement("UIStroke", {
			Color = props.strokeColor or colors.Stroke,
			Thickness = UIHelpers.value(props.strokeThickness or strokes.Thin),
			Transparency = props.strokeTransparency or transparency.Stroke,
		})
	end

	if props.gradient ~= false then
		panelChildren.LowPolyGradient = React.createElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, props.gradientStart or colors.PanelFacetCold),
				ColorSequenceKeypoint.new(0.38, props.backgroundColor or colors.Panel),
				ColorSequenceKeypoint.new(0.66, props.gradientMid or colors.PanelRaised),
				ColorSequenceKeypoint.new(1, props.gradientEnd or colors.PanelFacetDark),
			}),
			Rotation = props.gradientRotation or -28,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, props.gradientTransparency or transparency.Facet),
				NumberSequenceKeypoint.new(0.5, transparency.PanelLight),
				NumberSequenceKeypoint.new(1, props.gradientTransparency or transparency.FacetStrong),
			}),
		})
	end

	if props.aspectRatio ~= nil then
		panelChildren.AspectRatio = React.createElement("UIAspectRatioConstraint", {
			AspectRatio = props.aspectRatio or aspectRatios.PanelCommand,
			DominantAxis = props.DominantAxis or Enum.DominantAxis.Width,
		})
	end

	panelChildren.Padding = makePadding(props.padding)
	panelChildren.Layout = makeLayout(props)

	if children ~= nil then
		for key, value in children do
			panelChildren[key] = value
		end
	end

	return panelChildren
end

local function Panel(props)
	return React.createElement("Frame", {
		LayoutOrder = props.LayoutOrder,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		AutomaticSize = props.AutomaticSize,
		BackgroundColor3 = props.backgroundColor or colors.Panel,
		BackgroundTransparency = props.backgroundTransparency or transparency.Panel,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex,
		Active = props.Active,
		Visible = props.Visible,
		ClipsDescendants = props.ClipsDescendants,
	}, mergeChildren(props, props.children))
end

return Panel
