local UITheme = {}

function UITheme.sp(value: number): number
	return math.round(value)
end

UITheme.Colors = table.freeze({
	Scrim = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(12, 17, 18),
	PanelRaised = Color3.fromRGB(24, 31, 31),
	PanelDisabled = Color3.fromRGB(38, 42, 39),
	PanelPressed = Color3.fromRGB(30, 35, 34),
	PanelDim = Color3.fromRGB(20, 23, 22),
	PanelFacet = Color3.fromRGB(34, 46, 44),
	PanelFacetDark = Color3.fromRGB(8, 12, 13),
	PanelFacetCold = Color3.fromRGB(18, 35, 38),
	Stroke = Color3.fromRGB(101, 116, 104),
	StrokeHot = Color3.fromRGB(219, 180, 83),
	Text = Color3.fromRGB(237, 241, 232),
	MutedText = Color3.fromRGB(154, 168, 156),
	Green = Color3.fromRGB(70, 184, 100),
	Red = Color3.fromRGB(204, 66, 60),
	Amber = Color3.fromRGB(223, 170, 72),
	Cyan = Color3.fromRGB(83, 178, 184),
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
	Panel = 0.20,       -- Modern glassmorphism translucent panels
	PanelLight = 0.12,
	PanelSoft = 0.26,
	PanelMuted = 0.35,
	PanelDim = 0.45,
	Scrim = 0.30,       -- Subtle overlay that doesn't block gameplay
	ScrimStrong = 0.40,
	Stroke = 0.25,
	StrokeStrong = 0.15,
	StrokeSoft = 0.30,
	StrokeMuted = 0.50,
	Disabled = 0.6,
	IconDisabled = 0.5,
	Ghost = 0.6,
	Facet = 0.45,
	FacetStrong = 0.30,
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
	ButtonCompactHeight = 36,
	ButtonLargeHeight = 44,
	ButtonMaxHeight = 50,
	CommandButtonCompactWidth = 78,
	CommandButtonWidth = 104,
	PanelWidth = 272,
	PanelMaxTextWidth = 430,
	HudCompactMinWidth = 110,
	HudMinWidth = 136,
	HudCompactMaxWidth = 142,
	HudCompactMaxHeight = 176,
	HudMaxWidth = 248,
	HudMaxHeight = 270,
	CompactPanelMinWidth = 218,
	CompactPanelWidth = 238,
	CompactPanelMinHeight = 196,
	SelectionPanelWidth = 320,
	NexoPanelWidth = 370,
	NexoBuildPanelWidth = 356,
	NexoBuildPanelHeight = 380,
	NexoBuildMobileWidth = 284,
	NexoBuildMobileHeight = 310,
	NexoBuildCompactMinWidth = 230,
	NexoBuildCompactMaxWidth = 280,
	NexoBuildCompactMinHeight = 218,
	NexoBuildCompactMaxHeight = 275,
	DiplomacyMobileWidth = 280,
	BuildControlsMobileWidth = 284,
	UnitCardWidth = 110,
	UnitCardHeight = 78,
	BuildingCardCompactHeight = 88,
	BuildingCardHeight = 128,
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

UITheme.AspectRatios = table.freeze({
	PanelWide = 1.72,
	PanelCommand = 1.18,
	PanelTall = 0.92,
	BuildingCard = 0.86,
	UnitCard = 1.39,
	QueueSlot = 1,
	Icon = 1,
	Avatar = 1,
})

UITheme.Assets = table.freeze({
	PlaceholderIcon = "rbxassetid://6031075938",
})

return table.freeze(UITheme)
