# ROBLOX AI BRIEFING — Obby-Cybertruck-Lincoln

---

## HOW TO USE THIS FILE

- **Before asking the Roblox AI Assistant anything**, paste the relevant section(s) below into your prompt first.
- If you are adding a new system, **update this file first** so the AI has accurate context on every future prompt.
- If something breaks, check the **CRITICAL RULES** section first.

---

## 1. GAME OVERVIEW

**Obby-Cybertruck-Lincoln** ("Obby but in a Cybertruck") is a Roblox driving-obby game.  
Players drive a Tesla vehicle through obstacle courses (maps) as fast as possible.  
The goal is to reach the finish line (the highest-numbered checkpoint) on each map with the best time.

---

## 2. CRITICAL RULES

- `ProcessReceipt` is defined **ONLY** in `ServerScriptService/PaintShopHandler.server.lua`. NEVER add another `ProcessReceipt` callback anywhere else.
- DataStore name is **`PlayerData_v1`**. Key is **`Player_[UserId]`** (capital P). NEVER change the DataStore name or key format.
- Player vehicles in Workspace are always named **`Vehicle_[UserId]`**. NEVER rename them.
- Checkpoint Parts are named **`Checkpoint_N`** (N = integer, starting at 1) and live **inside the map folder** in Workspace. The final checkpoint is the highest-numbered one in that map.
- NEVER overwrite the entire PlayerData table. Always **read → modify specific fields → write back** with `SetAsync`.
- Server handles ALL game logic (purchases, data, vehicle spawning, map generation). Client handles UI ONLY.
- `GarageHandler.server.lua` owns the `playerDataCache` in-memory table. Do NOT create a second cache for the same DataStore in another script.
- All RemoteEvents under `ReplicatedStorage/Events/` (OpenGarage, EquipVehicle) must be accessed via `ReplicatedStorage:WaitForChild("Events"):WaitForChild("EventName")`.
- Top-level RemoteEvents (OpenPaintShop, PurchaseSuccess, ApplyPaintJob, ApplyBoost, BundlePurchased, MapPurchased, OwnedMapsSync) are accessed directly via `ReplicatedStorage:WaitForChild("EventName")`.
- VehicleData `Id` values are **numbers** (1, 2, 3, 4). MapData `Id` values are **strings** (`"skyscraper"`, `"bigfoot"`, `"highspeed"`). NEVER mix them.
- `OwnedMaps` array in PlayerData stores the map **display Name** strings (e.g. `"Skyscraper"`), not the Id strings.
- There is NO `CoinHandler.server.lua`, NO `CheckpointHandler.server.lua`, and NO `MapSelectHandler.server.lua` in this project. Do not reference them.
- Vehicle models in ServerStorage must match the `ModelName` field in `VehicleData.lua` exactly. NEVER rename them.
- Use `task.wait()` instead of `wait()`. Use `task.spawn()` instead of `spawn()`. NEVER use deprecated Roblox APIs.

---

## 3. FILE DIRECTORY

### ServerScriptService (server scripts)

| Location | File | What it does |
|---|---|---|
| `ServerScriptService/` | `GarageHandler.server.lua` | Handles `EquipVehicle` remote; verifies ownership; spawns/replaces vehicle model in Workspace; loads and saves PlayerData to DataStore `PlayerData_v1` |
| `ServerScriptService/` | 🚫 DO NOT TOUCH: `PaintShopHandler.server.lua` — `ProcessReceipt` lives here; handles paint job purchases, Speed Boost, Ultimate Bundle, and map purchases; fires `ApplyBoost`, `BundlePurchased`, `MapPurchased`, `OwnedMapsSync` to clients |
| `ServerScriptService/` | `GenerateCityMap.server.lua` | Procedurally generates the **SkyscraperMap** folder in Workspace if it does not already exist; places Checkpoint_N Parts inside the folder |
| `ServerScriptService/` | `GenerateMountainMap.server.lua` | Procedurally generates the **BigFootMap** folder in Workspace if it does not already exist |
| `ServerScriptService/` | `GenerateRaceTrackMap.server.lua` | Procedurally generates the **HighSpeedMap** folder in Workspace if it does not already exist |
| `ServerScriptService/` | `test.server.lua` | Prints "Rojo is working!" — diagnostic only |
| `ServerScriptService/` | `GenerateCityMap.lua` | Non-server copy of the city map generator (not auto-run by Roblox; exists for version control reference) |
| `ServerScriptService/` | `GenerateMountainMap.lua` | Non-server copy of the mountain map generator (reference only) |
| `ServerScriptService/` | `GenerateRaceTrackMap.lua` | Non-server copy of the race track generator (reference only) |

