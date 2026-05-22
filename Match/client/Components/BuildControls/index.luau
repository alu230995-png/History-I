local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local colors = UITheme.Colors

local function button(label: string, layoutOrder: number, accent: Color3, enabled: boolean, activated)
	local background = if enabled then colors.PanelRaised else Color3.fromRGB(38, 40, 40)
	local textColor = if enabled then colors.Text else colors.MutedText

	return React.createElement("TextButton", {
		LayoutOrder = layoutOrder,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(px(128), px(48)),
		BackgroundColor3 = background,
		BorderSizePixel = 0,
		AutoButtonColor = enabled,
		Text = label,
		TextColor3 = textColor,
		TextSize = px(14),
		TextWrapped = true,
		Font = Enum.Font.GothamBold,
		Active = enabled,
		[React.Event.Activated] = if enabled then activated else nil,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(3)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = accent,
			Thickness = px(1),
			Transparency = if enabled then 0 else 0.45,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, px(14)),
			PaddingRight = UDim.new(0, px(14)),
		}),
		Width = React.createElement("UISizeConstraint", {
			MinSize = Vector2.new(px(104), px(48)),
			MaxSize = Vector2.new(px(170), px(56)),
		}),
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

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -px(22)),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Active = true,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(4)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = statusColor,
			Thickness = px(1),
			Transparency = 0.1,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(8)),
			PaddingBottom = UDim.new(0, px(8)),
			PaddingLeft = UDim.new(0, px(10)),
			PaddingRight = UDim.new(0, px(10)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(6)),
		}),
		Status = React.createElement("TextLabel", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(px(260), px(18)),
			BackgroundTransparency = 1,
			Text = `{title}  |  {socketName}`,
			TextColor3 = colors.MutedText,
			TextSize = px(12),
			TextWrapped = true,
			Font = Enum.Font.Code,
		}, {
			Width = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(px(430), px(36)),
			}),
		}),
		Buttons = React.createElement("Frame", {
			LayoutOrder = 2,
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
			Rotate = button("ROTAR", 1, colors.Amber, canRotate, props.onRotate),
			Confirm = button("CONFIRMAR", 2, colors.Green, canConfirm, props.onConfirm),
			Cancel = button("CANCELAR", 3, colors.Red, true, props.onCancel),
		}),
	})
end

return BuildControls
