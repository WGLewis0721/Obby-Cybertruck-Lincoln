# Roblox Engineering Standard

Short project-specific guidance for contributors and AI tools working on `Obby-Cybertruck-Lincoln`.

Official references:
- https://create.roblox.com/docs/luau
- https://create.roblox.com/docs/scripting

## Current Architecture

- Server is authoritative for gameplay, persistence, vehicle spawning, purchases, checkpoints, timers, and map selection.
- Clients handle UI, camera, and player input.
- Shared modules live in `src/ReplicatedStorage/Shared`.
- RemoteEvents live in `src/ReplicatedStorage/Remotes.model.json` under `ReplicatedStorage.Remotes`.
- Server services live in `src/ServerScriptService/Services`.
- map/bootstrap scripts live in `src/ServerScriptService/Setup`.
- Mobile UI lives in `src/StarterGui`.
- Vehicle assets live in `src/ServerStorage`.

## Placement Rules

- Server logic: `*.server.lua` in `src/ServerScriptService/Services` or `src/ServerScriptService/Setup`
- Client UI/input: `*.client.lua` in `src/StarterGui`
- Client player scripts: `*.client.lua` in `src/StarterPlayer/StarterPlayerScripts/Client`
- Shared modules: `*.lua` in `src/ReplicatedStorage/Shared`
- Edit-time assets/models: `src/ServerStorage`, `src/ReplicatedStorage`, Rojo JSON model files

## Core Project Rules

- `PaintShopHandler.server.lua` is the only place that should own `MarketplaceService.ProcessReceipt`.
- Use `PlayerDataInterface` for persistence access. Do not create a second player-data cache or direct competing DataStore flow.
- Use constants from `ReplicatedStorage.Shared.Constants` instead of hardcoding key names, vehicle formats, or remote paths.
- Vehicle models in `ServerStorage` must match `VehicleData.ModelName` exactly.
- Spawned vehicles in `Workspace` must be named `Vehicle_<UserId>`.
- The default vehicle template is `Tesla Cybertruck`.
- The driver seat must be a `VehicleSeat` named `DriveSeat`.
- Vehicle models that are spawned/moved must have a valid `PrimaryPart`.
- Keep moving vehicle assemblies unanchored. Do not leave hidden anchored parts inside a spawned vehicle.
- `GarageHandler.server.lua` owns vehicle spawn/equip flow. Do not duplicate vehicle spawn logic in another server script.
- `MobileInputHandler.server.lua` owns `Remotes.MobileThrottle`.
- `MobileControls.client.lua` owns touch drive buttons.

## Vehicle Rules

- `VehicleTemplateFactory.lua` sanitizes vehicle templates before use.
- The Cybertruck template must preserve these defaults:
  - `DriveSeat.MaxSpeed = 60`
  - `DriveSeat.Torque = 20`
  - `DriveSeat.TurnSpeed = 1`
  - `DriveSeat.HeadsUpDisplay = false`
  - `DriveSeat.Disabled = false` by default in the template
- Desktop driving should continue to use Roblox vehicle controls.
- Mobile throttle is server-authoritative through `Remotes.MobileThrottle` because native client vehicle control can zero throttle on touch devices.
- If the vehicle model uses A-Chassis or another internal controller, preserve that architecture unless there is a verified reason to replace it.

## RemoteEvent Rules

- Access remotes with `ReplicatedStorage:WaitForChild("Remotes", timeout):WaitForChild("Name", timeout)`.
- Validate all client input on the server.
- Do not trust client ownership, seat state, race state, or currency values without server checks.
- If you add a new remote, add it to `src/ReplicatedStorage/Remotes.model.json`.
- After changing `src/default.project.json` or model JSON structure, restart `rojo serve`.

## Luau Style

- Use `game:GetService()`.
- Use `task.wait()`, `task.delay()`, `task.defer()`, and `task.spawn()` instead of deprecated APIs.
- Prefer defensive lookup patterns with timeouts for required instances.
- Use descriptive names and small helper functions.
- Add short comments only where the logic is not obvious.
- Prefer `Model:GetPivot()` / `Model:PivotTo()` for model movement unless an existing system intentionally relies on `PrimaryPart`.

## Refactor Safety

- Rojo is configured with `$ignoreUnknownInstances` in several services. Old scripts can remain in Studio after refactors.
- If you remove or rename a synced script, account for stale Studio instances on startup or by re-sync/restart.
- Do not leave duplicate handlers for the same remote, purchase callback, or vehicle spawn path.
- Before replacing a system, inspect the existing service that already owns that responsibility.

## Change Workflow

1. Decide whether the request is edit-time or run-time.
2. Read the owning service/module before changing anything adjacent to it.
3. Preserve current ownership boundaries unless the architecture is clearly wrong.
4. Make the smallest correct change that fits current project patterns.
5. Verify both desktop and mobile behavior when touching input, UI, or vehicles.

## Minimum Test Checklist

- Single-player spawn: one vehicle, correctly seated, no duplicate spawn.
- Respawn: old vehicle cleaned up, new vehicle spawns once.
- Two-player spawn: vehicles do not overlap.
- Desktop drive: arrow-key vehicle control still works.
- Mobile drive: touch throttle appears and drives correctly while seated.
- Purchases/remotes: no duplicate event handlers or stale scripts in Studio.
