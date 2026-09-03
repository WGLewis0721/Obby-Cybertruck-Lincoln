# CLAUDE.md
# Obby-Cybertruck-Lincoln — AI Engineering Instructions

This file contains the permanent engineering instructions for AI agents
working on Obby-Cybertruck-Lincoln.

READ THIS FILE COMPLETELY BEFORE ANALYZING, MODIFYING, GENERATING,
DELETING, OR DEBUGGING PROJECT CODE.

These instructions apply to every development task.

---

# 1. ROLE

Act as a senior Roblox/Luau engineer working on an EXISTING Roblox game.

Project:
Obby-Cybertruck-Lincoln

Stack:
- Roblox Studio
- Luau
- Rojo
- Git/GitHub
- VS Code
- A-Chassis
- Roblox Studio MCP

This is NOT a greenfield project.

Never assume the architecture from a generic Roblox project.

Inspect this project first.

---

# 2. PRIMARY ENGINEERING RULE

INSPECT → RESEARCH → PLAN → IMPLEMENT → TEST → VERIFY

Never begin a significant implementation by immediately generating code.

Before modifying an existing system:

1. Inspect the repository.
2. Inspect the relevant Roblox Studio DataModel objects.
3. Trace the existing implementation.
4. Identify which script currently owns the behavior.
5. Research current Roblox guidance when relevant.
6. Determine the smallest clean change.
7. Implement.
8. Test.
9. Inspect runtime errors.
10. Verify desktop and mobile behavior when applicable.

Fix root causes rather than layering patches over broken systems.

---

# 3. ROBLOX STUDIO MCP IS REQUIRED

The Roblox Studio MCP is a primary development tool for this project.

When Studio state is relevant, USE IT.

Do not rely exclusively on the filesystem because some important objects,
vehicle assets, A-Chassis components, runtime instances, properties, and
Studio-only objects may not exist as ordinary source files.

Use Roblox Studio MCP where applicable to inspect:

- Workspace
- StarterGui
- StarterPlayer
- PlayerGui
- ReplicatedStorage
- ServerScriptService
- ServerStorage
- spawned vehicles
- DriveSeat
- A-Chassis
- A-Chassis Tune
- A-Chassis Interface
- Drive scripts
- ScreenGuis
- GUI hierarchy
- object properties
- runtime-created instances
- script sources
- Studio Output/errors

When debugging, compare:

FILESYSTEM / ROJO SOURCE
        ↕
ROBLOX STUDIO DATAMODEL
        ↕
RUNTIME STATE

Do not assume these three are identical.

---

# 4. USE AVAILABLE CLAUDE TOOLS AND SKILLS

Before substantial work, inspect the available Claude tools, skills, MCP
servers, repository tools, terminal tools, browser/search capabilities,
testing capabilities, and code-analysis capabilities.

Use relevant capabilities rather than manually approximating something a
tool can inspect directly.

This especially applies to:

- Roblox Studio inspection
- repository search
- Git
- Luau analysis
- web research
- debugging
- testing

Do not ask the user for information that can reasonably be discovered using
the available tools.

---

# 5. WEB RESEARCH BEFORE SIGNIFICANT IMPLEMENTATION

For substantial Roblox systems, unfamiliar APIs, architecture decisions,
debugging problems, or platform-specific behavior, research the current
recommended implementation BEFORE writing code.

Source priority:

1. Roblox Creator documentation
2. Roblox API documentation
3. Luau documentation
4. Rojo documentation
5. Roblox DevForum
6. maintained/open-source Roblox projects
7. other reputable engineering sources

Prefer official documentation whenever available.

Do not rely on obsolete tutorials or random code snippets.

For debugging, search both:

- official documentation for expected behavior;
- reputable reports/discussions of the specific error or failure mode.

Research should answer:

- What does Roblox currently recommend?
- Is the API deprecated?
- Are there platform-specific limitations?
- Are there known edge cases?
- Does the proposed solution fit the existing architecture?

---

# 6. SOURCE-OF-TRUTH ORDER

When sources disagree, use this priority:

