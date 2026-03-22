const fs = require("fs");
const path = require("path");

const base = path.join(__dirname, "src", "StarterPlayer", "StarterPlayerScripts", "AutoBuild");

// Folder structure
const folders = [
  "client",
  "shared",
  "../../docs"
];

// Files to create
const files = {
  "client/UIBuilder.lua": `-- Builds HUD UI
-- TODO: create buttons, joystick, nitro bar
`,

  "client/InputHandler.lua": `-- Handles button input
-- TODO: update ControlState
`,

  "client/SteeringController.lua": `-- Handles joystick
-- TODO: set ControlState.Steering
`,

  "client/VehicleController.lua": `-- A-Chassis input simulation
-- TODO: simulate W, A, S, D, Shift
`,

  "client/NitroSystem.lua": `-- Nitro system
-- TODO: drain + regen nitro
`,

  "client/CooldownSystem.lua": `-- Cooldown system
-- TODO: prevent boost spam
`,

  "shared/ControlState.lua": `local ControlState = {
	Accelerating = false,
	Braking = false,
	Boosting = false,
	Steering = 0,
	Nitro = 100,
	MaxNitro = 100,
	IsCoolingDown = false
}
return ControlState
`,

  "../../docs/system-design.md": `# AutoBuild System

Input → ControlState → VehicleController

NitroSystem + CooldownSystem control boost
`,

  "../../docs/copilot-instructions.md": `You are working in a Roblox Luau system.

Do not create new systems.
Only expand TODO blocks.
Maintain ControlState structure.
Use A-Chassis input (W, A, S, D, Shift).
`
};

// Create folders
folders.forEach(folder => {
  const fullPath = path.join(base, folder);
  fs.mkdirSync(fullPath, { recursive: true });
});

// Create files
Object.entries(files).forEach(([file, content]) => {
  const filePath = path.join(base, file);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });

  if (!fs.existsSync(filePath)) {
    fs.writeFileSync(filePath, content);
    console.log("Created:", filePath);
  } else {
    console.log("Skipped (exists):", filePath);
  }
});

console.log("✅ AutoBuild system created");