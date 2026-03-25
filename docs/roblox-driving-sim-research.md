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
		| `PascalCase` | Services, classes, RemoteEvents, ModuleScript export tables |
		| `camelCase` | Local variables, function names, parameters |
			| `LOUD_SNAKE_CASE` | Module-level constants |
			| `_camelCase` | Private members (underscore prefix) |

			### Deprecated APIs — Always Replace
			| ❌ Deprecated | ✅ Current |
			|---|---|
			| `wait()` | `task.wait()` |
			| `spawn()` | `task.spawn()` |
			| `delay()` | `task.delay()` |
			| `game.Players` | `game:GetService("Players")` |
			| `BodyVelocity` | `LinearVelocity` constraint |
			| `BodyGyro` | `AngularVelocity` constraint |

			### Player Keying
			```lua
			-- ✅ CORRECT — UserId never changes
			playerDataCache[player.UserId] = data

			-- ❌ WRONG — Name can change
			playerDataCache[player.Name] = data
			```

			### Guard Clauses
			Use early returns to handle nil/invalid state rather than deeply nested if-blocks:
				```lua
				-- ✅ CORRECT
				local vehicle = workspace:FindFirstChild("Vehicle_" .. player.UserId)
				if not vehicle then
					warn("[VehicleManager] No vehicle found for UserId: " .. player.UserId)
					return
				end
				-- continue with vehicle logic
				```

				---

				## 5. FILE DIRECTORY

				### ServerScriptService (server scripts)

				| File | What it does |
				|---|---|
				| `GarageHandler.server.lua` | Handles `EquipVehicle` remote; verifies ownership; spawns/replaces vehicle in Workspace named `Vehicle_[UserId]`; loads and saves PlayerData to DataStore `PlayerData_v1` |
				| `PaintShopHandler.server.lua` | 🚫 **DO NOT TOUCH** — `ProcessReceipt` lives here; handles paint job, Speed Boost, Ultimate Bundle, and map purchases; fires `ApplyBoost`, `BundlePurchased`, `MapPurchased`, `OwnedMapsSync` |
				| `GenerateCityMap.server.lua` | Procedurally generates `SkyscraperMap` folder in Workspace if absent; places `Checkpoint_N` Parts inside |
					| `GenerateMountainMap.server.lua` | Procedurally generates `BigFootMap` folder in Workspace if absent |
						| `GenerateRaceTrackMap.server.lua` | Procedurally generates `HighSpeedMap` folder in Workspace if absent |
							| `test.server.lua` | Prints "Rojo is working!" — diagnostic only |
							| `GenerateCityMap.lua` | Non-server reference copy of city map generator (not auto-run) |
							| `GenerateMountainMap.lua` | Non-server reference copy of mountain map generator |
							| `GenerateRaceTrackMap.lua` | Non-server reference copy of race track generator |

							### StarterGui (client UI scripts)

							| File | What it does |
							|---|---|
							| `MainMenu.client.lua` | Main menu on launch; orbiting camera around Tesla Cybertruck; background music |
							| `GarageMenu.client.lua` | Full-screen garage UI; browse, equip, purchase vehicles; fires `EquipVehicle` |
							| `PaintShopButton.client.lua` | Paint shop UI; paint jobs and map purchase cards; fires `OpenPaintShop` |
							| `BoostHandler.client.lua` | Perks hotbar UI; shows ⚡ Speed Boost button when `ApplyBoost` fires; applies 30% MaxSpeed boost on click |
							| `ShopGui_d/LoadShop.client.lua` | Loads shop item list from `ShopItems` module into `ShopGui_d` ScrollingFrame |

							### StarterPlayer/StarterPlayerScripts/Client (client player scripts)

							| File | What it does |
							|---|---|
							| `ShopButtonHandler.client.lua` | Wires the ShopButton in `ShopGui_d` to fire `OpenPaintShop` RemoteEvent on click |
							| `ShopMenuScript.client.lua` | Toggles visibility of `ShopGui_d` Main frame when ShopButton is clicked |

							### ReplicatedStorage/Module (shared data modules)

							| File | What it does |
							|---|---|
							| `PlayerData.lua` | Defines `GetDefault()` schema; helper functions `OwnsVehicle`, `HasMap`, `UpdateBestTime`; no DataStore calls |
							| `VehicleData.lua` | Array of all vehicle definitions (`Id`, `Name`, `Price`, `ProductId`, `Unlocked`, `ModelName`, `Stats`, `Thumbnail`) |
							| `MapData.lua` | Array of all map definitions (`Id`, `Name`, `Description`, `Unlocked`, `Type`, `Price`, `ProductId`, `BestTimeTarget`, `FolderName`, `SpawnName`, `Thumbnail`) |
							| `ShopItems.lua` | Array of paint job items, Speed Boost, and Ultimate Bundle (`Name`, `ProductId`, `Color/Type`, `Pic`, `Price`) |

							---

							## 6. REMOTEEVENTS REFERENCE

							Direction: **C→S** = Client fires to Server | **S→C** = Server fires to Client

							| EventName | Path in ReplicatedStorage | Direction | Who fires it | Who listens |
							|---|---|---|---|---|
							| `OpenPaintShop` | `ReplicatedStorage.OpenPaintShop` | C→S | `PaintShopButton`, `ShopButtonHandler` | `PaintShopHandler` |
							| `PurchaseSuccess` | `ReplicatedStorage.PurchaseSuccess` | S→C | *(declared; not actively fired)* | *(declared; not actively consumed)* |
							| `ApplyPaintJob` | `ReplicatedStorage.ApplyPaintJob` | S→C | *(declared; not actively fired)* | *(declared; not actively consumed)* |
							| `ApplyBoost` | `ReplicatedStorage.ApplyBoost` | S→C | `PaintShopHandler` (Speed Boost purchase) | `BoostHandler` |
							| `BundlePurchased` | `ReplicatedStorage.BundlePurchased` | S→C | `PaintShopHandler` (Ultimate Bundle) | `BoostHandler` |
							| `MapPurchased` | `ReplicatedStorage.MapPurchased` | S→C | `PaintShopHandler` (map purchase) | `PaintShopButton` |
							| `OwnedMapsSync` | `ReplicatedStorage.OwnedMapsSync` | S→C | `PaintShopHandler` (paint shop opens) | `PaintShopButton` |
							| `OpenGarage` | `ReplicatedStorage.Events.OpenGarage` | S→C | `PaintShopHandler` (Ultimate Bundle) | `GarageMenu` |
							| `EquipVehicle` | `ReplicatedStorage.Events.EquipVehicle` | C→S | `GarageMenu` | `GarageHandler` |

								> **Access patterns:**
								> - Top-level events: `ReplicatedStorage:WaitForChild("EventName")`
								> - Events-folder events: `ReplicatedStorage:WaitForChild("Events"):WaitForChild("EventName")`

							### Vehicle Input Pipeline (to be implemented)
							These three RemoteEvents are required for the vehicle physics pipeline and do not yet exist:

								| EventName | Direction | Payload | Purpose |
								|---|---|---|---|
								| `VehicleInput` | C→S | `{throttle: number, steer: number, brake: number}` | Client sends raw input every Heartbeat |
								| `HUDUpdate` | S→C | `{speedMph: number, rpm: number, gear: number}` | Server sends vehicle state to HUD |
								| `VehicleSpawned` | S→C | `{vehicleName: string, spawnPosition: Vector3}` | Server notifies client vehicle is ready |

								---

								## 7. DATASTORE FIELD MAP

									**DataStore name:** `PlayerData_v1`
									**Key format:** `Player_[UserId]` (e.g. `Player_123456`)
									**Written by:** `GarageHandler.server.lua` and `PaintShopHandler.server.lua`

								| Field | Type | Default | Written by | Notes |
								|---|---|---|---|---|
								| `EquippedVehicle` | `number` | `1` | `GarageHandler` | VehicleData `Id` of current vehicle |
								| `OwnedVehicles` | `array<number>` | `{1}` | `GarageHandler`, `PaintShopHandler` | Always includes `1`; values are VehicleData Id numbers |
								| `OwnedMaps` | `array<string>` | `{}` | `PaintShopHandler` | Display Name strings (e.g. `"Skyscraper"`) — NOT Id strings |
								| `BestTimes` | `table<string, number>` | `{}` | *(not yet wired)* | Keys are MapData Id strings; values are seconds |
								| `OwnedPaints` | `array<string>` | `{}` | `PaintShopHandler` | Paint job name strings (e.g. `"Green"`, `"Gold"`) |
								| `HasBoost` | `boolean` | `false` | `PaintShopHandler` | `true` if Speed Boost perk is purchased |

									> **NEVER** invent new field names. **NEVER** write the entire table from scratch.
									> Always: **read → modify specific fields → write back**.

									---

									## 8. MAP REFERENCE

									| MapId (string) | Display Name | Workspace Folder | SpawnLocation | Type |
									|---|---|---|---|---|
									| `"skyscraper"` | Skyscraper | `SkyscraperMap` | `SkyscraperSpawn` | Free |
									| `"bigfoot"` | Big Foot | `BigFootMap` | `BigFootSpawn` | Robux (199 R$) |
									| `"highspeed"` | High Speed | `HighSpeedMap` | `HighSpeedSpawn` | Robux (299 R$) |

									- Map folders are generated at runtime by the corresponding `Generate*.server.lua` script if they do not already exist.
											- Each map folder is a **direct child of Workspace**.
											- Map `ProductId` values in `MapData.lua` are currently `0` (placeholder). Replace with real Developer Product IDs before going live.

											---

											## 9. VEHICLE REFERENCE

											| VehicleId (number) | ModelName in ServerStorage | Type | Name in Workspace when spawned |
											|---|---|---|---|
											| `1` | `Tesla Cybertruck` | Free (default) | `Vehicle_[UserId]` |
											| `2` | `Tesla Model 3` | Robux (100 R$) | `Vehicle_[UserId]` |
											| `3` | `Tesla Roadster` | Robux (200 R$) | `Vehicle_[UserId]` |
											| `4` | `Tesla Model Y` | Robux (150 R$) | `Vehicle_[UserId]` |

											- Every player starts with VehicleId `1` in `OwnedVehicles`.
												- Vehicle models must exist in **ServerStorage** with names matching `ModelName` exactly.
												- When spawned, the model is renamed to `Vehicle_[UserId]` and parented to Workspace.
												- Only one vehicle per player exists in Workspace at a time. Old one is destroyed before spawning.
												- Spawn position priority:
												1. `BasePart` named `VehicleSpawn` in Workspace
											2. 10 studs in front of player's `HumanoidRootPart`
											3. World origin `(0, 5, 0)` as last resort

											### Current Vehicle Physics (A-Chassis)
											The Tesla Cybertruck uses the **A-Chassis** system. Known issues from audit:
												- Uses deprecated `BodyGyro` — needs migration to `AngularVelocity` constraint
											- `A-Chassis Tune` ModuleScript lives inside the vehicle model in both Workspace and ServerStorage

											---

											## 10. CHECKPOINT STRUCTURE

												**Location:** Inside the map folder in Workspace.
												Example: `Workspace.SkyscraperMap.Checkpoint_1`

												**Naming:** `Checkpoint_N` where N is an integer starting at 1.
											The highest-numbered checkpoint is the **finish line**.

												**Physical properties:**
												```
											Size:         Vector3.new(ROAD_WIDTH, 0.5, 4)
											Transparency: 0.5
											Material:     Enum.Material.Neon
											Anchored:     true
											CanCollide:   false
											Color:        Color3.fromRGB(74, 240, 255)  -- electric cyan
											```

												**Detection pattern (exact Luau):**
												```lua
											local checkpoint = mapFolder:FindFirstChild("Checkpoint_" .. N)
											checkpoint.Touched:Connect(function(hit)
												local vehicle = workspace:FindFirstChild("Vehicle_" .. player.UserId)
												if vehicle and hit:IsDescendantOf(vehicle) then
													-- player reached checkpoint N
												end
											end)
											```

												**Finish line behavior:**
												Reaching the final checkpoint should stop the timer and record:
												`PlayerData.UpdateBestTime(data, mapId, elapsedTime)` → saves to `PlayerData_v1` under `BestTimes[mapId]`.

												---

												## 11. COMMON TASKS — EXACT INSTRUCTIONS

											### Check if a script already handles something
												Before writing new logic, check these files first:
													- **Purchase logic (paint, boost, bundle, maps):** `PaintShopHandler.server.lua`
												- **Vehicle equip and DataStore load/save:** `GarageHandler.server.lua`
												- **Garage UI:** `GarageMenu.client.lua`
												- **Paint shop UI:** `PaintShopButton.client.lua`
												- **Boost perk hotbar:** `BoostHandler.client.lua`
												- **Map generation:** `GenerateCityMap`, `GenerateMountainMap`, `GenerateRaceTrackMap`
												- **Shared data schemas:** `PlayerData.lua`, `VehicleData.lua`, `MapData.lua`, `ShopItems.lua`

												### Add a new script
												1. Create `.lua` file in the correct `src/` folder:
													- Server logic → `src/ServerScriptService/MyScript.server.lua`
												- Client UI → `src/StarterGui/MyScript.client.lua`
												- Client player script → `src/StarterPlayer/StarterPlayerScripts/Client/MyScript.client.lua`
												- Shared module → `src/ReplicatedStorage/Module/MyModule.lua`
												2. Use correct file extension: `.server.lua` for Scripts, `.client.lua` for LocalScripts, `.lua` for ModuleScripts.
															3. Save — Rojo syncs to Studio via `rojo serve`.

															### Add a new RemoteEvent
															1. Add to `default.project.json` under `ReplicatedStorage`:
																```json
															"MyEventName": {
																"$className": "RemoteEvent"
															}
															```
															2. **Restart `rojo serve`** after editing `default.project.json`.
																3. Access: `ReplicatedStorage:WaitForChild("MyEventName")`
															4. For Events-folder: add under `"Events"` node, access via `ReplicatedStorage:WaitForChild("Events"):WaitForChild("MyEventName")`

															### Add a new map
															1. Add entry to `src/ReplicatedStorage/Module/MapData.lua` with all required fields.
																2. Create `src/ServerScriptService/GenerateNewMap.server.lua` that generates a Workspace folder and places `Checkpoint_N` Parts.
																3. Add a SpawnLocation Part named `[SpawnName]` inside the generated folder.
																4. If paid (`Type = "Robux"`): create a Developer Product on Roblox Creator Dashboard and update `ProductId`.

																### Add a new vehicle
															1. Add entry to `src/ReplicatedStorage/Module/VehicleData.lua` with all required fields. Use next sequential integer for `Id`.
																2. Add the vehicle `Model` to **ServerStorage** in Studio with the exact same name as `ModelName`.
																3. If paid: create Developer Product, update `ProductId`, add purchase handler in `PaintShopHandler.server.lua`'s `ProcessReceipt`.
																4. Ensure the Model has a `PrimaryPart` set so `SetPrimaryPartCFrame` works in `GarageHandler`.

																	### Add a new checkpoint to a map
																1. Find the highest existing `N` by scanning `mapFolder:GetChildren()` for names matching `"Checkpoint_"`.
																	2. Create a new `Part` named `Checkpoint_[N+1]`.
																	3. Set: `CanCollide = false`, `Transparency = 0.5`, `Material = Enum.Material.Neon`, `Color = Color3.fromRGB(74, 240, 255)`, `Anchored = true`.
																	4. Parent to the map folder (e.g. `Workspace.SkyscraperMap`).

																	### Add a currency (Coins) field to a player
																	> *(No Coins field exists yet in `PlayerData_v1`. This shows the correct pattern.)*
																	1. Add `Coins = 0` to `PlayerData.GetDefault()` in `PlayerData.lua`.
																	2. To award coins on server:
																	```lua
																	local data = playerDataStore:GetAsync("Player_" .. player.UserId)
																	data.Coins = (data.Coins or 0) + amount   -- modify specific field only
																	playerDataStore:SetAsync("Player_" .. player.UserId, data)
																	```
																		**NEVER** overwrite the whole data table.

																		### Award a new vehicle to a player
																	1. Read data: `playerDataStore:GetAsync("Player_" .. player.UserId)`
																	2. Guard: `if not data.OwnedVehicles then data.OwnedVehicles = {1} end`
																	3. Deduplicate: `if not table.find(data.OwnedVehicles, vehicleId) then`
																	4. Insert: `table.insert(data.OwnedVehicles, vehicleId)`
																	5. Write back: `playerDataStore:SetAsync("Player_" .. player.UserId, data)`
																		> `vehicleId` must be a **number** matching `Id` in `VehicleData.lua`.

																		---

																		# PART TWO — TECHNICAL REFERENCE

																	---

																	## 12. PROMPTING & LLM WORKFLOW

																	### Universal System Prompt — Paste at the Start of Every AI Session

																	```
																	You are a senior Roblox game developer and Luau architect.
																		This project is a DRIVING SIMULATOR (not a racing game) called
																	"Obby-Cybertruck-Lincoln" built in Roblox Studio using Luau.

																		BEFORE writing any code, restate my request as:
																		> DIRECTIVE: [one sentence — what this script does]
																		> SCRIPT TYPE: [Script / LocalScript / ModuleScript]
																		> LOCATION: [exact hierarchy path in the project]
																		> DEPENDS ON: [RemoteEvents, modules, services this touches]
																		> BOUNDARY: [Server / Client / Shared]
																		> EDGE CASES: [at least 2 things that could go wrong]

																	ALWAYS:
																		- --!strict at line 1
																		- Header: -- SCRIPT: [name] | LOCATION: [path] | SIDE: [Server/Client/Shared]
																		- Services via game:GetService() — never globals
																	- task.wait() not wait() | task.spawn() not spawn()
																	- player.UserId as dictionary keys — never player.Name
																	- PascalCase: services, RemoteEvents, module export tables
																	- camelCase: local variables, function names, parameters
																		- LOUD_SNAKE_CASE: module-level constants
																		- Guard clauses for nil checks — fail early with warn(), not silently

																			NEVER:
																				- Use deprecated APIs: BodyVelocity, BodyGyro, wait(), spawn(), delay()
																			- Write client code that modifies server-authoritative state directly
																			- Put game logic (physics, data, purchases) in LocalScripts
																			- Access services via globals (game.Players, game.Workspace)
																			- Create a second ProcessReceipt handler anywhere
																			- Overwrite the entire PlayerData table — always read → modify → write
																			```

																			### Debug Prompt Template
																			```
																			ERROR: [exact text from Output window]
																			SCRIPT: [name] | TYPE: [Script/LocalScript/ModuleScript] | LOCATION: [path]
																			EXPECTED: [what should happen]
																			ACTUAL: [what is happening]
																			RELATED SCRIPTS: [any RemoteEvents, modules, or other scripts involved]
																			CODE: [paste the relevant function only — not the whole script]
																			```

																			### Prompt Anti-Patterns

																			| ❌ Weak | ✅ Strong |
																			|---|---|
																			| "Write a car script" | "Write a server Script in ServerScriptService/Services/ that listens to the VehicleInput RemoteEvent and applies AngularVelocity to the front HingeConstraints for steering..." |
																			| "Fix my error" | Use the debug template above |
																			| "Make it better" | "Refactor this function to use --!strict types, replace wait() with task.wait(), and add guard clauses for nil vehicle and nil player" |
																			| "Add a speedometer" | "Write a LocalScript in StarterGui that listens to the HUDUpdate RemoteEvent and updates a TextLabel named 'SpeedLabel' with the vehicle's speedMph value rounded to the nearest integer" |
																			| "Update the data" | "Read the PlayerData_v1 DataStore for key Player_[UserId], add vehicleId 3 to OwnedVehicles if not already present, write only that field back" |

																			### OpenGameEval Key Insight
																			LLMs (including Claude and ChatGPT) score near-perfect on **single-script atomic tasks** but fail significantly on **multi-script coordination**. Always break requests into one script at a time.

																				---

																				## 13. TOOLCHAIN — ROJO

																			| Resource | URL |
																			|---|---|
																			| Rojo Official Docs v7 | https://rojo.space/docs/v7/ |
																			| Rojo GitHub | https://github.com/rojo-rbx/rojo |
																			| Rojo DeepWiki | https://deepwiki.com/rojo-rbx/rojo |

																				**Current version:** 7.6.1 (November 2025) | 7.7.0-rc.1 in progress

																			### default.project.json Structure
																			```json
																			{
																				"name": "Obby-Cybertruck-Lincoln",
																				"tree": {
																					"$className": "DataModel",
																					"ServerScriptService": {
																						"$className": "ServerScriptService",
																						"$path": "src/ServerScriptService"
																					},
																					"ReplicatedStorage": {
																						"$className": "ReplicatedStorage",
																						"$path": "src/ReplicatedStorage"
																					},
																					"StarterGui": {
																						"$className": "StarterGui",
																						"$path": "src/StarterGui"
																					},
																					"StarterPlayer": {
																						"$className": "StarterPlayer",
																						"StarterPlayerScripts": {
																							"$className": "StarterPlayerScripts",
																							"$path": "src/StarterPlayer/StarterPlayerScripts"
																						}
																					}
																				}
																			}
																			```

																			### File Naming Rules
																			| Filename | Becomes in Roblox |
																			|---|---|
																			| `MyScript.server.lua` | `Script` (server-side) |
																			| `MyScript.client.lua` | `LocalScript` |
																			| `MyModule.lua` | `ModuleScript` |
																			| `init.server.lua` (in folder) | Folder becomes a ServerScript |
																			| `init.client.lua` (in folder) | Folder becomes a LocalScript |
																			| `init.lua` (in folder) | Folder becomes a ModuleScript |

																			### CLI Commands
																			```bash
																			rojo serve                                                        # Live-sync to Studio
																			rojo build default.project.json                                   # Build .rbxl file
																			rojo sourcemap --watch default.project.json --output sourcemap.json  # Generate type map
																			rojo syncback default.project.json --input MyGame.rbxl           # Pull place to filesystem
																			rojo init                                                         # Scaffold new project
																			```

																			---

																			## 14. TOOLCHAIN — LUAU-LSP & VS CODE

																			| Resource | URL |
																			|---|---|
																			| luau-lsp Marketplace | https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp |
																			| luau-lsp GitHub | https://github.com/JohnnyMorganz/luau-lsp |

																			### Setup Steps
																			1. Install luau-lsp from VS Code Marketplace
																			2. Run `rojo sourcemap --watch` to keep `sourcemap.json` live
																			3. Add `sourcemap.json` to `.gitignore`
																			4. Create `.luaurc` at project root:
																				```json
																			{ "languageMode": "strict" }
																			```
																			5. Install the Studio companion plugin for live DataModel intellisense

																				### What luau-lsp Gives You
																				- Full Roblox API type definitions loaded automatically
																				- `goto definition`, hover docs, error highlighting
																				- Type-aware autocomplete for Roblox instances
																					- Type information that GitHub Copilot passively reads from open files

																					### Copilot CLI LSP Registration
																					Create `.github/lsp.json` in the repo root:
																						```json
																					{
																						"lspServers": {
																							"luau": {
																								"command": "luau-lsp",
																								"args": ["lsp"],
																								"fileExtensions": {
																									".lua": "luau",
																									".luau": "luau"
																								}
																							}
																						}
																					}
																					```

																					### Required Files in Every Project
																					| File | Location | Purpose |
																					|---|---|---|
																					| `default.project.json` | repo root | Rojo project definition |
																					| `.luaurc` | repo root | Luau strict mode config |
																					| `sourcemap.json` | repo root (gitignored) | Generated by `rojo sourcemap --watch` |
																					| `.gitignore` | repo root | Excludes `sourcemap.json`, build artifacts |
																					| `CLAUDE.md` | repo root | Claude Code reads this automatically |
																					| `.github/copilot-instructions.md` | repo root | Copilot agent instructions |
																					| `.github/lsp.json` | repo root | luau-lsp registration for Copilot CLI |

																						---

																						## 15. AI & LLM TOOLS FOR ROBLOX

																						### Native / Official
																						| Tool | URL | Notes |
																						|---|---|---|
																						| Roblox Studio AI Assistant | https://create.roblox.com/docs/tutorials/curriculums/building/code-with-assistant | Agentic 2025 update — scans full DataModel, debugs, integrates assets |
																						| OpenGameEval Benchmark | https://about.roblox.com/newsroom/2025/12/opengameeval-benchmark-agentic-ai-assistants-roblox-studio | Roblox's LLM performance benchmark for Roblox tasks |
																						| StarCoder / ZenML | https://www.zenml.io/llmops-database/scaling-generative-ai-in-gaming-from-safety-to-creation-tools | How Roblox trained its Luau code assist model |

																						### Third-Party Studio Plugins
																						| Tool | URL | Notes |
																						|---|---|---|
																						| RoCode v2.0 | https://devforum.roblox.com/t/plugin-rocode-v20-native-studio-ai-assistant-is-here/4354046 | Context-aware, sees your script hierarchy — Feb 2026 |
																						| RobloxAIBuilder | https://devforum.roblox.com/t/robloxaibuilder-ai-assistant-coding-builder-plugin/4528734 | Scripts + UI + 3D parts + animations — Mar 2026 |
																						| Ropanion AI | https://devforum.roblox.com/t/plugin-ropanion-ai-the-ai-assistant-roblox-studio-should-have-built-in/4028432 | Free community-built Studio AI plugin |

																						### LLM Capability Map (OpenGameEval findings)
																						| Task | LLMs | Notes |
																						|---|---|---|
																						| Single-instance manipulation | ✅ Near-perfect | Setting properties, basic API calls |
																						| Basic API knowledge / code gen | ✅ Strong | Single-script generation |
																						| Multi-step contextual reasoning | ❌ Low pass rates | Break into atomic requests |
																						| 3D hierarchy navigation | ❌ Struggles | Always provide structure as context |
																						| Cross-script coordination | ❌ Struggles | One script per prompt |

																						---

																						## 16. DRIVING SIMULATOR — DOMAIN & PHYSICS

																						### Core Vehicle Systems (Build Order)
																						```
																						1. Chassis frame  — Model with PrimaryPart = chassis body
																						2. Wheel mounts   — HingeConstraint × 4
																						3. Suspension     — SpringConstraint × 4 (tunable stiffness/damping)
																						4. Drive force    — AngularVelocity on rear HingeConstraints
																						5. Steering       — LowerAngle/UpperAngle limits on front HingeConstraints
																						6. Braking        — Reduce AngularVelocity target, friction multiplier
																						7. Weight transfer— Adjust SpringConstraint RestLength dynamically
																						8. VehicleSeat    — Occupant detection, client input relay
																						```

																						### Client-Server Vehicle Input Pipeline
																						```
																						CLIENT (LocalScript in StarterPlayerScripts)
																						└── Reads UserInputService (throttle, brake, steer, handbrake)
																						└── Fires RemoteEvent "VehicleInput" every RunService.Heartbeat
																						└── payload: { throttle: number, steer: number, brake: number }

																						SERVER (Script in ServerScriptService)
																						└── Receives VehicleInput
																						└── Passes through InputProcessor.sanitize() ← REQUIRED before physics
																						└── Applies AngularVelocity to drive HingeConstraints
																						└── Applies steer angle to front HingeConstraints
																						└── Fires "HUDUpdate" RemoteEvent back to client
																						└── IS THE AUTHORITY on vehicle position and velocity
																						```

																						### Domain Vocabulary
																						| Term | Definition |
																						|---|---|
																						| **Understeer** | Front loses grip before rear — car goes wide |
																						| **Oversteer** | Rear loses grip before front — car rotates |
																						| **Weight transfer** | Load shift during acceleration/braking/cornering |
																						| **Torque curve** | RPM-to-force mapping (engine feel) |
																						| **Slip angle** | Angle between wheel heading and travel direction |
																						| **Suspension travel** | Spring compression range (bump/rebound) |
																						| **Camber** | Vertical wheel tilt (affects tire contact patch) |
																						| **Drivetrain** | Engine → gearbox → differential → wheels |
																						| **Server authority** | Server owns physics truth; client sends input only |

																						### Roblox Vehicle Physics Resources
																						| Resource | URL |
																						|---|---|
																						| Vehicle Mechanics w/ Constraints | https://devforum.roblox.com/t/how-to-implement-vehicle-mechanics-using-constraints/3575431 |
																						| In-Depth Scripted Car Physics | https://devforum.roblox.com/t/in-depth-scripted-car-physics/3915628 |
																						| PBSE_CHASSIS open-source reference | https://devforum.roblox.com/t/physics-based-vehicle-simulation-game/2685401 |
																						| Realistic Car Physics Q&A | https://devforum.roblox.com/t/how-to-go-about-realistically-simulating-car-physics-in-roblox/658713 |

																						---

																						## 17. GAME DESIGN & ARCHITECTURE PATTERNS

																						| Resource | URL |
																						|---|---|
																						| Game Engine Architecture Guide | https://generalistprogrammer.com/game-engine-architecture |
																						| Game Design Patterns Guide | https://generalistprogrammer.com/game-design-patterns |
																						| Racing/Driving Game Design | https://gamedesignskills.com/game-design/racing/ |
																						| Programming a Driving Simulator | https://www.gtplanet.net/forum/threads/programming-a-driving-simulator-how-hard-can-it-be.324556/ |

																						### Server-Authoritative ECS-lite Pattern (Target Architecture)
																						```
																						ServerScriptService/
																							Services/
																							GarageHandler.server.lua        ← EXISTING: vehicle equip, DataStore
																						PaintShopHandler.server.lua     ← EXISTING: purchases, ProcessReceipt
																						VehicleManager.server.lua       ← TO CREATE: vehicle lifecycle
																						Setup/
																							GenerateCityMap.server.lua      ← EXISTING
																						GenerateMountainMap.server.lua  ← EXISTING
																						GenerateRaceTrackMap.server.lua ← EXISTING

																						ReplicatedStorage/
																							Module/
																							PlayerData.lua                  ← EXISTING: data schema + helpers
																						VehicleData.lua                 ← EXISTING: vehicle definitions
																						MapData.lua                     ← EXISTING: map definitions
																						ShopItems.lua                   ← EXISTING: shop catalog
																						InputProcessor.lua              ← TO CREATE: sanitize client input
																						Events/ (folder)
																						OpenGarage (RemoteEvent)        ← EXISTING
																						EquipVehicle (RemoteEvent)      ← EXISTING
																						[top-level RemoteEvents]          ← EXISTING: see Section 6
																						[VehicleInput, HUDUpdate, VehicleSpawned] ← TO CREATE: see Section 6

																						StarterGui/
																							MainMenu.client.lua               ← EXISTING
																						GarageMenu.client.lua             ← EXISTING
																						PaintShopButton.client.lua        ← EXISTING
																						BoostHandler.client.lua           ← EXISTING

																						StarterPlayer/StarterPlayerScripts/Client/
																							ShopButtonHandler.client.lua      ← EXISTING
																						ShopMenuScript.client.lua         ← EXISTING
																						VehicleController.client.lua      ← TO CREATE: input capture only

																						Workspace/
																							Vehicle_[UserId]                  ← RUNTIME: active vehicle per player
																						[MapFolders]/                     ← RUNTIME: generated at server start
																						VehicleSpawn (Part)               ← EXISTING: spawn anchor
																						```

																						---

																						## 18. LANGUAGE & RUNTIME — LUAU

																						| Resource | URL |
																						|---|---|
																						| Luau Official Website | https://luau.org/ |
																						| Luau Getting Started | https://luau.org/getting-started/ |
																						| Luau GitHub | https://github.com/luau-lang/luau |
																						| Luau Wikipedia | https://en.wikipedia.org/wiki/Luau_(programming_language) |
																						| Roblox Creator Docs — Luau | https://create.roblox.com/docs/luau |
																						| Luau Type Checking | https://create.roblox.com/docs/luau/type-checking |

																							**Key facts:**
																							- Derived from Lua 5.1 — all Lua 5.1 code is valid Luau
																						- Adds: optional static typing, string interpolation (backticks), generalized iteration, augmented assignment (`+=`, `-=`)
																						- Type modes: `--!nonstrict` (default) | `--!strict` (full) | `--!nocheck` (disable)
																						- Native codegen: `--!native` pragma gives 1.5–2.5× speedup on compute-heavy scripts
																						- Current version: 0.702+ (weekly releases from Roblox)

																						---

																						## 19. ALTERNATIVE LANGUAGES IN ROBLOX

																						| Language | Tool | Recommendation |
																						|---|---|---|
																						| **TypeScript** | roblox-ts (https://roblox-ts.com/docs/) | ❌ Not for this project — debug errors show compiled Luau, not TS source |
																							| **MoonScript** | moonscript compiler | ❌ Adds toolchain complexity |
																							| **Haxe** | Haxe compiler | ❌ Adds toolchain complexity |
																							| **Python/C** | roblox-pyc (experimental) | ❌ Immature, not production-ready |

																								**Recommendation:** Stick with native Luau. This is a parent-child learning project — adding a compiler layer makes debugging significantly harder with no meaningful benefit at this scale.

																								---

																								## 20. ROBLOX OFFICIAL DOCUMENTATION

																							| Resource | URL |
																							|---|---|
																							| Creator Hub — Main Docs | https://create.roblox.com/docs |
																							| Scripting Overview | https://create.roblox.com/docs/scripting |
																							| Script API Reference | https://create.roblox.com/docs/reference/engine/classes/Script |
																							| Game Design Docs | https://create.roblox.com/docs/production/game-design |
																							| AI Assistant Docs | https://create.roblox.com/docs/tutorials/curriculums/building/code-with-assistant |
																							| Creator Docs GitHub | https://github.com/Roblox/creator-docs |
																							| Roblox Lua Style Guide | https://roblox.github.io/lua-style-guide/ |
																							| Best Practices Handbook (DevForum) | https://devforum.roblox.com/t/best-practices-handbook/2593598 |
																							| Playbook — Design Pattern Library | https://devforum.roblox.com/t/playbook-a-community-built-roblox-design-pattern-library/4530265 |
																							| Luau Optimizations | https://devforum.roblox.com/t/luau-optimizations-and-using-them-consciously/3631483 |

																							---

																							## 21. QUICK REFERENCE — KEY FACTS

																							### Tool Versions (March 2026)
																							| Tool | Version |
																							|---|---|
																							| Rojo | 7.6.1 (stable) |
																							| luau-lsp | Active development — auto-updates via VS Code |
																							| Roblox Studio AI | 2025 Agentic update — full DataModel scan |
																							| Luau | 0.702+ (weekly releases) |

																							### Essential URLs
																							```
																							Creator Docs:   https://create.roblox.com/docs
																							Luau Spec:      https://luau.org/
																								Luau Types:     https://luau.org/typecheck
																							Rojo Docs:      https://rojo.space/docs/v7/
																								luau-lsp:       https://github.com/JohnnyMorganz/luau-lsp
																							Style Guide:    https://roblox.github.io/lua-style-guide/
																								DevForum:       https://devforum.roblox.com/
																								OpenGameEval:   https://about.roblox.com/newsroom/2025/12/opengameeval-benchmark-agentic-ai-assistants-roblox-studio
																							```

																							### The 3 Things Most Likely to Break Your Project
																							1. **Duplicate ProcessReceipt** — only one allowed per server, ever
																							2. **Writing the whole PlayerData table** instead of specific fields — corrupts data
																							3. **RemoteEvents in the wrong folder** — events fire and listen on different objects, silently fail

																								---

																								*Combined from: ROBLOX_AI_BRIEFING.md + roblox-driving-sim-research.md*
																								*Last updated: March 2026*