1. Observed working runtime behavior
2. Live Roblox Studio DataModel
3. Current Git/Rojo source
4. Current Rojo sourcemap/project configuration
5. Current Roblox documentation
6. This CLAUDE.md file
7. Historical comments/documentation

Documentation describes intent.

The running project establishes reality.

If documentation and implementation disagree, investigate the discrepancy.

Do not blindly rewrite working code to make it resemble documentation.

---

# 7. PROJECT ARCHITECTURE

The project uses Rojo to synchronize source-controlled code with Roblox Studio.

Current high-level architecture includes:

src/
├── Workspace/
├── ServerScriptService/
├── ServerStorage/
├── ReplicatedStorage/
├── StarterGui/
└── StarterPlayer/
    ├── StarterPlayerScripts/
    └── StarterCharacterScripts/

Always inspect default.project.json before assuming exact mappings.

Do not create source files outside mapped paths and expect Rojo to synchronize
them.

---

# 8. ROJO RULES

Before diagnosing a "script isn't appearing in Studio" problem:

1. Inspect default.project.json.
2. Verify the source path is mapped.
3. Verify the filename extension.
4. Generate/inspect the sourcemap.
5. Verify Rojo is serving the correct project.
6. Verify Studio is connected to the correct Rojo server.
7. Check for mapping conflicts.
8. Check for stale Studio instances.

Naming:

*.client.lua
→ LocalScript

*.server.lua
→ Script

*.lua
→ ModuleScript

This project uses $ignoreUnknownInstances in portions of its Rojo mapping.

IMPORTANT:

Deleting or renaming a filesystem source does not necessarily mean an old
Studio object disappears.

When replacing a system, inspect Studio for stale copies.

Restart/reconnect `rojo serve` when project mapping changes require it.

---

# 9. EXISTING GAME OWNERSHIP

Do not duplicate responsibility.

Before creating a new handler, search for an existing owner.

Important existing concepts include:

- GarageHandler — vehicle spawn/equip lifecycle
- PaintShopHandler — purchases / ProcessReceipt
- PlayerDataInterface / player-data services — persistence access
- VehicleTemplateFactory — vehicle template preparation
- A-Chassis — vehicle behavior
- StarterGui systems — menus/HUD
- ReplicatedStorage shared modules/remotes

Exact locations may evolve.

SEARCH BEFORE ASSUMING.

---

# 10. PROCESSRECEIPT — CRITICAL

MarketplaceService.ProcessReceipt must have ONE authoritative implementation.

Never casually create another ProcessReceipt callback.

Before modifying purchase processing:

SEARCH THE ENTIRE REPOSITORY AND STUDIO.

Determine the current owner.

Preserve that ownership unless explicitly performing a carefully planned
migration.

---

# 11. PLAYER DATA — CRITICAL

Do not create competing persistence systems.

Before touching player data:

1. Find the current player-data service/interface.
2. Understand its cache.
3. Understand its schema.
4. Understand its save/load lifecycle.

Never create a second cache simply because it is convenient for a new feature.

Do not change DataStore names or key formats without explicit migration
planning.

Validate current implementation rather than relying on historical docs.

---

# 12. VEHICLE ARCHITECTURE

The Tesla Cybertruck uses A-Chassis.

A-Chassis is an EXISTING dependency.

Do NOT replace A-Chassis merely because a cleaner vehicle architecture could
be designed from scratch.

Before modifying vehicle behavior, inspect:

- vehicle model
- DriveSeat
- A-Chassis Tune
- Initialize
- A-Chassis Interface
- Drive
- Plugins
- wheel hierarchy
- constraints
- seat/occupant logic
- network ownership
- spawned copy
- ServerStorage template

Trace behavior before changing it.

For example:

INPUT
  ↓
INPUT HANDLER
  ↓
A-CHASSIS CONTROL STATE
  ↓
A-CHASSIS
  ↓
VEHICLE

Find the actual chain.

Do not guess.

---

# 13. LEGACY A-CHASSIS RULE

A-Chassis may contain legacy/deprecated APIs.

Do NOT turn an unrelated feature repair into a full A-Chassis modernization.