### StarterGui (client UI scripts)

| Location | File | What it does |
|---|---|---|
| `StarterGui/` | `MainMenu.client.lua` | Main menu on game launch; orbiting camera around Tesla Cybertruck; background music |
| `StarterGui/` | `GarageMenu.client.lua` | Full-screen garage UI; lets players browse, equip, and purchase vehicles; fires `EquipVehicle` |
| `StarterGui/` | `PaintShopButton.client.lua` | Paint shop UI; shows paint jobs and map purchase cards; fires `OpenPaintShop` |
| `StarterGui/` | `BoostHandler.client.lua` | Perks hotbar UI; shows ⚡ Speed Boost button when `ApplyBoost` fires; re-applies 30% MaxSpeed boost on click |
| `StarterGui/ShopGui_d/` | `LoadShop.client.lua` | Loads shop item list from `ShopItems` module into the `ShopGui_d` ScrollingFrame UI template |

### StarterPlayer/StarterPlayerScripts (client scripts)

| Location | File | What it does |
|---|---|---|
| `StarterPlayer/StarterPlayerScripts/Client/` | `ShopButtonHandler.client.lua` | Wires the ShopButton in `ShopGui_d` to fire `OpenPaintShop` RemoteEvent on click |
| `StarterPlayer/StarterPlayerScripts/Client/` | `ShopMenuScript.client.lua` | Toggles visibility of the `ShopGui_d` Main frame when ShopButton is clicked |

### ReplicatedStorage/Module (shared data modules)

| Location | File | What it does |
|---|---|---|
| `ReplicatedStorage/Module/` | `PlayerData.lua` | Defines `GetDefault()` schema; helper functions `OwnsVehicle`, `HasMap`, `UpdateBestTime`; no DataStore calls |
| `ReplicatedStorage/Module/` | `VehicleData.lua` | Array of all vehicle definitions (Id, Name, Price, ProductId, Unlocked, ModelName, Stats, Thumbnail) |
| `ReplicatedStorage/Module/` | `MapData.lua` | Array of all map definitions (Id, Name, Description, Unlocked, Type, Price, ProductId, BestTimeTarget, FolderName, SpawnName, Thumbnail) |
| `ReplicatedStorage/Module/` | `ShopItems.lua` | Array of paint job items, Speed Boost, and Ultimate Bundle (Name, ProductId, Color/Type, Pic, Price) |

---

## 4. REMOTEEVENTS QUICK REFERENCE

Direction: **C→S** = Client fires to Server | **S→C** = Server fires to Client

| EventName | Path in ReplicatedStorage | Direction | Who fires it | Who listens |
|---|---|---|---|---|
| `OpenPaintShop` | `ReplicatedStorage.OpenPaintShop` | C→S | `PaintShopButton.client.lua` / `ShopButtonHandler.client.lua` | `PaintShopHandler.server.lua` |
| `PurchaseSuccess` | `ReplicatedStorage.PurchaseSuccess` | S→C | *(declared; not actively fired in current scripts)* | *(declared; not actively consumed)* |
| `ApplyPaintJob` | `ReplicatedStorage.ApplyPaintJob` | S→C | *(declared; not actively fired in current scripts)* | *(declared; not actively consumed)* |
| `ApplyBoost` | `ReplicatedStorage.ApplyBoost` | S→C | `PaintShopHandler.server.lua` (on Speed Boost purchase) | `BoostHandler.client.lua` |
| `BundlePurchased` | `ReplicatedStorage.BundlePurchased` | S→C | `PaintShopHandler.server.lua` (on Ultimate Bundle purchase) | `BoostHandler.client.lua` |
| `MapPurchased` | `ReplicatedStorage.MapPurchased` | S→C | `PaintShopHandler.server.lua` (on map purchase) | `PaintShopButton.client.lua` |
| `OwnedMapsSync` | `ReplicatedStorage.OwnedMapsSync` | S→C | `PaintShopHandler.server.lua` (when paint shop opens) | `PaintShopButton.client.lua` |
| `OpenGarage` | `ReplicatedStorage.Events.OpenGarage` | S→C | `PaintShopHandler.server.lua` (after Ultimate Bundle purchase) | `GarageMenu.client.lua` |
| `EquipVehicle` | `ReplicatedStorage.Events.EquipVehicle` | C→S | `GarageMenu.client.lua` | `GarageHandler.server.lua` |

