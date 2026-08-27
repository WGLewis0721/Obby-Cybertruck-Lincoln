# Handoff — Obby-Cybertruck-Lincoln

Last updated: 2026-08-27. Written so GitHub Copilot (or any agent) can pick this
project up cold. Read [copilot-instructions.md](copilot-instructions.md) first for
coding conventions — this file is about *current state*, not style rules.

The repo root also has `docs/Instructions.md`, a fuller engineering-process doc
(inspect → research → plan → implement → test → verify) written for Claude Code but
equally applicable here. Skim it if you're about to touch vehicle physics, mobile
input, or DataStore/purchase code — it documents the project's actual architecture
and the file-vs-Studio divergence risk described below.

---

## 0. The one thing that will bite you: Studio DataModel vs. tracked source

This project has **three sources of truth that can silently disagree**:

```
FILESYSTEM / ROJO SOURCE  <->  ROBLOX STUDIO DATAMODEL  <->  RUNTIME STATE
```

Most of the game is decomposed into `.lua`/`.luau` files under `src/`, synced live via
`rojo serve` — edits there are safe and immediately reflected in Studio.

**But `src/ServerStorage/Tesla Cybertruck.rbxm` is an opaque binary blob**, not
decomposed source. If you (or an agent) edit anything inside that model *live in
Studio* — a script's `Source`, a property like `Tach.Visible`, anything — **that
change lives only in Studio's in-memory DataModel.** It is NOT written back to the
`.rbxm` file automatically. Close Studio without an explicit save-and-syncback cycle
and the edit is gone; the model reverts to whatever the tracked `.rbxm` still says.

This exact thing happened this session: gauge fixes (hiding the RPM tach, fixing the
speedometer's max-speed cap) were applied live, appeared to work, then silently
reverted after a Studio restart because they were never persisted.

**To persist a live edit inside `Tesla Cybertruck.rbxm`:**
1. In Studio, `File -> Save As` over the actual local place file (see below — this
   project's Studio session opens directly from a **published Roblox place**
   (`placeId 85655774877098`), so plain `Ctrl+S` saves to Roblox's cloud, not to a
   local file — you must explicitly Save As to a local `.rbxl` path).
2. Run a **narrowly scoped** `rojo syncback`, e.g.:
   ```json
   {
     "name": "Obby-Cybertruck-Lincoln",
     "tree": {
       "$className": "DataModel",
       "ServerStorage": {
         "$className": "ServerStorage",
         "$ignoreUnknownInstances": true,
         "Tesla Cybertruck": { "$path": "src/ServerStorage/Tesla Cybertruck.rbxm" }
       }
     }
   }
   ```
   `rojo syncback --input <the .rbxl> --dry-run --list <this temp project>` first —
   **do not** syncback against the main `default.project.json` directly; it currently
   errors out (`StarterPlayer` present only in the project file, not the saved
   place — an unresolved mismatch, see §4) and a full syncback would also pull in an
   untracked `ServerStorage.ArchitectureBackup_20260324_222829` folder full of dead
   legacy scripts that should NOT re-enter the tracked tree.
3. Delete the temp project file once done.

If something you fixed in Studio "reverts" for no reason, **this is almost certainly
why.** Check whether the object lives inside `Tesla Cybertruck.rbxm` before assuming
you're losing your mind.

---

## 1. Roblox Studio MCP connection (for AI agents)

The `Roblox_Studio` MCP server is registered user-scope in Claude Code as:
```json
{ "command": "cmd.exe", "args": ["/c", "cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat"] }
```
If Studio-connected tools report zero connected studios even though
`RobloxStudioBeta.exe` / `StudioMCP.exe` / `rojo.exe` are all running, the bridge
handshake has gone stale — remove and re-add the MCP server registration to force a
fresh subprocess. **Do this by editing the config JSON directly** (or via
`claude mcp add` with the args split as separate array entries), not via a shell
one-liner with `/c` in it — Git Bash on Windows silently mangles a bare `/c` argument
into a `C:/` path, corrupting the command.

---

## 2. What changed this session (2026-08-27)

- **Rojo desync fixed**: was running an unofficial npm Rojo build reporting
  `7.7.0-rc.1`; replaced with the official `winget install Rojo.Rojo` build (`7.7.0`),
  fresh Studio plugin install.
- **Mobile driving rebuilt**: `StarterGui/MobileControls.client.luau` now uses a real
  analog steering joystick (12% deadzone, per-touch `InputObject` identity tracking)
  instead of discrete left/right buttons, writing to `MobileActive` /
  `MobileThrottle` / `MobileBrake` / `MobileSteer` value objects that the AC6
  `Drive` script's Stepped loop reads directly — same logical action state keyboard
  input feeds (`_GThrot` / `_GSteerT` / `_GBrake`), per the "one control-state feeds
  every input method" rule in `docs/Instructions.md` §14–16.
- **Dead code removed**: `AutoBuild/` (had a forbidden nitro/boost system),
  `VehiclePhysicsHandler`, `MobileInputHandler`, `InputProcessor`, several duplicate
  mobile-controls scripts, dead `VehicleInput`/`MobileThrottle` remotes.
- **Load-time lag fixed**: `ResponsiveHudController` / `RestoreHudFeatures` were each
  running a full un-debounced `PlayerGui:GetDescendants()` scan on *every* GUI
  descendant insertion during the ~300-instance initial-load burst. Now debounced via
  `task.defer`. Also: `Workspace/HD Admin/Core/Loader` (third-party admin plugin) was
  requiring its module for every player; gated behind an owner-only check so
  non-owner joins skip it entirely.
- **Speedometer cluster redesigned** (was two overlapping dials, RPM tach and
  speedo literally sharing one position):
  - RPM tach hidden (`Tach.Visible = false`) — one gauge, not two.
  - `maxSpeed` in `Gauges_AC6`'s `UNITS.MPH` table raised `45 -> 100` (needle used to
    pin at 45mph while the car does 90+; it now scales correctly).
  - Gear number and transmission-mode badge (`Gear` / `TMode` TextLabels) must stay
    **direct children of `AC6_Compact_Gauges`**, siblings of `Speedo` — the gauge
    script does `script.Parent:WaitForChild("Gear")` at load and
    `script.Parent.TMode.Text = ...` by direct indexing elsewhere. Reparenting either
    one under `Speedo` (which seemed like the natural way to make them "orbit" the
    dial) silently hangs the whole gauge script forever on the `WaitForChild`. Fixed
    by keeping them as siblings and instead positioning them dynamically from
    `ResponsiveHudController` (same file that already manages `Speedo`/`Speed`),
    computed relative to Speedo's live scale/anchor so they track the dial across
    screen sizes without colliding with its tick-mark arc.
  - Speedometer sized up (300px desktop / 150-235px touch, from 220 / 116-190).