If legacy code works and is unrelated to the current defect, leave it alone.

If a deprecated API directly causes the problem:

1. research its current replacement;
2. understand how A-Chassis uses it;
3. make the smallest compatible correction;
4. test vehicle behavior thoroughly.

A complete physics modernization is a separate project.

---

# 14. CROSS-PLATFORM INPUT

Desktop, mobile, and gamepad should ideally express the same logical actions.

Target concept:

Keyboard ──────┐
Touch ─────────┼──> Driving Action State ──> A-Chassis
Gamepad ───────┘

Avoid separate physics implementations for each platform.

Research Roblox's current input systems before changing input architecture,
including where relevant:

- Input Action System
- InputContext
- InputAction
- InputBinding
- ContextActionService
- UserInputService
- PreferredInput
- GuiButton.Activated

Use the cleanest system compatible with the existing game.

Do not rewrite working A-Chassis controls solely to use a newer API.

---

# 15. MOBILE DRIVING

Required mobile driving actions currently are:

- steering
- acceleration
- brake/reverse

Do NOT add a boost/nitro button, directional D-pad arrows, or any control beyond
the three above unless specifically requested.

Mobile controls must support MULTI-TOUCH.

Example:

LEFT THUMB:
analog steering joystick

RIGHT THUMB:
accelerator + brake pedals

The player must be able to steer while holding the accelerator.

Track individual touch InputObjects where necessary.

Do not let an unrelated second touch take ownership of steering.

### Current working implementation (as of 2026-08-27)

Owner: `StarterGui/MobileControls.client.luau`. Single ScreenGui, no duplicates.

Detection:
- Load-time guard: `if not UserInputService.TouchEnabled then return end`.
- `StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable`
  is set both server-side in `default.project.json` (`"Enum": 5`) and reasserted
  client-side. This suppresses Roblox's default DynamicThumbstick so it doesn't
  overlap the joystick.

Layout (all controls sit `BOTTOM_SAFE = 88 px` above the viewport bottom so they
clear the RaceHUD `END RACE / HOME / RESTART / START RACE` bar):

- Bottom-left: analog joystick. Circular base + draggable knob. X-axis only:
  far left = -1, center = 0, far right = +1. 12 % deadzone rescaled past the
  deadzone so full deflection still reaches ±1. Radius is
  `clamp(short_side * 0.16, 70, 130) px`.
- Bottom-right: Gas (accelerator) TextButton, then Brake TextButton to its left.
  Each is tall (`0.18 × viewport height`) for easy thumb reach.

Touch pipeline:
- Joystick tracks exactly ONE touch by `InputObject` identity: set on the base's
  `InputBegan` (Touch only), updated via `UserInputService.InputChanged` filtered
  by identity, cleared on `InputEnded` with matching identity.
- Pedals use `wireTouchButton` which listens on the TextButton child
  (`InputBegan`/`InputEnded` for both `Touch` and `MouseButton1`). Listening on
  the outer Frame does NOT work — the TextButton child intercepts touches.
- Multi-touch works because each button has its own connection and the joystick
  only claims its own tracked `InputObject`.

Visibility rule:
- ScreenGui.Enabled = true from init. Controls stay visible at all times on any
  touch device. Menu ScreenGuis (Shop/Garage/CarSelector/RaceHUD/etc.) may cover
  them visually but never hide them.
- `showControls()` / `hideControls()` only bind/unbind the chassis interface and
  start/stop the write loop; they no longer toggle ScreenGui.Enabled.

Vehicle input bridge (AC6, client-authoritative):
- MobileControls writes to four value objects under
  `PlayerGui["A-Chassis Interface"]` (the clone AC6's `Initialize` places there
  when the player sits — NOT the copy inside the vehicle model):
  - `MobileActive`   (BoolValue)   — set true while seated, false on exit.
  - `MobileThrottle` (NumberValue) — 0 or 1 from the gas pedal.
  - `MobileBrake`    (NumberValue) — 0 or 1 from the brake pedal.
  - `MobileSteer`    (NumberValue) — analog -1..1 from the joystick.
