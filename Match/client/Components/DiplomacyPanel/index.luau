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

local function button(label: string, accent: Color3, enabled: boolean, activated, compact: boolean?)
	return React.createElement(TacticalButton, {
		width = if compact then sizes.ButtonMediumWidth else sizes.ButtonWideWidth,
		height = sizes.ButtonHeight - spacing.Xxs,
		label = label,
		accent = accent,
		enabled = enabled,
		TextSize = if compact then textSizes.ButtonSmall else textSizes.Button,
		onActivated = activated,
	})
end

local function inviteToast(invite, name: string, layoutOrder: number, onAccept, onReject, compact: boolean?)
	return React.createElement(Panel, {
		LayoutOrder = layoutOrder,
		Size = if compact then UDim2.fromScale(1, 0) else nil,
		AutomaticSize = Enum.AutomaticSize.Y,
		backgroundColor = colors.Panel,
		backgroundTransparency = transparency.Panel,
		strokeColor = colors.Amber,
		strokeTransparency = transparency.StrokeStrong,
		padding = {
			Y = spacing.Xs + spacing.Lg,
			X = spacing.Panel,
		},
		layout = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		gap = spacing.Xl,
		Active = true,
		children = {
			Text = React.createElement(Text, {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, px(sizes.ButtonCompactHeight - spacing.Lg)),
				variant = "Title",
				Text = `ALIANZA: {string.upper(name)}`,
				TextSize = if compact then textSizes.ButtonSmall else textSizes.Button,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Actions = React.createElement("Frame", {
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = transparency.Clear,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, px(if compact then spacing.Md else spacing.XXl)),
				}),
				Accept = button("ACEPTAR", colors.Green, true, function()
					onAccept(invite.id)
				end, compact),
				Reject = button("RECHAZAR", colors.Red, true, function()
					onReject(invite.id)
				end, compact),
			}),
		},
	})
end

local function selectedPanel(props)
	local selected = props.selectedPlayer
	if selected == nil then
		return nil
	end

	local enabled = props.actionEnabled == true
	local accent = if props.actionKind == "Break" then colors.Red else colors.Green
	local compact = props.compact == true

	return React.createElement(Panel, {
		AnchorPoint = if compact then Vector2.new(1, 0) else Vector2.new(0.5, 1),
		Position = if compact
			then UDim2.new(1, -px(spacing.Wide), 0, px(sizes.ButtonLargeHeight + spacing.Bottom))
			else UDim2.new(0.5, 0, 1, -px(sizes.UnitSelectionPanelHeight + spacing.Sm)),
		Size = if compact then UDim2.fromOffset(props.panelWidth, 0) else nil,
		AutomaticSize = Enum.AutomaticSize.Y,
		backgroundColor = colors.Panel,
		backgroundTransparency = transparency.Panel,
		strokeColor = accent,
		strokeTransparency = transparency.StrokeStrong,
		padding = {
			Y = spacing.Panel,
			X = spacing.Wide,
		},
		layout = Enum.FillDirection.Vertical,
		gap = spacing.XXl,
		Active = true,
		children = {
			Name = React.createElement(Text, {
				LayoutOrder = 1,
				Size = if compact
					then UDim2.new(1, 0, 0, px(spacing.Bottom + spacing.Xxs))
					else UDim2.fromOffset(px(sizes.PanelWidth - spacing.Wide), px(spacing.Bottom + spacing.Xxs)),
				variant = "Title",
				Text = string.upper(selected.name),
				TextWrapped = true,
			}),
			Action = button(props.actionLabel or "ALIANZA", accent, enabled, props.onAction, compact),
			Close = button("CERRAR", colors.Stroke, true, props.onClose, compact),
		},
	})
end

local function DiplomacyPanel(props)
	local viewportSize = UIHelpers.getViewportSize(props)
	local compact = UIHelpers.isCompact(props)
	local panelWidth = if compact
		then math.max(
			px(sizes.CompactPanelMinWidth),
			math.min(px(sizes.DiplomacyMobileWidth), viewportSize.X - px(spacing.Bottom + spacing.Xxs))
		)
		else px(sizes.PanelWidth)
	local inviteTopOffset = if compact and props.selectedPlayer ~= nil
		then sizes.UnitSelectionPanelHeight + sizes.ButtonLargeHeight + spacing.Modal
		else sizes.ButtonLargeHeight + spacing.Bottom
	local inviteChildren = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(spacing.XXl)),
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
			props.onRejectInvite,
			compact
		)
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = transparency.Clear,
		BorderSizePixel = 0,
		Active = false,
	}, {
		Invites = React.createElement("Frame", {
			AnchorPoint = if compact then Vector2.new(0, 0) else Vector2.new(0, 0.5),
			Position = if compact
				then UDim2.fromOffset(px(spacing.Wide), px(inviteTopOffset))
				else UDim2.new(0, px(spacing.Loose), 0.5, 0),
			Size = if compact then UDim2.fromOffset(panelWidth, 0) else nil,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = transparency.Clear,
		}, inviteChildren),
		Selected = selectedPanel(table.freeze({
			selectedPlayer = props.selectedPlayer,
			actionKind = props.actionKind,
			actionLabel = props.actionLabel,
			actionEnabled = props.actionEnabled,
			onAction = props.onAction,
			onClose = props.onClose,
			compact = compact,
			panelWidth = panelWidth,
		})),
	})
end

return DiplomacyPanel
