local UITheme = {}

function UITheme.sp(value: number): number
	return math.round(value)
end

UITheme.Colors = table.freeze({
	Panel = Color3.fromRGB(17, 20, 22),
	PanelRaised = Color3.fromRGB(29, 33, 35),
	Stroke = Color3.fromRGB(91, 99, 94),
	Text = Color3.fromRGB(232, 235, 228),
	MutedText = Color3.fromRGB(160, 166, 157),
	Green = Color3.fromRGB(63, 176, 92),
	Red = Color3.fromRGB(188, 61, 58),
	Amber = Color3.fromRGB(205, 159, 68),
})

return table.freeze(UITheme)