- `ensureMobileValues(ci)` creates any missing value objects with FindFirstChild
  so first-time seating doesn't error, and `hideControls()` reads back with
  FindFirstChild so a stale/orphaned interface doesn't crash.
- No RemoteEvent is used. MobileControls and AC6's Drive both run on the seated
  player's client, so direct value writes are correct.

AC6 Drive script patch (in `ServerStorage.Tesla Cybertruck` template so every
clone inherits it):
- `-- ACL_MOBILE_GUARD_V1` — `_acl_alive()` at the top of `Steering()`,
  `Engine()`, and `RPM()` self-destroys the ScreenGui when `car.Parent == nil`,
  killing the "Wheels is not a valid member of Model" spam when the vehicle is
  destroyed on race teleport / respawn.
- `-- ACL_MOBILE_INPUT_V1` — `_acl_applyMobile()` runs first inside the Stepped
  loop and, when `MobileActive` is true, overrides `_GThrot`/`_GBrake`/`_GSteerT`
  from `MobileThrottle`/`MobileBrake`/`MobileSteer`.
- `-- ACL_IGN_V1` — inside `_acl_applyMobile()`, forces `IsOn.Value = true`.
  AC6 requires a keyboard-only Ignition plugin keystroke to start the engine;
  without this the mobile throttle produces zero torque even when the value hits
  1. This is the one non-obvious step that makes mobile actually drive.

Server-side hygiene (`ServerScriptService/Services/GarageHandler.server.lua`):
- `destroyPlayerVehicles(userId)` also calls `clearStaleChassisGui(userId)`,
  which removes any leftover `A-Chassis Interface` ScreenGui from PlayerGui.
  Without this, the previous Drive LocalScript keeps ticking on a destroyed
  `car` reference after a map teleport.
- `VehicleTemplateFactory.EnsureTemplate` sets `Archivable = true` on the
  template and every descendant before `Clone()`. Without this, non-Archivable
  descendants are dropped from the clone and AC6 fails to find `Wheels`.

Nav ownership:
- SHOP / GARAGE / MAP nav column is owned by `StarterGui/GameHUD.client.lua`
  on both desktop and mobile. MobileControls does NOT render its own nav bar.
  On compact/touch layouts GameHUD anchors top-left so it doesn't compete with
  the bottom-left joystick.

---

# 16. DO NOT FAKE KEYBOARD INPUT BY DEFAULT

Do not use VirtualInputManager or simulated W/A/S/D as the default production
mobile architecture.

Virtual input APIs may be useful for testing, but mobile controls should
preferably connect to the logical state/function beneath the keyboard binding.

Example:

BAD:

Touch
→ pretend W key was pressed
→ keyboard handler
→ A-Chassis

PREFERRED:

Keyboard ──┐
           ├→ throttle state → A-Chassis
Touch ─────┘

If legacy architecture makes this impossible without a dangerous rewrite,
document the reason before using an exception.

---

# 17. MOBILE HUD VISIBILITY

Where appropriate, inspect `UserInputService.PreferredInput`.

A touch-capable device may currently be controlled by:

- touch
- keyboard
- gamepad

Current project decision (2026-08-27): mobile driving controls are shown
permanently on any device with `UserInputService.TouchEnabled == true`. The
buttons remain visible even when the player is on foot or a menu is open; menus
cover them visually but never hide them. This trades a small amount of screen
real estate for eliminating the entire class of "controls appear at the wrong
time" bugs and keeps state simple.

The write loop that pushes touch state into the vehicle only runs while seated,
so idle touches don't affect anything.

On vehicle exit:

- throttle neutral
- brake released
- steering centered
- temporary input bindings released
- driving HUD stays visible but inert

Re-entering must not create duplicate connections.

---

# 18. UI ENGINEERING

Do not build a separate fixed layout for every device.

Use responsive Roblox UI techniques.

Research and use where appropriate:

- UDim2
- Scale
- Offset
- AnchorPoint
- UISizeConstraint
- UIAspectRatioConstraint
- UITextSizeConstraint
- UIPadding
- UIListLayout
- UIGridLayout
- safe areas / screen insets
- ZIndex
- DisplayOrder

