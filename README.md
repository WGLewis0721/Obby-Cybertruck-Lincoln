# Obby but in a Cybertruck 🚗⚡

A Roblox obstacle course (obby) game set inside and around a Tesla Cybertruck, built with [Rojo](https://rojo.space/) for seamless Studio sync.

---

## 📁 Project Folder Structure

```
Obby-Cybertruck-Lincoln/
├── _backup/                          # Raw Roblox model files (.rbxm) — not synced by Rojo
│   ├── tesla_cybertruck.rbxm
│   └── teslacybertruck.rbxm
│
├── src/                              # All synced game source files
│   ├── ReplicatedStorage/
│   │   └── Module/
│   │       └── ShopItems.lua         # ModuleScript: list of paint-job shop items
│   │
│   ├── ServerScriptService/
│   │   ├── PaintShopHandler.server.lua  # Handles paint-job purchases server-side
│   │   └── test.server.lua              # Quick Rojo connectivity test
│   │
│   ├── StarterGui/
│   │   ├── LoadingScreen.client.lua  # Loading screen (Play / Settings / Shop)
│   │   ├── PaintShopButton.client.lua # In-game paint shop toggle button
│   │   └── ShopGui_d/
│   │       └── LoadShop.client.lua   # Populates the shop scroll frame from ShopItems
│   │
│   └── StarterPlayer/
│       ├── StarterCharacterScripts/  # (reserved for character scripts)
│       └── StarterPlayerScripts/
│           └── Client/
│               ├── ShopButtonHandler.client.lua  # Wires up the shop open button
│               └── ShopMenuScript.client.lua     # Controls shop menu visibility
│
├── default.project.json              # Rojo project definition
├── .github/
│   └── copilot-instructions.md       # GitHub Copilot coding guidelines
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites
- [Rojo](https://rojo.space/) CLI installed  
- Roblox Studio open with the Rojo plugin installed

### Running locally
```bash
# Start the Rojo dev server
rojo serve default.project.json
```
Then click **Connect** in the Rojo Studio plugin to sync all source files into your place.

---

## 🎮 Features
- **Loading Screen** — Cyberpunk-styled title screen with Play, Settings, and Shop buttons.
- **Paint Shop** — Purchase cosmetic Cybertruck paint jobs (Green, Blue, Gold) via Roblox developer products.
- **Obby Gameplay** — Classic obstacle course built around the Cybertruck model.

---

## 🤝 Contributing
See [`.github/copilot-instructions.md`](.github/copilot-instructions.md) for coding conventions used in this project.