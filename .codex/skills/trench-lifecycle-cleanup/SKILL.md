---
name: trench-lifecycle-cleanup
description: Find and fix memory leaks, lifecycle bugs, dead code, unused requires, untracked connections, stale tasks, and cleanup gaps in Trench-Track Roblox Luau modules. Use when reviewing Destroy methods, Signal or RBXScriptConnection usage, task.spawn or task.delay captures, Instance ownership, Tween cleanup, BaseObject patterns, Trove adoption, or dead state in services/controllers/classes.
---

# Trench Lifecycle Cleanup

## Project fit

Trench-Track currently uses simple table classes plus `Start()` methods, with `BaseObject` available in `src/TrenchTrackCore/Classes/BaseObject.lua`. Wally includes Trove and Signal. Prefer Trove for non-trivial lifecycle ownership, but keep simple modules simple.

## Cleanup contract

Every class that creates long-lived resources should have one owner and one cleanup path.

Use these fields consistently:

- `self._trove` for Trove-owned resources.
- `self._connections` only for small modules that do not need Trove.
- `self._destroyed` when guarding delayed callbacks or async work.
- `:Destroy()` for cleanup. It must be idempotent.

## Leak checks

Search for:

- `:Connect(` without assigning the connection, returning it, or adding it to Trove.
- `task.delay`, `task.spawn`, `Promise`, or callbacks that capture `self`, Instances, players, characters, UI roots, or services.
- `Instance.new` in modules with `Destroy()` that do not destroy every created Instance.
- `TweenService:Create` without cancelling or destroying old tweens.
- `BindableEvent`, `BindableFunction`, `RemoteEvent`, and Signal objects created but never destroyed.
- `Players.PlayerAdded`, `PlayerRemoving`, `CharacterAdded`, and input connections in client controllers without cleanup.

## Safe patterns

Prefer Trove when a module owns multiple resources:

```lua
local Trove = require(ReplicatedStorage.Packages.Trove)

function Controller.new()
	local self = setmetatable({}, Controller)
	self._trove = Trove.new()
	self._destroyed = false
	return self
end

function Controller:Start()
	self._trove:Add(signal:Connect(function(...)
		if self._destroyed then
			return
		end
		self:_handle(...)
	end))
end

function Controller:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._trove:Destroy()
end
```

For `task.delay`, capture only what is needed and guard destruction:

```lua
local version = self._version
task.delay(seconds, function()
	if self._destroyed or self._version ~= version then
		return
	end
	self:_finish()
end)
```

## Dead code rules

- Remove functions that are never called, unless they are public API used by Rojo/Roblox conventions or are intentionally documented.
- Remove `require` results that are never used.
- Remove boolean flags that are written but never read.
- Remove enum/state entries that have no transition, handler, or UI mapping.
- Keep `_unused` parameters only when the callback signature is meaningful. Otherwise remove the parameter.
- Treat impossible branches as architecture smells. Before deleting, verify the invariant from constants, types, or callers.

## Output expectation

When changing code, state:

- What owned the resource before and after.
- Which connections/tasks/instances now clean up.
- Which dead code was removed and how usage was checked.