> **Note:** `OpenGarage` and `EquipVehicle` live inside the **`Events` Folder** under `ReplicatedStorage`. All other RemoteEvents are direct children of `ReplicatedStorage`.

---

## 5. DATASTORE FIELD MAP

DataStore name: **`PlayerData_v1`**  
Key format: **`Player_[UserId]`** (e.g. `Player_123456`)  
Written by: `GarageHandler.server.lua` and `PaintShopHandler.server.lua`

| FieldName | Type | Default | Written by | Notes |
|---|---|---|---|---|
| `EquippedVehicle` | `number` | `1` | `GarageHandler.server.lua` | VehicleData `Id` of the currently equipped vehicle |
| `OwnedVehicles` | `array<number>` | `{1}` | `GarageHandler.server.lua`, `PaintShopHandler.server.lua` | Array of owned VehicleData `Id` numbers; always includes `1` |
| `OwnedMaps` | `array<string>` | `{}` | `PaintShopHandler.server.lua` | Array of **display Name strings** (e.g. `"Skyscraper"`, `"Big Foot"`, `"High Speed"`) |
| `BestTimes` | `table<string, number>` | `{}` | *(not yet wired in current server scripts; updated via `PlayerData.UpdateBestTime()`)* | Keys are MapData `Id` strings (e.g. `"skyscraper"`); values are best lap time in seconds |
| `OwnedPaints` | `array<string>` | `{}` | `PaintShopHandler.server.lua` | Array of owned paint job name strings (e.g. `"Green"`, `"Blue"`, `"Gold"`) |
| `HasBoost` | `boolean` | `false` | `PaintShopHandler.server.lua` | `true` if the player has purchased the Speed Boost perk |

> NEVER invent new field names. NEVER write the entire table from scratch. Always read → modify → write specific fields only.

---

## 6. MAP QUICK REFERENCE

| MapId (string) | Display Name | Workspace Folder | SpawnLocation Name | Type |
|---|---|---|---|---|
| `"skyscraper"` | Skyscraper | `SkyscraperMap` | `SkyscraperSpawn` | Free |
| `"bigfoot"` | Big Foot | `BigFootMap` | `BigFootSpawn` | Robux (199 R$) |
| `"highspeed"` | High Speed | `HighSpeedMap` | `HighSpeedSpawn` | Robux (299 R$) |

- The map folder is generated at runtime by the corresponding `Generate*.server.lua` script if it does not already exist.
- Each map folder is a direct child of `Workspace`.
- Map `ProductId` values in `MapData.lua` are currently `0` (placeholder). Replace with real Developer Product IDs before going live.

---

## 7. VEHICLE QUICK REFERENCE

| VehicleId (number) | ModelName in ServerStorage | Type | Workspace name when spawned |
|---|---|---|---|
| `1` | `Tesla Cybertruck` | Free (default) | `Vehicle_[UserId]` |
| `2` | `Tesla Model 3` | Robux (100 R$) | `Vehicle_[UserId]` |
| `3` | `Tesla Roadster` | Robux (200 R$) | `Vehicle_[UserId]` |
| `4` | `Tesla Model Y` | Robux (150 R$) | `Vehicle_[UserId]` |

