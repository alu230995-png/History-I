local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local NexoData = require(script.Parent:WaitForChild("data"))

local px = UITheme.sp
local colors = UITheme.Colors

local function actionButton(label: string, layoutOrder: number, accent: Color3, enabled: boolean, activated)
	return React.createElement("TextButton", {
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(px(168), px(46)),
		BackgroundColor3 = if enabled then colors.PanelRaised else Color3.fromRGB(39, 42, 42),
		BorderSizePixel = 0,
		AutoButtonColor = enabled,
		Active = enabled,
		Font = Enum.Font.GothamBold,
		Text = label,
		TextColor3 = if enabled then colors.Text else colors.MutedText,
		TextSize = px(13),
		TextWrapped = true,
		[React.Event.Activated] = if enabled then activated else nil,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(3)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = accent,
			Thickness = px(1),
			Transparency = if enabled then 0.08 else 0.5,
		}),
	})
end

local function NexoSelectionMenu(props)
	if not props.visible then
		return nil
	end

	local nexo = NexoData.getNexoData(props.nexoId, props.snapshot, props.localUserId)

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.48,
		BorderSizePixel = 0,
		Active = true,
	}, {
		Panel = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(px(420), px(242)),
			BackgroundColor3 = colors.Panel,
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, px(4)),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = if nexo.canSelect then colors.Green else colors.Red,
				Thickness = px(1),
				Transparency = 0.08,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, px(18)),
				PaddingBottom = UDim.new(0, px(16)),
				PaddingLeft = UDim.new(0, px(18)),
				PaddingRight = UDim.new(0, px(18)),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, px(12)),
			}),
			Title = React.createElement("TextLabel", {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, px(28)),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Text = string.upper(nexo.nombre),
				TextColor3 = colors.Text,
				TextSize = px(18),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			}),
			Status = React.createElement("TextLabel", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, px(22)),
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				Text = nexo.statusText,
				TextColor3 = if nexo.canSelect then colors.Amber else colors.Red,
				TextSize = px(12),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			}),
			Lore = React.createElement("TextLabel", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, px(64)),
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Text = nexo.lore,
				TextColor3 = colors.MutedText,
				TextSize = px(14),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			Buttons = React.createElement("Frame", {
				LayoutOrder = 4,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, px(10)),
				}),
				Select = actionButton("SELECCIONAR NEXO", 1, colors.Green, nexo.canSelect, props.onSelect),
				Close = actionButton("CERRAR", 2, colors.Red, true, props.onClose),
			}),
		}),
	})
end

return NexoSelectionMenu
