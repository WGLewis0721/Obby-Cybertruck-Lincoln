# ROBLOX AI MASTER REFERENCE
## Obby-Cybertruck-Lincoln — Driving Simulator

**Project:** Obby-Cybertruck-Lincoln ("Obby but in a Cybertruck")
**Type:** Driving Simulator (parent-child learning project) — NOT a racing game
**Stack:** Roblox Studio · Luau · Rojo v7.6.1 · VS Code · GitHub · GitHub Copilot · Claude
**Last Updated:** March 2026

---

## HOW TO USE THIS FILE

This is the **single source of truth** for all AI-assisted development on this project.

- **Before asking any AI tool anything**, paste the relevant section(s) into your prompt first.
- **Before writing any new script**, read Section 3 (Critical Rules) and Section 5 (File Directory).
- **Before asking about vehicle or map logic**, read Sections 7 and 8.
- **When debugging**, paste the relevant RemoteEvent table from Section 6 as context.
- **When prompting an LLM**, use the templates in Section 12 (Prompting Workflow).
- **When adding a new system**, update this file first so all future AI prompts have accurate context.

---

## TABLE OF CONTENTS

**PROJECT SPEC (Sections 1–11)**
1. [Game Overview](#1-game-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [Critical Rules](#3-critical-rules)
4. [Luau Code Standards](#4-luau-code-standards)
5. [File Directory](#5-file-directory)
6. [RemoteEvents Reference](#6-remoteevents-reference)
7. [DataStore Field Map](#7-datastore-field-map)
8. [Map Reference](#8-map-reference)
9. [Vehicle Reference](#9-vehicle-reference)
10. [Checkpoint Structure](#10-checkpoint-structure)
11. [Common Tasks — Exact Instructions](#11-common-tasks--exact-instructions)

**TECHNICAL REFERENCE (Sections 12–21)**
12. [Prompting & LLM Workflow](#12-prompting--llm-workflow)
13. [Toolchain — Rojo](#13-toolchain--rojo)
14. [Toolchain — luau-lsp & VS Code](#14-toolchain--luau-lsp--vs-code)
15. [AI & LLM Tools for Roblox](#15-ai--llm-tools-for-roblox)
16. [Driving Simulator — Domain & Physics](#16-driving-simulator--domain--physics)
17. [Game Design & Architecture Patterns](#17-game-design--architecture-patterns)
18. [Language & Runtime — Luau](#18-language--runtime--luau)
19. [Alternative Languages in Roblox](#19-alternative-languages-in-roblox)
20. [Roblox Official Documentation](#20-roblox-official-documentation)
21. [Quick Reference — Key Facts](#21-quick-reference--key-facts)

---

# PART ONE — PROJECT SPEC

---

## 1. GAME OVERVIEW

**Obby-Cybertruck-Lincoln** ("Obby but in a Cybertruck") is a Roblox driving-obby game.
Players drive a Tesla vehicle through obstacle courses (maps) as fast as possible.
The goal is to reach the finish line (the highest-numbered checkpoint) on each map with the best time.

This is a **driving simulator** — not a racing game. The key distinction:

| Dimension | Racing Game | This Project (Driving Simulator) |
|---|---|---|
| World | Closed track | Obstacle courses + open world areas |
| Goal | Finish first vs. opponents | Best personal time, exploration, progression |
| Physics | Arcade-acceptable | Realistic vehicle feel via constraint-based chassis |
| Vehicles | One type | Multiple Tesla models with different stats |
| Progression | Lap positions | Unlocks, best times, purchased maps/paint |

---

## 2. ARCHITECTURE OVERVIEW

This project uses a **server-authoritative architecture**. The server owns all game state. The client handles input and UI only.

```
CLIENT (LocalScript)                    SERVER (Script)
─────────────────────────────────────────────────────────
Reads UserInputService                  Owns vehicle physics
Renders UI (HUD, menus)                 Manages DataStore
Fires RemoteEvents with input/requests  Spawns/despawns vehicles
Receives state from server              Generates maps
NEVER mutates game state directly       NEVER trusts raw client input
```

### Canonical Folder Locations

| What | Where |
|---|---|
| Server game logic | `ServerScriptService/` |
| Server-only templates | `ServerStorage/` |
| Shared modules | `ReplicatedStorage/Module/` |
| RemoteEvents (most) | `ReplicatedStorage/` (top-level) |
| RemoteEvents (grouped) | `ReplicatedStorage/Events/` |
| Client UI scripts | `StarterGui/` |
| Client player scripts | `StarterPlayer/StarterPlayerScripts/Client/` |
| Active vehicle in world | `Workspace/Vehicle_[UserId]` |
| Map folders | `Workspace/[FolderName]` (e.g. `SkyscraperMap`) |

---

## 3. CRITICAL RULES

> These rules exist to prevent data corruption, duplicate callbacks, and silent failures.
> Violating any of these will break the game.

- `ProcessReceipt` is defined **ONLY** in `ServerScriptService/PaintShopHandler.server.lua`. **NEVER** add another `ProcessReceipt` callback anywhere else — Roblox only allows one per server.
- DataStore name is **`PlayerData_v1`**. Key format is **`Player_[UserId]`** (capital P). **NEVER** change either — doing so orphans all existing player data.
- Player vehicles in Workspace are always named **`Vehicle_[UserId]`**. **NEVER** rename them — checkpoint detection depends on this exact naming.
- Checkpoint Parts are named **`Checkpoint_N`** (N = integer starting at 1) and live **inside the map folder** in Workspace. The final checkpoint is the highest-numbered one.
- **NEVER** overwrite the entire PlayerData table. Always **read → modify specific fields → write back** with `SetAsync`.
- Server handles ALL game logic (purchases, data, vehicle spawning, map generation). Client handles **UI only**.
- `GarageHandler.server.lua` owns the `playerDataCache` in-memory table. Do **NOT** create a second cache for the same DataStore in another script.
- RemoteEvents inside `ReplicatedStorage/Events/` folder: access via `ReplicatedStorage:WaitForChild("Events"):WaitForChild("EventName")`.
- Top-level RemoteEvents: access via `ReplicatedStorage:WaitForChild("EventName")`.
- VehicleData `Id` values are **numbers** (1, 2, 3, 4). MapData `Id` values are **strings** (`"skyscraper"`, `"bigfoot"`, `"highspeed"`). **NEVER** mix them.
- `OwnedMaps` array in PlayerData stores the map **display Name strings** (e.g. `"Skyscraper"`), not the Id strings.
- There is **NO** `CoinHandler.server.lua`, **NO** `CheckpointHandler.server.lua`, and **NO** `MapSelectHandler.server.lua` in this project. Do not reference or create them.
- Vehicle models in ServerStorage must match the `ModelName` field in `VehicleData.lua` exactly. **NEVER** rename them independently.
- Use `task.wait()` not `wait()`. Use `task.spawn()` not `spawn()`. Use `task.delay()` not `delay()`. **NEVER** use deprecated Roblox APIs.

---

## 4. LUAU CODE STANDARDS

All scripts in this project must follow these standards without exception.

### Type Mode
```lua
--!strict   ← required at line 1 of every script
```

### Required Header Block
Every script must begin with:
```lua
--!strict
-- SCRIPT: [ScriptName] | LOCATION: [HierarchyPath] | SIDE: [Server/Client/Shared]
```

### Service Acquisition
```lua
-- ✅ CORRECT
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- ❌ WRONG — never use globals
local Players = game.Players
local workspace = game.Workspace
```

### Naming Conventions (Roblox Official Style Guide)
| Pattern | Use For |
|---|---|
| PascalCase | Services, Classes, RemoteEvents, ModuleScript exports |
| camelCase | local variables, function names, parameters |
| LOUD_SNAKE_CASE | constants |
| _prefixUnderscore | private members |

---

## 5. FILE DIRECTORY

```
game/
├── ReplicatedStorage/
│   ├── Events/                    # RemoteEvents (grouped)
│   │   ├── VehicleInput          # Client → Server: vehicle input
│   │   ├── VehicleSpawned        # Server → Client: vehicle ready
│   │   ├── HUDUpdate             # Server → Client: speed/rpm/gear
│   │   ├── ApplyBoost            # Client → Server: boost activation
│   │   ├── OpenPaintShop         # Client → Server: open paint UI
│   │   ├── OpenGarage            # Client → Server: open garage UI
│   │   ├── OpenMapSelect         # Client → Server: open map select
│   │   ├── Horn                  # Client → Server: honk horn
│   │   └── ... (other events)
│   └── Module/                    # Shared ModuleScripts
│       ├── Constants.lua         # Game constants
│       ├── Logger.lua            # Logging utility
│       ├── VehicleData.lua       # Vehicle definitions
│       ├── MapData.lua           # Map definitions
│       ├── PlayerData.lua        # PlayerData type + defaults
│       ├── EventBus.lua          # Server-side event bus
│       └── InputProcessor.lua    # Input sanitization
│
├── ServerScriptService/
│   ├── Services/
│   │   ├── GarageHandler.server.lua      # Vehicle spawning
│   │   ├── PaintShopHandler.server.lua   # Paint shop + ProcessReceipt
│   │   ├── PlayerDataInterface.lua      # DataStore wrapper
│   │   ├── PlayerDataService.lua        # Player data loading
│   │   ├── VehiclePhysicsHandler.lua    # Server-side physics
│   │   ├── VehicleTemplateFactory.lua   # Vehicle model factory
│   │   └── TimerHandler.lua             # Race timing
│   ├── Setup/
│   │   ├── GenerateCityMap.lua          # Skyscraper map generator
│   │   ├── GenerateMountainMap.lua      # Bigfoot map generator
│   │   └── GenerateRaceTrackMap.lua     # Highspeed map generator
│   └── Documentation/                    # AI docs (ignored at runtime)
│       ├── AI-Reference.lua
│       └── AI-Instructions.lua
│
├── StarterGui/
│   ├── MobileControls.client.lua        # Mobile touch UI
│   ├── GarageMenu.client.lua            # Garage UI
│   ├── PaintShopButton.client.lua       # Paint shop button
│   ├── RaceHUD.client.lua               # Race HUD
│   ├── GameHUD.client.lua               # Game HUD
│   └── BoostHandler.client.lua          # Boost UI
│
└── StarterPlayer/
    └── StarterPlayerScripts/
        └── Client/
            └── VehicleController.client.lua  # Keyboard input
```

---

## 6. REMOTEEVENTS REFERENCE

### Client → Server Events

| Event | Payload | Purpose |
|---|---|---|
| `VehicleInput` | `(throttle, steer, brake)` | Send vehicle input to server |
| `ApplyBoost` | `()` | Activate vehicle boost |
| `OpenPaintShop` | `()` | Request paint shop UI |
| `OpenGarage` | `()` | Request garage UI |
| `OpenMapSelect` | `()` | Request map selection UI |
| `Horn` | `()` | Honk vehicle horn |
| `EquipVehicle` | `(vehicleId)` | Equip a vehicle |
| `SelectMap` | `(mapId)` | Select a map |

### Server → Client Events

| Event | Payload | Purpose |
|---|---|---|
| `VehicleSpawned` | `(vehicleName, position)` | Notify client vehicle is ready |
| `HUDUpdate` | `(speed, rpm, gear)` | Update HUD display |
| `ApplyPaintJob` | `(color)` | Apply paint to vehicle |
| `CheckpointReached` | `(checkpointNum)` | Notify checkpoint reached |
| `RaceStarted` | `()` | Race has started |
| `RaceFinished` | `(time)` | Race has finished |

---

## 7. DATASTORE FIELD MAP

```lua
PlayerData = {
    UserId = 0,
    Coins = 0,
    EquippedVehicle = 1,        -- VehicleData.Id (number)
    OwnedVehicles = {1},        -- Array of VehicleData.Id (numbers)
    OwnedMaps = {"Skyscraper"}, -- Array of map display names (strings)
    BestTimes = {},             -- mapId → bestTime
    EquippedPaint = "Default",  -- Paint color name
    TotalPlayTime = 0,          -- Seconds
}
```

---

## 8. MAP REFERENCE

| Map Name | Id | Description |
|---|---|---|
| Skyscraper | `"skyscraper"` | City skyline obstacle course |
| Bigfoot | `"bigfoot"` | Mountain forest trail |
| Highspeed | `"highspeed"` | Race track with boost pads |

---

## 9. VEHICLE REFERENCE

| Vehicle | Id | ModelName | Stats |
|---|---|---|---|
| Tesla Cybertruck | 1 | `"Tesla Cybertruck"` | Balanced |
| Tesla Model 3 | 2 | `"Tesla Model 3"` | Speed |
| Tesla Roadster | 3 | `"Tesla Roadster"` | Acceleration |
| Tesla Model Y | 4 | `"Tesla Model Y"` | Comfort |

---

## 10. CHECKPOINT STRUCTURE

Checkpoints are Parts named `Checkpoint_N` inside the map folder:
- `Checkpoint_1` through `Checkpoint_N-1`: Regular checkpoints
- `Checkpoint_N` (highest number): Finish line

---

## 11. COMMON TASKS — EXACT INSTRUCTIONS

### Adding a New Vehicle
1. Add model to `ServerStorage/` with exact `ModelName`
2. Add entry to `VehicleData.lua` with unique `Id` (number)
3. Add to `ShopItems.lua` if purchasable

### Adding a New Map
1. Create generator in `ServerScriptService/Setup/`
2. Add entry to `MapData.lua` with unique `Id` (string)
3. Add spawn marker named `{MapName}Spawn`

### Adding a New RemoteEvent
1. Create in `ReplicatedStorage/Events/`
2. Document in this file (Section 6)
3. Use `WaitForChild` with timeout

---

# PART TWO — TECHNICAL REFERENCE

---

## 12. PROMPTING & LLM WORKFLOW

When prompting an LLM:
1. Paste relevant sections from this file first
2. Be specific about what you want
3. Include error messages if debugging
4. Ask for `--!strict` compliant code

---

## 13-21. [Additional technical reference sections omitted for brevity]

See full documentation in the source file.

---

return {}
