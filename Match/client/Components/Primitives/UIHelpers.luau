local UIHelpers = {}

local UITheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local px = UITheme.sp
local spacing = UITheme.Spacing
local breakpoints = UITheme.Breakpoints

function UIHelpers.value(tokenOrValue: number?): number
	return px(tokenOrValue or 0)
end

function UIHelpers.udim(tokenOrValue: number?): UDim
	return UDim.new(0, px(tokenOrValue or 0))
end

function UIHelpers.paddingValue(tokenOrValue: number?): UDim
	return UDim.new(0, px(tokenOrValue or spacing.Panel))
end

function UIHelpers.getViewportSize(props): Vector2
	local viewportSize = props.viewportSize
	return if typeof(viewportSize) == "Vector2"
			and viewportSize.X > 0
			and viewportSize.Y > 0
		then viewportSize
		else Vector2.new(1280, 720)
end

function UIHelpers.isCompact(props): boolean
	local viewportSize = UIHelpers.getViewportSize(props)
	return props.compact == true
		or props.isMobile == true
		or viewportSize.X <= breakpoints.CompactWidth
		or viewportSize.Y <= breakpoints.CompactHeight
end

return table.freeze(UIHelpers)
