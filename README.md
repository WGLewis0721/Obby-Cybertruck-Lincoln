# Obby but in a Cybertruck 🚗⚡

A Roblox obstacle course (obby) game set inside and around a Tesla Cybertruck, built with [Rojo](https://rojo.space/) for seamless Studio sync.

---

## 📁 Project Folder Structure

```
Obby-Cybertruck-Lincoln/
├── _backup/                          # Raw/disabled files — not synced by Rojo
│
├── src/                              # All synced game source files
│   ├── ReplicatedStorage/
│   │   ├── Events/                   # RemoteEvents (.rbxm)
│   │   └── Module/                   # Shared ModuleScripts: ShopItems, MapData,
│   │                                 # PlayerData, InputProcessor, Logger, EventBus...
│   │
│   ├── ServerScriptService/
│   │   ├── Documentation/            # Prose notes (.md) — NOT synced as scripts
│   │   ├── Services/                 # PaintShopHandler, PlayerDataInterface,
│   │   │                             # VehiclePhysicsHandler, GarageHandler, etc.
│   │   └── Setup/                    # One-time map/RemoteEvent generation scripts
│   │
│   ├── StarterGui/                   # HUD, shop UI, mobile controls, results screen
│   │
│   └── StarterPlayer/
│       ├── StarterCharacterScripts/
│       └── StarterPlayerScripts/
│
├── default.project.json              # Rojo project definition
├── .github/
│   └── copilot-instructions.md       # GitHub Copilot coding guidelines
└── README.md
```

> Note: files under `ServerScriptService/Documentation/` are intentionally `.md` — earlier
> revisions gave some of these a `.luau`/`.server.luau` extension, which made Rojo sync them
> as real (broken) script instances. Keep documentation in this folder as `.md` only.

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