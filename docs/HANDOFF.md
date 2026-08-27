# Cybertruck Racing — Current State & Handoff

Last updated: 2026-08-26. Written so you can take over cold.

---

## 0. READ THIS FIRST — the recurring "blue screen"

**It is not a bug in the game.** It happens in Studio **Edit mode** because the world
now lives at **X ≈ 1840–3600**, but the Studio viewport camera keeps getting parked
back near the origin, pointed at empty sky.

Fix it by running this in the Command Bar (setting `CFrame` alone does *not* stick —
it needs `CameraType` and `Focus` too):

```lua
local cam = workspace.CurrentCamera
local target = Vector3.new(2450, 10, -20)
cam.CameraType = Enum.CameraType.Fixed
cam.CFrame = CFrame.lookAt(target + Vector3.new(-600, 800, 1000), target)
cam.Focus = CFrame.new(target)
```

Or: select `workspace.CityHub` in Explorer and press **F**.

There is also an orphaned `workspace.Baseplate` still sitting at the origin — that
grey slab you sometimes see off to one side. Harmless; delete it when convenient.

---

## 1. World layout (all coordinates are world-space)

| Thing | Where | Notes |
|---|---|---|
| **City Circuit** (`workspace.SkyscraperMap`) | X 1840–3419, Z −454–581, Y ≈ 0–22 | Closed loop, 4,879 studs, 12 checkpoints + start/finish, 3 laps |
| **Lobby** (`workspace.CityHub`) | X 2027–2851, Z −343–291, Y ≈ 3.7+ | Your original hand-built city; sits in the circuit's infield |
| **Pit lane** (`SkyscraperMap.PitLane`) | Lobby SW corner → behind the start line | 14 segments; 11 inner-barrier pieces deleted to open the junction |
| **Player spawn** (`workspace.VehicleSpawn`) | (2358, 8, 266.5) | In the lobby. `GarageHandler` prioritises this over the per-map spawn |
| **Race grid** (`SkyscraperMap.SkyscraperSpawn`) | Behind start/finish | Not currently used for spawning |

**Current flow:** spawn in lobby → free drive (no timer, no coins) → drive out the
pit lane → crossing `Checkpoint_99` starts a timed 3-lap race.

**The lobby must stay ≥ ~2 studs above the circuit's `Terrain.Ground` plane.** If they
go coplanar the surfaces z-fight and at distance the green ground wins — the lobby
*looks deleted* but isn't. Current clearance is 5.1 studs.

---

## 2. What each system does

### Track generation (config-driven)
- `ReplicatedStorage.Module.TrackConfig` — the track's **shape**: 25 control points,
  road width, barrier height, coin spacing, checkpoint count, laps, `Origin`.
- `ServerScriptService.Services.TrackBuilder` — turns that into geometry. Runs the
  control points through a Catmull-Rom spline, then lays road, red/white curbing,
  barriers, checkpoints, coins, skyline, ground and kill-volume.
- `ServerScriptService.Setup.GenerateCityMap` — builds at server start **only if
  `SkyscraperMap` is missing**. It deliberately does **not** move `VehicleSpawn`.

To reshape the track, edit `TrackConfig` and run:
```lua
-- NOTE: require() caches; you MUST recreate the ModuleScript or you'll run stale code
local s = game.ServerScriptService.Services
local old = s.TrackBuilder; local src = old.Source; old:Destroy()
local m = Instance.new("ModuleScript"); m.Name = "TrackBuilder"; m.Source = src; m.Parent = s
require(m).Build("City")
```
Then rebuild the pit lane + barrier gap (see §5).

### Race / laps
`Services.CheckpointHandler` — `Checkpoint_99` is start/finish. Crossing it with no
active race **starts** one. Crossing again only counts once every numbered checkpoint
was hit **in order** (anti lap-skip), plus a `MIN_LAP_TIME` floor. Fires
`RaceStarted` / `CheckpointReached` / `LapCompleted` / `RaceFinished`.

### Coins
Any `BasePart` tagged **`CoinPickup`** (CollectionService) is auto-wired — new tracks
get pickups free.
- `Services.CoinPickupHandler` — server-authoritative collection + 20s respawn.
- `StarterGui.CoinPickupEffects` — spin/bob/sparkle/sound (cosmetic only).

### Economy / shop
- `Module.EconomyConfig` — coin rewards, pickup value, respawn time.
- `Module.ShopConfig` — paint + track prices, Robux product IDs.
- `Module.VehicleData` — **single source of truth for cars.** Drives spawning
  (`GarageHandler`), purchasing (`ShopService`) and the summon UI (`CarSelector`).
  Adding a car = one entry here + a Model of that `ModelName` in `ServerStorage`.
- `Services.ShopService` — server-validated coin purchases (`PurchaseWithCoins`,
  `GetShopState` RemoteFunctions) with per-player rate limiting.
- `StarterGui.PaintShopButton` — your original shop, extended with coin buttons
  alongside the existing Robux flow.
- `StarterGui.CarSelector` — "MY CARS" panel; select/summon owned cars, buy locked ones.

Robux `ProcessReceipt` stays defined **only** in `PaintShopHandler`.

---

## 3. Critical bugs found and fixed (do not regress these)

