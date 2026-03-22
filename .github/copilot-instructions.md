# GitHub Copilot Instructions

These instructions help GitHub Copilot generate code that matches the conventions of this Roblox Luau project.

---

## Language & Runtime

- All game scripts are written in **Luau** (Roblox's variant of Lua 5.1+).
- Client scripts use the `.client.lua` suffix (LocalScripts in Roblox).
- Server scripts use the `.server.lua` suffix (Scripts in Roblox).
- Shared modules use plain `.lua` files (ModuleScripts).

---

## Project Layout (Rojo)

| Folder | Roblox Service |
|--------|----------------|
| `src/ServerScriptService/` | `ServerScriptService` |
| `src/ReplicatedStorage/` | `ReplicatedStorage` |
| `src/StarterGui/` | `StarterGui` |
| `src/StarterPlayer/StarterPlayerScripts/` | `StarterPlayer.StarterPlayerScripts` |
| `src/StarterPlayer/StarterCharacterScripts/` | `StarterPlayer.StarterCharacterScripts` |

Use `default.project.json` as the Rojo project definition.

---

## Coding Conventions

### General
- Use **tabs** for indentation (consistent with existing files).
- Keep lines under **120 characters**.
- Prefer `local` variables over globals.
- Always use `local` for services obtained via `game:GetService()`.

### Services
Obtain Roblox services at the **top of the file**, in alphabetical order:
```lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
```

### RemoteEvents / RemoteFunctions
- Declare shared remotes in `ReplicatedStorage` via `default.project.json`.
- Use `WaitForChild` on the client when accessing remotes from `ReplicatedStorage`.

### GUI
- Create UI **programmatically** in LocalScripts — do not rely on Studio-created instances unless they come from a synced file.
- Use `UDim2.new(...)` for sizes and positions.
- Apply `Enum.Font.GothamBold` / `Enum.Font.Gotham` for text to match existing UI.
- Set `ResetOnSpawn = false` on `ScreenGui` instances created in client scripts.

### Naming
- **PascalCase** for Roblox instances (e.g., `ScreenGui`, `TextButton`).
- **camelCase** for local variables (e.g., `shopButton`, `paintJobs`).
- **SCREAMING_SNAKE_CASE** for constants (e.g., `MAX_PLAYERS`).

### Error Handling
- Use `warn(...)` for non-fatal issues (e.g., a GUI element not found).
- Use `error(...)` only for truly unrecoverable situations.

---

## Theming

The game has a **Cyberpunk / Tesla Cybertruck** aesthetic:
- Primary background: `Color3.fromRGB(10, 10, 20)` (near-black dark blue)
- Accent: `Color3.fromRGB(0, 210, 255)` (electric cyan)
- Secondary accent: `Color3.fromRGB(180, 180, 180)` (steel grey)
- Text: `Color3.new(1, 1, 1)` (white)
- Danger / close actions: `Color3.fromRGB(200, 50, 50)` (red)

---

## Animation
- Use `TweenService:Create(instance, TweenInfo.new(...), {property = target})` for smooth UI transitions.
- Prefer `Enum.EasingStyle.Quart` with `Enum.EasingDirection.Out` for enter animations.
- Prefer `Enum.EasingStyle.Quart` with `Enum.EasingDirection.In` for exit animations.

---

## Do Not
- Do not use deprecated Roblox APIs (e.g., `Instance.new("LocalScript")`).
- Do not use `wait()` — use `task.wait()` instead.
- Do not use `spawn()` — use `task.spawn()` instead.
- Do not hard-code player UserIds or asset IDs without a comment explaining them.

You are working in a Roblox Luau project.

System architecture:
- UIBuilder handles UI
- InputHandler handles button input
- SteeringController handles joystick
- VehicleController simulates A-Chassis key input
- NitroSystem manages boost resource
- CooldownSystem prevents boost spam

Rules:
- Do not create new systems
- Do not rename variables
- Only expand TODO blocks
- Maintain ControlState structure

Vehicle uses A-Chassis:
- W = accelerate
- S = brake
- A/D = steering
- Shift = boost
