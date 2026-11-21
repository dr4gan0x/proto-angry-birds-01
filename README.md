# Angry Birds 2D Prototype (Roblox Studio)

A 2D side-view Angry Birds prototype built for Roblox Studio in strict Luau. It runs a client-side rigid-body simulation constrained to the `Z = 0` plane with a low-FOV side camera, slingshot drag-and-release launching, parabolic trajectory preview, three destructible block materials, and three progressive levels.

## Features

- **2D Planar Physics Lock:** Dynamic parts (birds, blocks, and targets) are locked to `Z = 0` with Z-axis-only rotation using `PlaneConstraint`, `AlignOrientation`, and per-frame Heartbeat drift correction.
- **Slingshot Aiming & Preview:** Drag the active bird back with mouse or touch, stretch the elastic bands, and preview the launch arc with physics-matched parabolic dots. Release inside the deadzone or press Right-Click / `Esc` to cancel.
- **Destructible Materials:** Three distinct material tiers (`Glass`, `Wood`, `Stone`) with custom density, friction, elasticity, health, damaged tint states, debris bursts, and score values.
- **3 Progressive Levels:** Sequential unlocking (`Level 1 -> Level 2 -> Level 3`) with session best-score tracking and unused bird bonuses (`+10,000` per remaining bird).
- **Turn & Soft-Lock Safety:** Spawn grace period prevents accidental damage while towers settle; flight and settle timeouts guarantee turns never hang on jittering debris.
- **No Avatar Interference:** Disables character auto-loading (`CharacterAutoLoads = false`) and anchors `ReplicationFocus` for smooth playback with `StreamingEnabled`.

## Project Structure

```text
proto-angry-birds-01/
├── default.project.json                          # Rojo project mapping
├── src/
│   ├── shared/AngryBirds/                        # ReplicatedStorage > AngryBirds
│   │   ├── Config.luau                           # Physics, slingshot, camera, material & score constants
│   │   ├── LevelData.luau                        # Data-driven definitions & overlap validator for Levels 1-3
│   │   ├── ProgressionState.luau                 # Session unlock progression & best scores
│   │   └── TrajectoryMath.luau                   # Pull clamping, launch velocity, arc sampling & framing math
│   ├── server/                                   # ServerScriptService
│   │   └── GameSetup.server.luau                 # Environment lighting, StreamingFocus & CollisionGroups
│   ├── client/                                   # StarterPlayer > StarterPlayerScripts
│   │   ├── AngryBirdsClient.client.luau          # Main client game state machine
│   │   └── AngryBirds/
│   │       ├── CameraController.luau             # Scriptable side-view camera with viewport aspect adaptation
│   │       ├── LevelBuilder.luau                 # Scenery, slingshot, blocks, targets & bird queue builder
│   │       ├── Physics2D.luau                    # 2D constraints, impact damage, OOB checks & settle detection
│   │       ├── SlingshotController.luau          # Raycast aiming, band visuals, trajectory dots & launch
│   │       └── UIController.luau                 # Main menu, level selector, gameplay HUD & result modals
│   └── tests/
│       └── AngryBirdsTests.luau                  # Studio unit, physics, UI, end-to-end & regression checks
├── LICENSE
└── README.md
```

## Getting Started

### Option A: With Rojo (Recommended)

1. Install [Rojo](https://rojo.space/) (7.x) and the Rojo plugin for Roblox Studio.
2. Start a live sync server from the repository root:

   ```bash
   rojo serve
   ```

   Or build a standalone place file directly:

   ```bash
   rojo build -o proto-angry-birds-01.rbxl
   ```

3. Open the place (or connect via the Rojo Studio plugin to a fresh Baseplate place) and press **F5** (Play).

### Option B: Manual Setup in Roblox Studio

1. Open Roblox Studio and create a new **Baseplate** place.
2. Create a **Folder** named `AngryBirds` inside **ReplicatedStorage** and add **ModuleScripts** matching every file in `src/shared/AngryBirds/`.
3. Add a **Script** named `GameSetup` inside **ServerScriptService** with the contents of `src/server/GameSetup.server.luau`.
4. Inside **StarterPlayer > StarterPlayerScripts**:
   - Add a **LocalScript** named `AngryBirdsClient` with the contents of `src/client/AngryBirdsClient.client.luau`.
   - Create a **Folder** named `AngryBirds` and add **ModuleScripts** matching every file in `src/client/AngryBirds/`.
5. Press **F5** (Play) — the Main Menu opens automatically.

## Controls

| Action | Input |
|---|---|
| Aim & Pull | Left-click (or touch) near the slingshot and drag back |
| Launch | Release Left-click (or touch) past the minimum pull deadzone |
| Cancel Shot | Right-click, press `Esc`, or release inside the deadzone |

## Levels & Materials

### Levels

| # | Name | Birds | Targets | Materials |
|---|---|---|---|---|
| 1 | Wooden Tower | 3 | 2 | Wood |
| 2 | Glass & Wood Outpost | 3 | 3 | Glass, Wood |
| 3 | Stone Castle | 4 | 4 | Glass, Wood, Stone |

### Destructible Specs (`Config.luau`)

| Type | HP | Density | Score |
|---|---|---|---|
| Glass | 18 | 0.55 | 500 |
| Wood | 42 | 0.90 | 750 |
| Stone | 90 | 2.00 | 1,000 |
| Pig (Target) | 26 | 0.80 | 5,000 |

## Tuning

All gameplay parameters live in `src/shared/AngryBirds/Config.luau`:

- **Slingshot & Trajectory:** `SLINGSHOT_ANCHOR`, `PULL_MIN`, `PULL_MAX`, `GRAB_RADIUS`, `LAUNCH_SPEED_PER_STUD`, `DOT_COUNT`, `DOT_DT`
- **Impact & Settling:** `SPAWN_GRACE_SEC`, `MIN_IMPACT_SPEED`, `DAMAGE_PER_SPEED`, `PAIR_COOLDOWN_SEC`, `SETTLE_SPEED_THRESHOLD`, `SETTLE_HOLD_SEC`, `MAX_FLIGHT_SEC`, `MAX_SETTLE_SEC`
- **Camera:** `CAMERA.fov`, `CAMERA.center`, `CAMERA.width`, `CAMERA.height`

New levels can be appended to `LevelData.Levels` in `src/shared/AngryBirds/LevelData.luau` and checked for ground penetration or bounding-box overlaps via `LevelData.validateLevel`.

## Running Tests

`src/tests/AngryBirdsTests.luau` contains unit, physics, slingshot, UI, end-to-end, and regression tests designed to run inside a Roblox Studio Play Solo session:

1. Place `AngryBirdsTests.luau` as a `ModuleScript` in `ReplicatedStorage` (named `AngryBirdsTests`).
2. Start **Play Solo** (**F5**) and switch the Command Bar to **Client**.
3. Run:

   ```lua
   require(game:GetService("ReplicatedStorage").AngryBirdsTests).runAll()
   ```

## License

[MIT](LICENSE)
