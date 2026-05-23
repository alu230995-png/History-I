local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local colors = UITheme.Colors

local function button(label: string, accent: Color3, enabled: boolean, activated)
	return React.createElement("TextButton", {
		Size = UDim2.fromOffset(px(118), px(42)),
		BackgroundColor3 = if enabled then colors.PanelRaised else Color3.fromRGB(38, 40, 40),
		BorderSizePixel = 0,
		AutoButtonColor = enabled,
		Active = enabled,
		Font = Enum.Font.GothamBold,
		Text = label,
		TextColor3 = if enabled then colors.Text else colors.MutedText,
		TextSize = px(12),
		TextWrapped = true,
		[React.Event.Activated] = if enabled then activated else nil,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(3)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = accent,
			Thickness = px(1),
			Transparency = if enabled then 0.12 else 0.45,
		}),
	})
end

local function inviteToast(invite, name: string, layoutOrder: number, onAccept, onReject)
	return React.createElement("Frame", {
		LayoutOrder = layoutOrder,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Active = true,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(4)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = colors.Amber,
			Thickness = px(1),
			Transparency = 0.1,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(9)),
			PaddingBottom = UDim.new(0, px(9)),
			PaddingLeft = UDim.new(0, px(10)),
			PaddingRight = UDim.new(0, px(10)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(7)),
		}),
		Text = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(px(224), px(34)),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = `ALIANZA: {string.upper(name)}`,
			TextColor3 = colors.Text,
			TextSize = px(12),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Actions = React.createElement("Frame", {
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, px(8)),
			}),
			Accept = button("ACEPTAR", colors.Green, true, function()
				onAccept(invite.id)
			end),
			Reject = button("RECHAZAR", colors.Red, true, function()
				onReject(invite.id)
			end),
		}),
	})
end

local function selectedPanel(props)
	local selected = props.selectedPlayer
	if selected == nil then
		return nil
	end

	local enabled = props.actionEnabled == true
	local accent = if props.actionKind == "Break" then colors.Red else colors.Green

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -px(150)),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Active = true,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(4)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = accent,
			Thickness = px(1),
			Transparency = 0.1,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(10)),
			PaddingBottom = UDim.new(0, px(10)),
			PaddingLeft = UDim.new(0, px(12)),
			PaddingRight = UDim.new(0, px(12)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(8)),
		}),
		Name = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(px(260), px(24)),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = string.upper(selected.name),
			TextColor3 = colors.Text,
			TextSize = px(15),
			TextWrapped = true,
		}),
		Action = button(props.actionLabel or "ALIANZA", accent, enabled, props.onAction),
		Close = button("CERRAR", colors.Stroke, true, props.onClose),
	})
end

local function DiplomacyPanel(props)
	local inviteChildren = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(8)),
		}),
	}

	local invites = if type(props.invites) == "table" then props.invites else {}
	for index = 1, #invites do
		local invite = invites[index]
		inviteChildren[`Invite{index}`] = inviteToast(
			invite,
			props.getPlayerName(invite.fromUserId),
			index,
			props.onAcceptInvite,
			props.onRejectInvite
		)
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
	}, {
		Invites = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, px(14), 0.5, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, inviteChildren),
		Selected = selectedPanel(props),
	})
end

return DiplomacyPanel
