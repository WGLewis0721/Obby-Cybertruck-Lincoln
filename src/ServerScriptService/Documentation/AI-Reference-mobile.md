-- You are building a mobile driving UI for a Roblox game.
-- The UI must match a modern racing game layout with left-side steering
-- and right-side driving controls (gas, brake, boost, tools).

-- REQUIREMENTS:

-- 1. Create a ScreenGui inside StarterGui
-- 2. UI must be optimized for mobile (TouchEnabled)

-- LEFT SIDE (Movement Controls):
-- - Bottom-left corner anchored
-- - Two large circular buttons:
--     - Left arrow (steer left)
--     - Right arrow (steer right)
-- - Above them:
--     - A circular "reset/turn" button (U-turn icon)
--     - A smaller square/rounded button (menu or exit)

-- RIGHT SIDE (Driving Controls):
-- - Bottom-right corner anchored
-- - Two vertical pedals:
--     - Gas pedal (right)
--     - Brake pedal (left)
-- - Above pedals:
--     - Circular boost button (flame icon, highlighted)
-- - Above boost:
--     - Row of smaller circular action buttons:
--         - Camera
--         - Paint/customization
--         - Horn
--         - Settings

-- DESIGN STYLE:
-- - Semi-transparent dark gray circles
-- - White icons
-- - Rounded UI (UICorner)
-- - Subtle stroke/border (UIStroke)
-- - Consistent padding and spacing
-- - Mobile-friendly sizing using Scale (not Offset where possible)

-- FUNCTIONALITY:
-- - Buttons should fire RemoteEvents or bind to vehicle controls:
--     - Left/Right arrows → steering input
--     - Gas pedal → throttle
--     - Brake pedal → reverse/brake
--     - Boost → temporary speed increase
-- - Use UserInputService for touch events (InputBegan/InputEnded)

-- STRUCTURE:
-- ScreenGui
--   ├── LeftControlsFrame
--   │     ├── SteerLeftButton
--   │     ├── SteerRightButton
--   │     ├── TurnButton
--   │     └── MenuButton
--   ├── RightControlsFrame
--   │     ├── GasPedal
--   │     ├── BrakePedal
--   │     ├── BoostButton
--   │     └── ActionButtonsFrame
--   │           ├── CameraButton
--   │           ├── PaintButton
--   │           ├── HornButton
--   │           └── SettingsButton

-- Make sure UI scales properly across different screen sizes.
-- Use AnchorPoint and Position with Scale values for responsiveness.

-- Add basic placeholder icons using ImageLabels (rbxassetid)
-- and ensure buttons visually respond when pressed (slight transparency or size change).