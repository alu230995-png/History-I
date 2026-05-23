local UITheme = {}

function UITheme.sp(value: number): number
	return math.round(value)
end

UITheme.Colors = table.freeze({
	Scrim = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(17, 20, 22),
	PanelRaised = Color3.fromRGB(29, 33, 35),
	PanelDisabled = Color3.fromRGB(38, 40, 40),
	PanelPressed = Color3.fromRGB(34, 36, 36),
	PanelDim = Color3.fromRGB(29, 29, 28),
	Stroke = Color3.fromRGB(91, 99, 94),
	Text = Color3.fromRGB(232, 235, 228),
	MutedText = Color3.fromRGB(160, 166, 157),
	Green = Color3.fromRGB(63, 176, 92),
	Red = Color3.fromRGB(188, 61, 58),
	Amber = Color3.fromRGB(205, 159, 68),
})

UITheme.Fonts = table.freeze({
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.Gotham,
	Mono = Enum.Font.Code,
})

UITheme.TextSizes = table.freeze({
	Micro = 6,
	Unit = 7,
	Tiny = 8,
	Small = 10,
	ButtonSmall = 11,
	Button = 12,
	Meta = 13,
	Body = 14,
	Title = 15,
	Value = 16,
	Heading = 18,
	HudTitle = 19,
	Timer = 20,
})

UITheme.Spacing = table.freeze({
	Hairline = 1,
	Xxs = 2,
	Xs = 3,
	Sm = 4,
	Md = 5,
	Lg = 6,
	Xl = 7,
	XXl = 8,
	Panel = 10,
	Wide = 12,
	Loose = 14,
	Modal = 18,
	Bottom = 22,
})

UITheme.Radii = table.freeze({
	Track = UDim.new(0, UITheme.sp(2)),
	Control = UDim.new(0, UITheme.sp(3)),
	Panel = UDim.new(0, UITheme.sp(4)),
	Circle = UDim.new(1, 0),
})

UITheme.Strokes = table.freeze({
	Thin = 1,
	Avatar = 2,
})

UITheme.Transparency = table.freeze({
	Clear = 1,
	Solid = 0,
	Panel = 0.04,
	PanelLight = 0.02,
	PanelSoft = 0.08,
	PanelMuted = 0.12,
	PanelDim = 0.18,
	Scrim = 0.48,
	ScrimStrong = 0.58,
	Stroke = 0.12,
	StrokeStrong = 0.08,
	StrokeSoft = 0.18,
	StrokeMuted = 0.45,
	Disabled = 0.5,
	IconDisabled = 0.45,
	Ghost = 0.55,
})

UITheme.Sizes = table.freeze({
	MinTouch = 44,
	ButtonSmallWidth = 78,
	ButtonMediumWidth = 96,
	ButtonLargeWidth = 104,
	ButtonWideWidth = 118,
	ButtonBuildWidth = 128,
	ButtonBuildMinWidth = 104,
	ButtonBuildMaxWidth = 170,
	ButtonHeight = 44,
	ButtonCompactHeight = 40,
	ButtonLargeHeight = 48,
	ButtonMaxHeight = 56,
	CommandButtonCompactWidth = 78,
	CommandButtonWidth = 104,
	PanelWidth = 272,
	PanelMaxTextWidth = 430,
	HudCompactMinWidth = 126,
	HudMinWidth = 154,
	HudCompactMaxWidth = 164,
	HudCompactMaxHeight = 230,
	HudMaxWidth = 280,
	HudMaxHeight = 320,
	CompactPanelMinWidth = 254,
	CompactPanelWidth = 276,
	CompactPanelMinHeight = 240,
	SelectionPanelWidth = 352,
	NexoPanelWidth = 420,
	NexoBuildPanelWidth = 390,
	NexoBuildPanelHeight = 428,
	NexoBuildCompactMinWidth = 286,
	NexoBuildCompactMaxWidth = 340,
	NexoBuildCompactMinHeight = 278,
	NexoBuildCompactMaxHeight = 348,
	UnitCardWidth = 128,
	UnitCardHeight = 92,
	BuildingCardCompactHeight = 112,
	BuildingCardHeight = 154,
	QueueSlot = 60,
	QueueSlotCompactWidth = 44,
	QueueSlotCompactHeight = 32,
	QueueSlotWidth = 54,
	QueueSlotHeight = 36,
	UnitChipCompact = 42,
	UnitChip = 48,
	UnitSelectionChip = 60,
	UnitSelectionPanelWidth = 282,
	UnitSelectionPanelHeight = 146,
	IconTiny = 17,
	IconSmall = 20,
	IconCompact = 23,
	IconMedium = 25,
	IconLarge = 27,
	IconButton = 30,
	IconCardCompact = 32,
	IconCard = 44,
	IconContainerCompactWidth = 54,
	IconContainerCompactHeight = 42,
	IconContainerWidth = 70,
	IconContainerHeight = 58,
	AvatarCompact = 30,
	Avatar = 38,
	AvatarImageCompact = 25,
	AvatarImage = 32,
	ProgressThin = 4,
	Progress = 7,
	HealthTrack = 8,
})

UITheme.Breakpoints = table.freeze({
	CompactWidth = 720,
	CompactHeight = 520,
})

UITheme.Assets = table.freeze({
	PlaceholderIcon = "rbxassetid://6031075938",
})

return table.freeze(UITheme)
