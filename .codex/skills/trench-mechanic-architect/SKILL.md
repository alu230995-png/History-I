---
name: trench-mechanic-architect
description: Design and implement complete gameplay mechanics in the Trench-Track Roblox project with clean separation across server services, client controllers, shared constants/classes/types, remotes, state, and data. Use when adding match mechanics, lobby mechanics, queues, objectives, teams, scoring, deploy/spawn flows, tactical interactions, replicated state, validation, rate limiting, or cross-place features.
---

# Trench Mechanic Architect

## Project fit

Trench-Track is organized by place/domain:

- Shared core: `src/TrenchTrackCore`
- Lobby: `src/lobby`
- Match: `src/match`
- Server services: `server/Services`
- Client controllers: `client/Controllers`
- Shared constants/classes: `shared/Constants`, `shared/Classes`

Prefer the repo's current simple class style unless a dependency already in Wally clearly fits: Knit for service/controller orchestration, Reflex for state, Signal for local events, Trove for cleanup, ProfileService/ReplicaService for persistent and replicated data.

## Mechanic workflow

1. Define the mechanic contract in shared code first: constants, types, remote names, and any pure state class.
2. Put authoritative validation and state mutation on the server.
3. Put prediction, input, camera, HUD, and feedback on the client.
4. Keep remotes narrow and rate-limited. Clients request intent; server decides truth.
5. Add cleanup for every connection, timer, spawned object, and UI root.
6. Add focused validation: unit-style pure class checks when possible, plus manual or runtime checks for Roblox services.

## File placement

Use this placement by default:

- Shared constants: `src/<domain>/shared/Constants/<Mechanic>Constants.lua`
- Shared pure classes: `src/<domain>/shared/Classes/<Mechanic>State.lua`
- Core remote names: `src/TrenchTrackCore/Network/RemoteNames.lua`
- Server authority: `src/<domain>/server/Services/<Mechanic>Service.lua`
- Client control/UI bridge: `src/<domain>/client/Controllers/<Mechanic>Controller.lua`
- Cross-domain reusable types: `src/TrenchTrackCore/Types/RuntimeTypes.lua`

Only put code in `TrenchTrackCore` if lobby and match both need it.

## Server rules

- Never trust client payloads. Validate player, character, team, distance, cooldown, state, and match/lobby phase.
- Store per-player cooldowns as dictionaries keyed by `Player` or `UserId`.
- Clean up per-player state on `PlayerRemoving`.
- Avoid per-frame server loops unless the mechanic truly needs simulation. Prefer events, scheduled tasks, or state transitions.
- Keep persistent player data behind ProfileService-facing modules, not scattered service fields.

## Client rules

- Client controllers may cache LocalPlayer, Character, Humanoid, HumanoidRootPart, Camera, and UI roots.
- Update caches from events such as `CharacterAdded` and `CurrentCamera` changed signals.
- Keep gameplay center clear for HUD work and use the `trench-react-hud` skill for React UI.
- Disconnect input, character, render, and remote listeners in `Destroy()`.

## Shared state rules

- Shared classes should be pure when possible: no direct `game:GetService` calls, no Instances, no remotes.
- Keep enums/states exhaustive: every state needs a transition path or handler.
- Avoid `_G` and `shared`. Use module requires and explicit dependencies.

## Implementation checklist

- Shared contract exists.
- Server owns truth.
- Client owns presentation and input.
- Remotes are named, validated, and rate-limited.
- Cleanup is idempotent.
- Hot paths avoid unnecessary allocation.
- Tests or manual verification cover the main success path and one rejection path.

## Output expectation

When delivering a mechanic, summarize:

- Server files changed.
- Client files changed.
- Shared contract files changed.
- Validation and cleanup decisions.