- Every player starts with VehicleId `1` in `OwnedVehicles`.
- Vehicle models must exist in **ServerStorage** with names matching `ModelName` exactly.
- When spawned, the model is renamed to `Vehicle_[UserId]` and parented to `Workspace`.
- Only one vehicle per player exists in Workspace at a time. The old one is destroyed before spawning the new one.
- Spawn position priority: (1) `BasePart` named **`VehicleSpawn`** in Workspace → (2) 10 studs in front of player's `HumanoidRootPart` → (3) world origin `(0, 5, 0)` as last resort.

---

## 8. CHECKPOINT STRUCTURE

**Where they live:** Inside the map folder in Workspace.  
Example: `Workspace.SkyscraperMap.Checkpoint_1`

**How they are named:** `Checkpoint_N` where N is an integer starting at 1.  
The highest-numbered checkpoint in the map folder is the finish line.

**Physical properties:**
- Size: `Vector3.new(ROAD_WIDTH, 0.5, 4)` — a flat slab spanning the road width; height `0.5` keeps it flush with the road surface; depth `4` studs ensures reliable vehicle collision detection even at high speed
- `Transparency = 0.5`
- `Material = Enum.Material.Neon`
- `Anchored = true`
- `CanCollide = false` (thin parts; vehicles should pass through them)
- Color: `Color3.fromRGB(74, 240, 255)` (electric cyan)

**How to detect a vehicle touching a checkpoint (exact Lua pattern):**
```lua
local checkpoint = mapFolder:FindFirstChild("Checkpoint_" .. N)
checkpoint.Touched:Connect(function(hit)
    local vehicle = workspace:FindFirstChild("Vehicle_" .. player.UserId)
    if vehicle and hit:IsDescendantOf(vehicle) then
        -- player reached checkpoint N
    end
end)
```

**What the final checkpoint means:**  
It is the finish line. Reaching it should stop the timer and record the run time to `PlayerData_v1` under `BestTimes[mapId]` using `PlayerData.UpdateBestTime(data, mapId, elapsedTime)`.

---

## 9. HOW TO ADD A NEW SCRIPT

1. Create the `.lua` file in the correct `src/` folder:
   - Server logic → `src/ServerScriptService/MyScript.server.lua`
   - Client UI/logic → `src/StarterGui/MyScript.client.lua`
   - Client player script → `src/StarterPlayer/StarterPlayerScripts/Client/MyScript.client.lua`
   - Shared module → `src/ReplicatedStorage/Module/MyModule.lua`
2. Use the correct file extension: `.server.lua` for server Scripts, `.client.lua` for LocalScripts, `.lua` for ModuleScripts.
3. Save the file — Rojo syncs it to Studio automatically via `rojo serve`.
4. If you added new RemoteEvents, add them to `default.project.json` under the correct path:
   - Top-level event: add under `"ReplicatedStorage"` alongside `"OpenPaintShop"` etc.
   - Grouped event: add under `"ReplicatedStorage" > "Events"` alongside `"OpenGarage"` and `"EquipVehicle"`.
   ```json
   "MyNewEvent": {
       "$className": "RemoteEvent"
   }
   ```
5. **Restart `rojo serve`** after editing `default.project.json` so the new RemoteEvents appear in Studio.
6. Access top-level events: `ReplicatedStorage:WaitForChild("MyNewEvent")`  
   Access Events-folder events: `ReplicatedStorage:WaitForChild("Events"):WaitForChild("MyNewEvent")`

---

## 10. COMMON TASKS WITH EXACT INSTRUCTIONS

### Task: Add a new checkpoint to a map

> The map folder lives in Workspace as a `Folder` instance.  
> Checkpoints are `Part` instances named `Checkpoint_N` where N is the next number in the existing sequence.  
> Find the highest existing N by scanning `mapFolder:GetChildren()` for names matching `"Checkpoint_"`.  
> Create a new `Part` named `Checkpoint_[N+1]`.  
> Set `CanCollide = false`, `Transparency = 0.5`, `Material = Enum.Material.Neon`, `Color = Color3.fromRGB(74, 240, 255)`, `Anchored = true`.  
> Position it on the road inside the map folder.  
> Parent it to the map folder (e.g. `Workspace.SkyscraperMap`).