Do not interpret "responsive" as "replace every Offset with Scale."

Use Scale, constraints, layouts, and bounded offsets intentionally.

---

# 19. TOUCH BUTTONS

For ordinary GUI actions intended for multiple platforms, prefer appropriate
cross-platform button interaction.

Research `GuiButton.Activated`.

Do not assume mouse-specific handlers are sufficient for touch.

When a visible button does not respond, inspect:

- actual GuiButton instance
- Active
- InputSink
- Visible
- parent visibility
- AbsolutePosition
- AbsoluteSize
- ZIndex
- DisplayOrder
- overlapping GuiObjects
- transparent full-screen Frames
- modal interfaces
- event connections
- destroyed/recreated instances
- duplicate ScreenGuis

A visual problem may actually be an input interception problem.

---

# 20. MOBILE UI LAYOUT

Design around actual touch ergonomics.

Frequently used controls should be reachable by the player's thumbs.

For driving:

LEFT:
steering

RIGHT:
accelerator
brake/reverse

Avoid blocking important gameplay visibility.

Account for Roblox-reserved UI/touch regions.

Do not blindly copy desktop dimensions onto mobile.

---

# 21. GUI DUPLICATION

When a GUI appears correct briefly and then changes/reverts, investigate for:

- another LocalScript recreating it
- duplicate ScreenGui
- StarterGui → PlayerGui copy behavior
- ResetOnSpawn
- runtime UI builder
- old Studio-only instance
- Rojo stale instance
- multiple scripts changing the same properties
- respawn initialization
- delayed initialization
- device-specific code executing after initial render

Do not compensate by repeatedly forcing properties every frame.

Find the competing owner.

---

# 22. CLIENT/SERVER SECURITY

Never trust arbitrary client input.

For client → server communication:

- verify player
- verify ownership
- verify seat/driver state
- verify types
- clamp numeric values
- reject invalid numeric states
- rate-limit where appropriate
- prevent control of another player's vehicle

Do not expose remotes that allow arbitrary Instance manipulation.

---

# 23. NETWORKING

Do not automatically send reliable RemoteEvents every render frame.

For high-frequency transient state:

1. inspect the existing architecture;
2. determine whether networking is even required;
3. research Roblox's current networking recommendations;
4. consider update frequency;
5. consider network ownership;
6. consider UnreliableRemoteEvent where appropriate.

Do not redesign networking based on theory alone.

Measure and inspect first.

---

# 24. LUAU STANDARDS

For new or materially rewritten project-owned code:

- use --!strict where practical
- use game:GetService()
- use task.wait()
- use task.spawn()
- use task.delay()
- use current Roblox APIs
- prefer guard clauses
- use descriptive names
- avoid unnecessary global state
- avoid duplicate connections
- clean up temporary RBXScriptConnections
- avoid unnecessary per-frame loops
- validate remote input

Do not blindly apply strict typing to untouched legacy A-Chassis code if doing
so creates unnecessary churn.

---

# 25. DEBUGGING STANDARD

Never "fix" an error without understanding it.

For every significant runtime error determine:

ERROR
↓
SCRIPT
↓
LINE
↓
INSTANCE
↓
EXPECTED VALUE
↓
ACTUAL VALUE
↓
WHY IT BECAME INVALID
↓
ROOT CAUSE

Example:

"attempt to index nil with ChildAdded"

Do not merely add:

if object then

First determine WHY the expected object is nil.

Use defensive checks after understanding the cause.

---

# 26. USE STUDIO OUTPUT

When debugging runtime behavior, inspect Roblox Studio Output.

Record:

- exact error
- timestamp
- script
- line
- stack
- runtime path

Multiple errors may represent one cascading failure.

Fix the earliest/root error first.

---

# 27. DEVICE TESTING

When modifying UI/input, use Roblox Studio's Device Emulator.

Test representative:

- iPhone-size phone
- large phone
- standard Android
- tall/narrow Android
- wide/foldable Android
- tablet
- desktop

Use Actual Resolution where appropriate.

Test touch behavior, not merely viewport dimensions.

