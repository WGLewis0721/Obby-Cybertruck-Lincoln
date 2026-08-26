--!strict
--[[
================================================================================
  PROMPT: A-Chassis Mobile Controls UI — Obby-Cybertruck-Lincoln
================================================================================

PROJECT CONTEXT
---------------
Game:       Obby-Cybertruck-Lincoln (Driving Simulator — NOT a racing game)
Engine:     Roblox Studio | Language: Luau --!strict
Vehicles:   Tesla Cybertruck, Model 3, Roadster, Model Y — physics via A-Chassis
            Vehicle in Workspace is always named Vehicle_[player.UserId]
            A-Chassis Tune ModuleScript lives inside the vehicle model
Physics:    Server-authoritative. Server owns vehicle state.
            Client ONLY reads input and fires RemoteEvents. Never mutates physics directly.
Platform:   Mobile (iPhone, iPad, Samsung Galaxy — various screen sizes and densities)
            Must be fully functional without keyboard or mouse.

================================================================================
  YOUR TASK
================================================================================

Write ONE LocalScript named MobileControls.client.lua
Location:   StarterGui/MobileControls (ScreenGui + LocalScript together)
Rojo path:  src/StarterGui/MobileControls.client.lua

This script creates the entire mobile driving UI and handles all touch input.
It connects to the A-Chassis vehicle input pipeline via the VehicleInput RemoteEvent.

Do NOT write any server-side code.
Do NOT write any vehicle physics code.
Do NOT touch PlayerData, DataStore, or PaintShopHandler.
This script is UI + input capture ONLY.

================================================================================
  LUAU CODE STANDARDS (mandatory — no exceptions)
================================================================================

Line 1:    --!strict
Header:    -- SCRIPT: MobileControls | LOCATION: StarterGui/MobileControls | SIDE: Client

Services — acquire ALL via GetService(), never globals:
  local Players         = game:GetService("Players")
  local UserInputService = game:GetService("UserInputService")
  local RunService      = game:GetService("RunService")
  local ReplicatedStorage = game:GetService("ReplicatedStorage")

APIs — NEVER use deprecated versions:
  task.wait()    not wait()
  task.spawn()   not spawn()
  task.delay()   not delay()

Naming:
  PascalCase    → RemoteEvents, GUI instances, exported tables
  camelCase     → local variables, functions, parameters
  LOUD_SNAKE    → module-level constants (button sizes, colors, etc.)

Type annotations — required on all non-obvious variables and function signatures.
Guard clauses — use early returns for nil checks. Never deeply nested if-blocks.

================================================================================
  REMOTEEVENTS — EXACT ACCESS PATTERNS
================================================================================

-- VehicleInput fires from this script to the server every Heartbeat:
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local vehicleInput = remotes:WaitForChild("VehicleInput", 10)
-- Payload fired:  vehicleInput:FireServer({ throttle = n, steer = n, brake = n })
-- throttle: -1.0 to 1.0  (negative = reverse)
-- steer:    -1.0 to 1.0  (negative = left)
-- brake:     0.0 to 1.0

-- Horn fires from this script (no payload):
local horn = ReplicatedStorage:WaitForChild("Horn", 10)

-- OpenPaintShop fires when paint button is pressed:
local openPaintShop = ReplicatedStorage:WaitForChild("OpenPaintShop", 10)

-- OpenGarage fires when garage button is pressed:
local events = ReplicatedStorage:WaitForChild("Events", 10)
local openGarage = events:WaitForChild("OpenGarage", 10)

-- ApplyBoost fires locally when boost button is pressed (boost is client-visible 
-- but server-authoritative — the boost button should also fire a server event 
-- if one is added later; for now wire it to the existing BoostHandler pattern):
-- BoostHandler.client.lua already handles ApplyBoost S→C
-- This script should NOT re-implement boost — just provide the UI button
-- that calls the same local boost logic BoostHandler uses.

================================================================================
  A-CHASSIS INTEGRATION — HOW MOBILE INPUT MAPS TO A-CHASSIS
================================================================================

A-Chassis reads throttle, steer, and brake values from the VehicleSeat:
  VehicleSeat.ThrottleFloat  (-1 to 1)
  VehicleSeat.SteerFloat     (-1 to 1)
  VehicleSeat.Brake           (0 to 1, via custom property or AngularVelocity)

The mobile UI does NOT write to VehicleSeat directly (that would be client-side
physics mutation — a Critical Rule violation).

Instead, this LocalScript fires VehicleInput RemoteEvent to the server every
RunService.Heartbeat with the current { throttle, steer, brake } values derived
from which buttons are currently held down. The server's VehicleManager or
A-Chassis server script applies those values to the VehicleSeat and constraints.

INPUT STATE MODEL (managed by this script):
  local inputState = {
      throttle = 0,   -- set to 1.0 when Gas held, -1.0 when Reverse held
      steer    = 0,   -- set to -1.0 when Left held, 1.0 when Right held
      brake    = 0,   -- set to 1.0 when Brake held
  }

  -- Every Heartbeat:
  RunService.Heartbeat:Connect(function()
      vehicleInput:FireServer(inputState)
  end)

  -- Buttons set/clear inputState values on TouchStart/TouchEnd

================================================================================
  UI LAYOUT — EXACT STRUCTURE REQUIRED
================================================================================

ScreenGui (ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5)
  ├── LeftControlsFrame   (AnchorPoint 0,1 | Position {0, 16, 1, -16} Scale-based)
  │     ├── SteerLeftButton     (large circle, left arrow icon)
  │     ├── SteerRightButton    (large circle, right arrow icon)
  │     ├── ReverseButton       (medium circle, reverse/down arrow icon)
  │     └── ResetButton         (small square-rounded, U-turn / reset icon)
  │
  └── RightControlsFrame  (AnchorPoint 1,1 | Position {1, -16, 1, -16} Scale-based)
        ├── GasPedal            (large tall rounded rect, green tint, "GAS" label)
        ├── BrakePedal          (large tall rounded rect, red tint, "BRAKE" label)
        ├── BoostButton         (medium circle, flame/lightning icon, orange tint)
        └── ActionButtonsRow    (horizontal row above pedals)
              ├── HornButton    (small circle, horn icon)
              ├── PaintButton   (small circle, paint/palette icon)
              ├── GarageButton  (small circle, car/garage icon)
              └── CameraButton  (small circle, camera icon)

================================================================================
  SIZING — SCALE-BASED FOR CROSS-DEVICE COMPATIBILITY
================================================================================

All sizes and positions MUST use UDim2 Scale values, not Offset, except for
fixed-pixel gaps and padding (use Offset only for those small constants).

Target device baseline: iPhone 14 Pro (393×852 logical points)
The UI must adapt correctly to:
  - iPhone SE (375×667) — smallest common iOS
  - iPhone 14 Pro Max (430×932)
  - iPad Air (820×1180) — scale up gracefully, do not stretch
  - Samsung Galaxy S23 (360×780)
  - Samsung Galaxy Tab S8 (800×1280) — tablet, scale up

Recommended scale constants (define as LOUD_SNAKE_CASE at top of script):
  LARGE_BUTTON_SIZE  = UDim2.new(0.12, 0, 0.10, 0)   -- gas/brake pedals
  MEDIUM_BUTTON_SIZE = UDim2.new(0.10, 0, 0.09, 0)   -- steer L/R, boost
  SMALL_BUTTON_SIZE  = UDim2.new(0.08, 0, 0.07, 0)   -- action row buttons
  CORNER_RADIUS      = UDim.new(0.5, 0)               -- full circle
  PEDAL_CORNER       = UDim.new(0.3, 0)               -- rounded rect

Frame positioning must use AnchorPoint to pin to screen corners so the layout
is stable on all aspect ratios:
  LeftControlsFrame:  AnchorPoint(0, 1) — bottom-left
  RightControlsFrame: AnchorPoint(1, 1) — bottom-right

================================================================================
  VISUAL DESIGN
================================================================================

Background color (all buttons):  Color3.fromRGB(20, 20, 20) at 0.45 transparency
Gas pedal tint:                   Color3.fromRGB(30, 80, 30)  at 0.5 transparency
Brake pedal tint:                 Color3.fromRGB(80, 20, 20)  at 0.5 transparency
Boost button tint:                Color3.fromRGB(100, 50, 0)  at 0.4 transparency
Icon color (ImageLabel):          Color3.fromRGB(255, 255, 255)
Stroke color (UIStroke):          Color3.fromRGB(255, 255, 255) at 0.2 transparency
Stroke thickness:                 1.5

Button press feedback:
  On TouchStart → BackgroundTransparency set to 0.2 (darker, pressed feeling)
  On TouchEnd   → BackgroundTransparency restored to original value
  Size pulse is optional but welcome (TweenService scale up 1.05× on press)

Icons: Use ImageLabel children inside each button frame. Use TextLabels as fallback
if no rbxassetid is available (e.g. "◀", "▶", "⛽", "🅱", "🔊", "🎨", "🏠", "📷").
Define icon asset IDs as constants at the top of the script so they can be
swapped easily:
  local ICON_STEER_LEFT  = "rbxassetid://0"  -- replace with real asset
  local ICON_STEER_RIGHT = "rbxassetid://0"
  local ICON_GAS         = "rbxassetid://0"
  etc.

================================================================================
  TOUCH INPUT — EXACT IMPLEMENTATION PATTERN
================================================================================

Use UserInputService.TouchStarted and TouchEnded — NOT InputBegan/InputEnded.
Reason: InputBegan/InputEnded on mobile do not reliably distinguish simultaneous
multi-touch (player can hold gas AND steer at the same time).

Each button frame must independently detect its own touch using:
  button.InputBegan:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.Touch then
          -- activate this button's state
      end
  end)
  button.InputEnded:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.Touch then
          -- deactivate this button's state
      end
  end)