### Task: Add a new RemoteEvent

> Add it to `default.project.json` under `ReplicatedStorage`:
> ```json
> "MyEventName": {
>     "$className": "RemoteEvent"
> }
> ```
> Then **restart `rojo serve`**. The event will appear in Studio automatically.  
> Access it in scripts via `ReplicatedStorage:WaitForChild("MyEventName")`.

### Task: Add a currency (Coins) field to a player — example implementation guide

> *(There is no Coins field in PlayerData_v1 yet. This section shows how to add it when needed.)*  
> 1. Add `Coins = 0` to `PlayerData.GetDefault()` in `src/ReplicatedStorage/Module/PlayerData.lua`.  
> 2. Then in server code to award coins:  
>    1. Read data: `local data = playerDataStore:GetAsync("Player_" .. player.UserId)`  
>    2. Modify only the Coins field: `data.Coins = (data.Coins or 0) + amount`  
>    3. Write back: `playerDataStore:SetAsync("Player_" .. player.UserId, data)`  
> NEVER overwrite the whole data table.

### Task: Award a new vehicle to a player

> 1. Read data from DataStore `PlayerData_v1` for key `Player_[UserId]`.  
> 2. Ensure `data.OwnedVehicles` exists: `if not data.OwnedVehicles then data.OwnedVehicles = {1} end`  
> 3. Check for duplicates: `if not table.find(data.OwnedVehicles, vehicleId) then`  
> 4. Add: `table.insert(data.OwnedVehicles, vehicleId)`  
> 5. Write back: `playerDataStore:SetAsync("Player_" .. player.UserId, data)`  
> The `vehicleId` must be a **number** matching the `Id` field in `VehicleData.lua`.

### Task: Check if a script already handles something

> Before writing new logic, check these files first:
> - **Purchase logic (paint, boost, bundle, maps):** `PaintShopHandler.server.lua`
> - **Vehicle equip and DataStore load/save:** `GarageHandler.server.lua`
> - **Garage UI:** `GarageMenu.client.lua`
> - **Paint shop UI:** `PaintShopButton.client.lua`
> - **Boost perk hotbar:** `BoostHandler.client.lua`
> - **Map generation:** `GenerateCityMap.server.lua`, `GenerateMountainMap.server.lua`, `GenerateRaceTrackMap.server.lua`
> - **Shared data schemas:** `ReplicatedStorage/Module/PlayerData.lua`, `VehicleData.lua`, `MapData.lua`, `ShopItems.lua`

### Task: Add a new map

> 1. Add a new entry to `src/ReplicatedStorage/Module/MapData.lua` with all required fields (`Id`, `Name`, `Description`, `Unlocked`, `Type`, `Price`, `ProductId`, `BestTimeTarget`, `FolderName`, `SpawnName`, `Thumbnail`).  
> 2. Create `src/ServerScriptService/GenerateNewMap.server.lua` that generates a Folder named `[FolderName]` in Workspace if it does not exist, and places Checkpoint_N Parts inside it.  
> 3. Add a SpawnLocation Part named `[SpawnName]` inside the generated folder.  
> 4. If the map is paid (`Type = "Robux"`), create a real Developer Product on the Roblox Creator Dashboard and update `ProductId` in `MapData.lua`.

### Task: Add a new vehicle

> 1. Add a new entry to `src/ReplicatedStorage/Module/VehicleData.lua` with all required fields (`Id`, `Name`, `Price`, `ProductId`, `Unlocked`, `ModelName`, `Stats`, `Thumbnail`). Use the next sequential integer for `Id`.  
> 2. Add the vehicle `Model` to **ServerStorage** in Studio with the exact same name as the `ModelName` field.  
> 3. If the vehicle is paid, create a real Developer Product on the Roblox Creator Dashboard, update `ProductId` in `VehicleData.lua`, and add a purchase handler inside `PaintShopHandler.server.lua`'s `ProcessReceipt` function.  
> 4. Ensure the Model has a `PrimaryPart` set so `SetPrimaryPartCFrame` works in `GarageHandler.server.lua`.
