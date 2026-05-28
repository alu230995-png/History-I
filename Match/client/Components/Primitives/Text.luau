local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local colors = UITheme.Colors
local fonts = UITheme.Fonts
local textSizes = UITheme.TextSizes

local variants = table.freeze({
	Label = table.freeze({
		font = fonts.Heading,
		color = colors.MutedText,
		size = textSizes.Small,
	}),
	Title = table.freeze({
		font = fonts.Heading,
		color = colors.Text,
		size = textSizes.Title,
	}),
	Body = table.freeze({
		font = fonts.Body,
		color = colors.MutedText,
		size = textSizes.Body,
	}),
	Mono = table.freeze({
		font = fonts.Mono,
		color = colors.MutedText,
		size = textSizes.Button,
	}),
	Value = table.freeze({
		font = fonts.Mono,
		color = colors.Text,
		size = textSizes.Value,
	}),
	Button = table.freeze({
		font = fonts.Heading,
		color = colors.Text,
		size = textSizes.Button,
	}),
})

local function TacticalText(props)
	local variant = variants[props.variant or "Body"] or variants.Body

	return React.createElement("TextLabel", {
		LayoutOrder = props.LayoutOrder,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size or UDim2.fromScale(1, 0),
		AutomaticSize = props.AutomaticSize,
		BackgroundTransparency = UITheme.Transparency.Clear,
		Font = props.Font or variant.font,
		Text = props.Text or "",
		TextColor3 = props.TextColor3 or variant.color,
		TextSize = px(props.TextSize or variant.size),
		TextScaled = props.TextScaled == true,
		TextWrapped = props.TextWrapped == true,
		TextTruncate = props.TextTruncate,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		TextStrokeColor3 = props.TextStrokeColor3,
		TextStrokeTransparency = props.TextStrokeTransparency,
		Visible = props.Visible,
		ZIndex = props.ZIndex,
	}, props.children)
end

return TacticalText