This allows simultaneous gas + steer (the most important mobile UX requirement).

Guard clauses required:
  - Check UserInputService.TouchEnabled before building UI — if false (desktop),
    skip UI creation entirely so the script is safe on all platforms.
  - Check that VehicleInput RemoteEvent exists before firing — if missing after
    10 second timeout, warn and disable input loop gracefully.

================================================================================
  VISIBILITY RULES
================================================================================

The mobile controls UI should only be visible when the player is driving.
- On load: ScreenGui.Enabled = false
- When VehicleSpawned RemoteEvent fires to this client: ScreenGui.Enabled = true
- When player leaves vehicle (VehicleSeat.Occupant becomes nil, detected via
  GetPropertyChangedSignal on the VehicleSeat): ScreenGui.Enabled = false
- Reset inputState to all zeros when UI is hidden

Access VehicleSpawned:
  local vehicleSpawned = remotes:WaitForChild("VehicleSpawned", 10)
  vehicleSpawned.OnClientEvent:Connect(function(vehicleName, spawnPosition)
      -- show controls
      screenGui.Enabled = true
  end)

================================================================================
  WHAT NOT TO DO (Critical Rule violations to avoid)
================================================================================

❌ Do NOT write to VehicleSeat.ThrottleFloat or SteerFloat directly from client
❌ Do NOT use game.Players or game.Workspace globals
❌ Do NOT use wait(), spawn(), delay()
❌ Do NOT use BodyVelocity or BodyGyro
❌ Do NOT create a ProcessReceipt handler
❌ Do NOT access RemoteEvents without WaitForChild + timeout
❌ Do NOT use Offset-only sizing for main button dimensions
❌ Do NOT disable ResetOnSpawn on the ScreenGui if you want it to persist across
   respawns — ResetOnSpawn = false is required here so UI survives character resets

================================================================================
  DELIVERABLE
================================================================================

One complete LocalScript: MobileControls.client.lua
Saved to: src/StarterGui/MobileControls.client.lua (Rojo syncs to StarterGui)

The script must:
  [x] Build the entire ScreenGui and all button instances programmatically in code
      (no separate Roblox Studio UI building required — fully code-driven)
  [x] Handle multi-touch gas + steer simultaneously
  [x] Fire VehicleInput RemoteEvent every Heartbeat while driving
  [x] Fire Horn, OpenPaintShop, OpenGarage on the correct button taps
  [x] Show/hide based on VehicleSpawned and VehicleSeat occupancy
  [x] Skip UI creation entirely on non-touch devices
  [x] Use only Scale-based sizing for cross-device compatibility
  [x] Follow all Luau code standards: --!strict, header block, GetService(), 
      task.* library, PascalCase events, camelCase locals, guard clauses

================================================================================
]]