- Fixed this session's regressions: `CheckpointHandler` variable-scoping bug
  (`progressFunction` declared inside an `if` block, used outside it),
  `GameHUD.client.lua` missing `end`, duplicated block in `RaceHUD.client.lua`.

## 3. Verification notes / known test gaps

- Gauge fixes were verified structurally (script source re-read after edit, live
  property inspection) and the tick-arc/needle/labels were confirmed rendering
  correctly via an in-Studio screenshot. **Actual live-speed needle sweep was not
  verified** — synthetic throttle input (both keyboard injection and the mobile
  bridge) could not get the AC6 chassis out of Park/Neutral in a scripted test
  session (`TransmissionMode` stayed `""`, `Gear` stayed `0` no matter what). This
  looks like an ignition/gear-engagement sequencing quirk specific to scripted input,
  not a defect in the gauge code — but do a real manual drive-test to be sure.
- Mobile controls were verified for wiring/structure, not on a physical touch device.

---

## 4. Known outstanding issues (carried over, not addressed this session)

1. **`ServerStorage.fixesv2`** — an unrecognized script, doesn't match this project's
   structure, hasn't been traced. Investigate before assuming it's safe to delete.
2. **`default.project.json` full-tree `rojo syncback` is currently blocked**: fails
   with `The child 'StarterPlayer' of Instance ... is present only in a project file,
   and not the provided file.` Root cause not yet diagnosed — needs investigation
   before any full-project syncback (as opposed to the narrowly-scoped kind described
   in §0) will work.
3. **`Playground` destroyed** (pre-existing, from a compounding-CFrame bug moving
   unanchored welded parts). Recoverable from `src/Workspace/Playground/*.rbxm` —
   never re-added to the lobby.
4. **Cars 2-4 in `VehicleData`** reference ServerStorage models (`Tesla Model 3`,
   `Roadster`, `Model Y`) that don't exist — summoning them will warn and no-op.
5. **Lobby/track separation** (turning the circuit into a menu-selected race rather
   than something you drive onto) is a real but unstarted feature — see the old
   `docs/HANDOFF.md` §5 for a still-valid step-by-step plan if picked up.
6. Nothing has been published this session. The live game predates all of the above
   fixes until someone explicitly publishes.

---

## 5. Quick orientation

- **Single vehicle registry**: `ReplicatedStorage.Module.VehicleData`. One entry here
  + a Model in `ServerStorage` = a new car. Don't create a second list.
- **Config over code**: track shape in `Module.TrackConfig`, prices in
  `Module.ShopConfig` / `Module.EconomyConfig`.
- **Coins are tag-driven**: any `BasePart` tagged `CoinPickup` is auto-wired by
  `CoinPickupHandler`.
- **`ProcessReceipt`** has exactly one authoritative implementation, in
  `PaintShopHandler.server.lua`. Never add a second one.
- Full architecture/gotchas table: repo-root `CLAUDE.md` and `docs/Instructions.md`.
