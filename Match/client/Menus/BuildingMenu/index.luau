local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local colors = UITheme.Colors

local function BuildingMenu(props)
	if not props.visible then
		return nil
	end

	local buildingType = props.buildingType or "BUILDING"
	local hp = if typeof(props.hp) == "number" then props.hp else 0
	local maxHp = if typeof(props.maxHp) == "number" and props.maxHp > 0 then props.maxHp else 1
	local healthText = `{math.floor(hp)} / {math.floor(maxHp)}`

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -px(92)),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(4)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = colors.Stroke,
			Thickness = px(1),
			Transparency = 0.05,
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
		Title = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(px(260), px(22)),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = string.upper(buildingType),
			TextColor3 = colors.Text,
			TextSize = px(15),
			TextWrapped = true,
		}),
		Health = React.createElement("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(px(260), px(18)),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = `HP {healthText}`,
			TextColor3 = colors.MutedText,
			TextSize = px(13),
		}),
		Close = React.createElement("TextButton", {
			LayoutOrder = 3,
			Size = UDim2.fromOffset(px(128), px(44)),
			BackgroundColor3 = colors.PanelRaised,
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Font = Enum.Font.GothamBold,
			Text = "CERRAR",
			TextColor3 = colors.Text,
			TextSize = px(13),
			[React.Event.Activated] = props.onClose,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, px(3)),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = colors.Red,
				Thickness = px(1),
				Transparency = 0.15,
			}),
		}),
	})
end

return BuildingMenu
