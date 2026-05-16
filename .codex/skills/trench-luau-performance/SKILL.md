---
name: trench-luau-performance
description: Optimize Luau and Roblox hot paths in the Trench-Track project. Use when auditing, refactoring, or implementing code that runs in RenderStepped, Heartbeat, Stepped, input loops, camera loops, character movement loops, UI update loops, raycast loops, or any frequently-called client/server path where allocations, O(n) searches, Roblox API calls, remotes, tweens, or CollectionService operations can hurt frame budget.
---

# Trench Luau Performance

## Project fit

Treat Trench-Track as a Rojo/Wally Roblox project with shared code under `src/TrenchTrackCore`, lobby code under `src/lobby`, match code under `src/match`, and dependencies including React, ReactRoblox, Reflex, Knit, Signal, Trove, ProfileService, and ReplicaService.

Prefer small, local optimizations that preserve the current module style: table classes with `.new()`, `:Start()`, and optional `:Destroy()`.

## Workflow

1. Identify the hot path first. Search for `Heartbeat`, `RenderStepped`, `Stepped`, `Update`, `while true`, `task.wait`, `GetTagged`, `GetChildren`, `GetDescendants`, `FindFirstChild`, `Raycast`, `FireServer`, `FireClient`, `TweenService:Create`, and `Instance.new`.
2. Confirm call frequency before changing architecture. A tiny allocation in `Start()` is fine; the same allocation in `Heartbeat` is not.
3. Move stable values to module constants, constructor fields, or cached locals.
4. Replace repeated lookups with event-maintained cached references or maps.
5. Keep readability unless the code is definitely in a hot path.

## Hot path rules

- Avoid literal tables `{}` inside per-frame functions. Reuse scratch tables with `table.clear` or move static tables to module constants.
- Avoid `string.format`, `..`, `tostring`, and `tonumber` in per-frame logic. Precompute labels or update UI only when values change.
- Avoid inline closures in per-frame callbacks or loops when they capture changing state.
- Move constant `Vector3.new`, `CFrame.new`, `Color3.new`, `UDim2`, and `RaycastParams.new()` values outside hot functions.
- Create `RaycastParams` once in `.new()` or module scope, then mutate only the fields that truly change.
- Use `for i = 1, #array do` for dense arrays in hot loops. Use `pairs` only for dictionaries.
- Read expensive or repeated properties once per update: `MoveDirection`, `AssemblyLinearVelocity`, `CurrentCamera`, `Character`, `HumanoidRootPart`, and `os.clock()`.

## Cache instead of polling

- Do not call `FindFirstChild`, `FindFirstChildOfClass`, `GetChildren`, or `GetDescendants` every frame for stable trees. Cache the reference and refresh it from `ChildAdded`, `ChildRemoved`, `AncestryChanged`, or explicit lifecycle events.
- Do not iterate `CollectionService:GetTagged()` every frame. Build a cached set/list from `GetInstanceAddedSignal` and `GetInstanceRemovedSignal`.
- Replace `table.find` on growing collections with a set: `{ [key] = true }`.
- Cache `workspace.CurrentCamera` and update from `workspace:GetPropertyChangedSignal("CurrentCamera")`.
- Cache `Players.LocalPlayer.Character` from `CharacterAdded` instead of reading it every frame.

## Roblox API budget

- Do not create Instances, Tweens, or many Debris entries in hot loops. Use pooling for repeated temporary objects.
- Destroy or reuse Tweens created in loops.
- Rate-limit `RemoteEvent:FireServer`, `RemoteEvent:FireClient`, and `FireAllClients`. Prefer sending state changes, not per-frame noise.
- Avoid `CollectionService:AddTag` and `RemoveTag` every frame.

## Output expectation

When changing code, explain:

- Which path was hot.
- Which allocations or expensive calls were removed.
- Any tradeoff, especially cached state invalidation.
- How it was checked with available tests, lint, or targeted manual reasoning.