| Bug | Fix |
|---|---|
| `FindFirstAncestorWhichIsA("Model")` returns the inner `Wheels`/`Body` model, never `Vehicle_<id>` — so `Name:match("^Vehicle_(%d+)$")` **always failed**. This silently broke coins, checkpoints and laps *simultaneously*; the race system had never registered a single hit. | `Services.RaceUtil.GetPlayerFromHit()` walks the full ancestor chain. Always use it. |
| Roblox `LookVector` is the **−Z** axis, so `CFrame.new(0,3,-26)` put the start grid *past* the finish line — driving forward never crossed it, so no race ever began. | Use `+Z` to sit behind a gate. |
| `DataStoreService:GetDataStore()` throws when `game.PlaceId == 0`, cascading into every script that requires the data module. | `PlayerDataInterface` guards on `PlaceId` up front. |
| `require()` caches per ModuleScript instance — editing `.Source` from the command bar does nothing for the rest of the session. | Destroy + recreate the instance. |
| Moving parts individually by `CFrame` **compounds on unanchored welded assemblies**. This flung the `Playground` props to X≈67,000 and destroyed their internal geometry. | Anchor first, or move the Model with `PivotTo`. Lobby is now fully anchored. |

These are also recorded in the repo-root [CLAUDE.md](../../CLAUDE.md).

---

## 4. Known damage / outstanding issues

1. **`Playground` is gone.** Its swing set / merry-go-round / play structure were
   destroyed by the compounding bug above and I deleted them. Recoverable from
   `src/Workspace/Playground/*.rbxm` — drag in and position in the lobby.
2. **Filesystem sync is incomplete.** In git: `RaceUtil`, `TrackBuilder`, `TrackConfig`,
   `ShopConfig`, `ShopService`, `EconomyConfig`, `CheckpointHandler`, `CoinPickupHandler`,
   `CoinPickupEffects`, `VehicleData`, `GenerateCityMap`.
   **Studio-only (not in git yet):** `CarSelector`, and the patched `RaceHUD`,
   `PaintShopButton`, `OutOfBoundsHandler`.
3. **Nothing is published.** The live game predates all of this. Save (Ctrl+S) *and*
   publish, or a Studio crash loses everything.
4. Cars 2–4 in `VehicleData` reference models (`Tesla Model 3`, `Roadster`, `Model Y`)
   that **don't exist in `ServerStorage`** — summoning them will warn and no-op.
5. `ServerStorage.fixesv2` is an unfamiliar script that isn't mine and doesn't match
   this project's structure. It hasn't run. Delete if you don't recognise it.
6. The track got dragged out of place at one point (found at Y≈125). If geometry ever
   looks wrong, rebuild from config rather than nudging it by hand.

---

## 5. Your next goal: separate lobby from track + race via menu

You want the lobby and racing map to be **separate places-in-one**, with racing
started by **selecting a map in the sidebar menu**, not by driving onto the circuit.

### Recommended approach

**Step 1 — Physically separate them.** Move `CityHub` well clear of the circuit
(e.g. `Origin + Vector3.new(0, 0, 4000)`), so the lobby is its own area rather than
the infield. Move as a unit and mind the compounding bug:
```lua
workspace.CityHub:PivotTo(workspace.CityHub:GetPivot() + Vector3.new(0, 0, 4000))
```
Then delete `SkyscraperMap.PitLane` and rebuild the track so the barrier gap closes
(the circuit should be fully walled once it's no longer entered by driving).

**Step 2 — Add a teleport-to-race flow.** Add a `StartRace` RemoteEvent. Server-side:
```
StartRace(player, mapId)
  -> validate player owns mapId (ShopService already exposes ownership)
  -> destroy their current vehicle
  -> spawn it on SkyscraperSpawn (the grid) via GarageHandler's spawnVehicle
  -> optionally run a 3-2-1 countdown before releasing throttle
```
`GarageHandler` already has `spawnVehicle(player, vehicle)` and honours a spawn
CFrame — point it at `SkyscraperMap.SkyscraperSpawn` instead of `workspace.VehicleSpawn`.

**Step 3 — Make the race start explicitly, not on line-cross.** Right now
`CheckpointHandler.onFinishLineTouched` starts a race when no race is active. Change
that: have `StartRace` call `startRace()` directly, and make `onFinishLineTouched`
**only** handle lap completion (early-return if there's no active race). That's a
small edit — the lap logic is already separated into `startRace` / `finishRace` /
`onFinishLineTouched`.

**Step 4 — Add a "Return to Lobby" action** after `RaceFinished` that teleports the
player back and clears race state (`RaceAgain` already resets state server-side).

**Step 5 — Wire the sidebar.** The existing HUD buttons live in
`StarterGui.GameHUD` (Shop / Garage / Map). The **Map** button currently just shows a
"coming soon" toast — that's the natural place to hang the track-select menu.
`ShopConfig.Tracks` already carries name/difficulty/style/price/ownership, so the
menu can be built from it the same data-driven way `CarSelector` is built from
`VehicleData`.

### Why this ordering
Steps 2–3 are the real behavioural change and are testable while the lobby is still
in the infield. Do them first if you want quick feedback; do Step 1 first if you'd
rather see the separation immediately.

---

## 6. Quick verification snippet

Paste into the Command Bar (Edit mode) to confirm everything is wired:

```lua
local CS = game:GetService("CollectionService")
local map, hub = workspace:FindFirstChild("SkyscraperMap"), workspace:FindFirstChild("CityHub")
print("track:", map and map:GetAttribute("CenterlineStuds"), "laps:", map and map:GetAttribute("TotalLaps"))
print("coins tagged:", #CS:GetTagged("CoinPickup"))
print("checkpoints:", map and #map.Checkpoints:GetChildren())
print("lobby parts:", hub and #hub:GetDescendants())
for _, n in ipairs({"RaceUtil","TrackBuilder","CheckpointHandler","CoinPickupHandler","ShopService"}) do
    print(n, game.ServerScriptService.Services:FindFirstChild(n) ~= nil)
end
```

Expected: 4879 studs / 3 laps / 40 coins / 14 checkpoints / all services `true`.
