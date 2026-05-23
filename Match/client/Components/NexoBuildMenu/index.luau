local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages:WaitForChild("React"))

local BuildingConfig = require(Shared:WaitForChild("Constants"):WaitForChild("BuildingConfig"))
local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local colors = UITheme.Colors

local PLACEHOLDER_IMAGE = "rbxassetid://6031075938"

local function getGold(resources): number
	if resources ~= nil and typeof(resources.Gold) == "number" then
		return resources.Gold
	end

	return 0
end

local function createBuildingItems()
	local items = {}

	for _, buildingType in BuildingConfig.MenuOrder do
		local definition = BuildingConfig.Buildings[buildingType]
		if definition ~= nil then
			table.insert(items, {
				Type = buildingType,
				DisplayName = definition.DisplayName or string.upper(buildingType),
				Gold = definition.Gold or 0,
				Icon = definition.Icon or PLACEHOLDER_IMAGE,
			})
		end
	end

	return items
end

local BUILDING_ITEMS = table.freeze(createBuildingItems())

local function BuildingCard(props)
	local item = props.item
	local resources = props.resources
	local onSelect = props.onSelectBuilding
	local gold = getGold(resources)
	local canAfford = gold >= item.Gold
	local cardColor = if canAfford then colors.PanelRaised else Color3.fromRGB(29, 29, 28)
	local priceColor = if canAfford then colors.Amber else colors.Red
	local strokeColor = if canAfford then colors.Stroke else colors.Red
	local imageTransparency = if canAfford then 0 else 0.45

	return React.createElement("TextButton", {
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = cardColor,
		BackgroundTransparency = if canAfford then 0.02 else 0.18,
		BorderSizePixel = 0,
		AutoButtonColor = canAfford,
		Text = "",
		Active = canAfford,
		[React.Event.Activated] = if canAfford
			then function()
				onSelect(item.Type)
			end
			else nil,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, px(4)),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = strokeColor,
			Thickness = px(1),
			Transparency = if canAfford then 0.18 else 0.05,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, px(10)),
			PaddingBottom = UDim.new(0, px(10)),
			PaddingLeft = UDim.new(0, px(10)),
			PaddingRight = UDim.new(0, px(10)),
		}),
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, px(8)),
		}),
		Name = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, px(32)),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = string.upper(item.DisplayName),
			TextColor3 = if canAfford then colors.Text else colors.MutedText,
			TextSize = px(12),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		IconContainer = React.createElement("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(px(70), px(58)),
			BackgroundColor3 = colors.Panel,
			BackgroundTransparency = 0.16,
			BorderSizePixel = 0,
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = colors.Stroke,
				Thickness = px(1),
				Transparency = 0.45,
			}),
			Icon = React.createElement("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(px(44), px(44)),
				BackgroundTransparency = 1,
				Image = item.Icon,
				ImageColor3 = if canAfford then colors.Text else colors.MutedText,
				ImageTransparency = imageTransparency,
				ScaleType = Enum.ScaleType.Fit,
			}),
		}),
		Price = React.createElement("TextLabel", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, px(22)),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			Text = `{item.Gold} ORO`,
			TextColor3 = priceColor,
			TextSize = px(13),
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
end

local function NexoBuildMenu(props)
	if not props.visible then
		return nil
	end

	local children = {
		Grid = React.createElement("UIGridLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = 2,
			CellPadding = UDim2.fromOffset(px(8), px(8)),
			CellSize = UDim2.new(0.5, -px(4), 0, px(154)),
		}),
		Padding = React.createElement("UIPadding", {
			PaddingRight = UDim.new(0, px(6)),
		}),
	}

	for index, item in BUILDING_ITEMS do
		children[item.Type] = React.createElement(BuildingCard, {
			LayoutOrder = index,
			item = item,
			resources = props.resources,
			onSelectBuilding = props.onSelectBuilding,
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.58,
		BorderSizePixel = 0,
		Active = true,
	}, {
		NexoBuildPanel = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -px(24), 0, px(428)),
			BackgroundColor3 = colors.Panel,
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
		}, {
			Width = React.createElement("UISizeConstraint", {
				MinSize = Vector2.new(px(292), px(428)),
				MaxSize = Vector2.new(px(390), px(428)),
			}),
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, px(4)),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = colors.Amber,
				Thickness = px(1),
				Transparency = 0.08,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, px(14)),
				PaddingBottom = UDim.new(0, px(14)),
				PaddingLeft = UDim.new(0, px(14)),
				PaddingRight = UDim.new(0, px(14)),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, px(10)),
			}),
			Header = React.createElement("Frame", {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, px(48)),
				BackgroundTransparency = 1,
			}, {
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.new(1, -px(112), 1, 0),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Text = "NEXO",
					TextColor3 = colors.Text,
					TextSize = px(19),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
				Gold = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, -px(112), 0, px(18)),
					BackgroundTransparency = 1,
					Font = Enum.Font.Code,
					Text = `{getGold(props.resources)} ORO`,
					TextColor3 = colors.Amber,
					TextSize = px(12),
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Close = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(px(96), px(44)),
					BackgroundColor3 = colors.PanelRaised,
					BorderSizePixel = 0,
					AutoButtonColor = true,
					Font = Enum.Font.GothamBold,
					Text = "CERRAR",
					TextColor3 = colors.Text,
					TextSize = px(12),
					[React.Event.Activated] = props.onClose,
				}, {
					Corner = React.createElement("UICorner", {
						CornerRadius = UDim.new(0, px(3)),
					}),
					Stroke = React.createElement("UIStroke", {
						Color = colors.Red,
						Thickness = px(1),
						Transparency = 0.12,
					}),
				}),
			}),
			Scroll = React.createElement("ScrollingFrame", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, px(332)),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromScale(0, 0),
				ScrollBarThickness = px(4),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollingEnabled = true,
			}, children),
		}),
	})
end

return NexoBuildMenu
