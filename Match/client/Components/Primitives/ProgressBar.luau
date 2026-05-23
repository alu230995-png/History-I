local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local colors = UITheme.Colors
local radii = UITheme.Radii
local sizes = UITheme.Sizes

local function ProgressBar(props)
	local progress = if typeof(props.progress) == "number" then math.clamp(props.progress, 0, 1) else 0

	return React.createElement("Frame", {
		LayoutOrder = props.LayoutOrder,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size or UDim2.new(1, 0, 0, UIHelpers.value(props.height or sizes.ProgressThin)),
		BackgroundColor3 = props.backgroundColor or colors.Panel,
		BorderSizePixel = 0,
	}, {
		TrackCorner = React.createElement("UICorner", {
			CornerRadius = props.radius or radii.Track,
		}),
		Fill = React.createElement("Frame", {
			Size = UDim2.fromScale(progress, 1),
			BackgroundColor3 = props.fillColor or colors.Amber,
			BorderSizePixel = 0,
		}, {
			FillCorner = React.createElement("UICorner", {
				CornerRadius = props.radius or radii.Track,
			}),
		}),
	})
end

return ProgressBar