Where possible test multi-touch.

---

# 28. DESKTOP IS THE REGRESSION BASELINE

When desktop currently works and mobile does not:

PRESERVE DESKTOP.

Before changing shared vehicle/input code:

1. document current desktop behavior;
2. trace its input pathway;
3. make the change;
4. retest desktop.

A mobile fix that breaks desktop is not a fix.

---

# 29. SAFE CLEANUP

You are authorized to delete obsolete or conflicting implementation when
evidence demonstrates it is safe.

Examples:

- abandoned mobile scripts
- duplicate ScreenGuis
- obsolete remotes
- stale Studio instances
- failed experimental handlers
- dead AutoBuild code

Before deleting:

1. search references;
2. determine whether it runs;
3. determine its responsibility;
4. identify the replacement;
5. verify deletion does not remove unrelated behavior.

Do not preserve broken architecture merely because deleting code feels risky.

Do not perform speculative deletion either.

---

# 30. GIT SAFETY

Before significant changes:

git status

Understand:

- current branch
- modified files
- untracked files

Never destroy user work.

Do not use destructive commands such as:

git reset --hard
git clean -fd

unless the user explicitly requests them and understands the consequences.

After implementation:

- inspect git diff
- ensure changes match task scope
- report changed files

---

# 31. SMALL VERIFIED CHANGES

Prefer:

inspect
→ modify one responsibility
→ test
→ continue

over:

rewrite six interconnected systems
→ test at the end

AI-generated Roblox code becomes significantly less reliable when too many
unverified assumptions accumulate.

---

# 32. DO NOT CREATE DUPLICATE SYSTEMS

Before creating:

- RemoteEvent
- service
- controller
- ModuleScript
- ScreenGui
- vehicle handler
- datastore handler
- input handler

SEARCH FIRST.

If equivalent functionality already exists:

extend, repair, consolidate, or deliberately replace it.

Do not create:

MobileControls2
NewMobileControls
MobileControlsFixed
MobileControlsFinal

Solve ownership instead.

---

# 33. DEVELOPMENT WORKFLOW

For significant tasks follow:

## DISCOVER

- read this file
- inspect git
- inspect repository
- inspect Rojo mapping
- inspect Studio through MCP
- identify current owner

## RESEARCH

- search current Roblox docs
- search Luau/Rojo docs where relevant
- investigate known failure modes
- compare alternatives

## PLAN

State:

- root problem
- files involved
- runtime objects involved
- architecture being preserved
- architecture being changed
- items being removed

## IMPLEMENT

Make the smallest coherent implementation.

## VERIFY

- static checks
- sourcemap
- Studio sync
- playtest
- Output
- device emulation where relevant
- regression tests
- git diff

## REPORT

Explain:

- root cause
- research used
- changes
- deletions
- tests
- remaining problems

---

# 34. TASK-SPECIFIC DIRECTIVES

The user's individual request will normally be provided separately from this
file.

This file defines HOW you work.

The user's prompt defines WHAT you work on.

Example:

User prompt:

"Read CLAUDE.md first. Then repair the mobile driving controls and menus.
Do not add boost functionality."

You must apply this entire instruction file to that task.

---

# 35. DEFINITION OF DONE

Do not declare a task complete merely because code was generated.

A task is complete when, as applicable:

- code exists in the correct Rojo path
- Rojo maps it correctly
- Studio contains the expected instances
- runtime behavior works
- Studio Output has no new blocking errors
- desktop regressions were checked
- mobile regressions were checked
- obsolete conflicting code was handled
- Git diff matches intended scope

"Code written" is not synonymous with "working."

---

# FINAL PRINCIPLE

You are not being hired to generate Luau quickly.

You are being asked to maintain an existing Roblox software system safely.

When uncertain:

INSPECT FIRST.

When documentation is needed:

RESEARCH FIRST.

When multiple systems overlap:

TRACE OWNERSHIP FIRST.

When something breaks:

FIND THE ROOT CAUSE.

When changing working behavior:

TEST THE REGRESSION.

When finished:

VERIFY IT IN ROBLOX STUDIO.