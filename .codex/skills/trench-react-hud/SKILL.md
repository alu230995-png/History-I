---
name: trench-react-hud
description: Build or refactor React/ReactRoblox UI for Trench-Track with a tactical dark military HUD style inspired by Gears-like interfaces. Use for Roblox React components, HUD layout, mobile-safe controls, UITheme usage, responsive scaling, icons, typography, chamfered panels, lobby UI, match UI, overlays, meters, tactical buttons, and PC/mobile interface work.
---

# Trench React HUD

## Project fit

Use React and ReactRoblox from Wally. Keep UI code under the relevant client area, usually `src/lobby/client` or `src/match/client`, and share reusable UI constants/components through `src/TrenchTrackCore` when they are truly cross-place.

Assume the game is Trench-Track: tactical, dark, military, serious, readable under combat pressure.

## Visual rules

- Use dark tactical surfaces, high-contrast text, restrained red/amber/green status accents, and metal/utility spacing.
- Use straight edges and 45-degree chamfer feel. Do not use `UICorner` radius above `sp(4)`.
- Use `Enum.Font.GothamBold` for primary HUD labels.
- Use `Enum.Font.Code` for numbers, timers, tickets, ammo-like counters, coordinates, and debug-looking data.
- Use uppercase text for tactical HUD labels.
- Use monochrome silhouette icons. Never use emoji. Use `rbxassetid://6031075938` only as a generic placeholder when no project asset exists.
- Avoid decorative cards, oversized marketing sections, and bright playful palettes.

## Scaling rules

Always use the project UI theme scale function:

```lua
local px = UITheme.sp
```

If the project uses another name, adapt to the existing theme, but keep the rule: no hard-coded pixel sizes for size, padding, gap, stroke thickness, icon size, or text size.

Examples:

```lua
Size = UDim2.fromOffset(px(48), px(48))
PaddingTop = UDim.new(0, px(8))
TextSize = px(14)
```

## Layout rules

- Prefer `AutomaticSize`, `UIListLayout`, `UIGridLayout`, and `UIPadding` over manual offsets.
- Interactive mobile buttons must be at least `sp(44)` high and wide.
- Keep the gameplay center clear. Center-screen messages must be temporary and semi-transparent.
- Do not block lower-left and lower-right thumb zones on mobile.
- Anchor persistent HUD to upper bands, side rails, or compact corners that do not interfere with movement controls.
- Make text resilient: no clipping for localization or longer labels. Use constraints, wrapping, or smaller component-level text sizes.

## Component structure

- Keep components pure. Side effects belong in controllers or hooks that are easy to clean up.
- Do not create new tables/functions in render loops if avoidable. Memoize stable props and callbacks when components update frequently.
- Keep repeated HUD elements data-driven, but avoid rebuilding large arrays every frame.
- Bind UI to state changes, not polling. Reflex or controller events should drive UI updates.

## Roblox React details

- Use `React.createElement` or the existing project style consistently.
- Use `ReactRoblox.createRoot` for mounting.
- Unmount roots in controller `Destroy()`.
- Store UI roots/connections in Trove when the controller owns them.

## Output expectation

When implementing UI, mention:

- Where the component/controller lives.
- How it respects `sp()`, mobile thumb zones, and center gameplay space.
- Which theme tokens or fallback constants were used.
