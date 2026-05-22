# Simple Tower Defense

An endless, maze-building tower defense game made in **Godot 4.6** (GL Compatibility renderer). Build a labyrinth of walls to route enemies past your towers, mix six tower types and five traps, and survive as many waves as you can. Everything is drawn with vector primitives — no art assets, just code.

![Gameplay](screenshots/gameplay.jpg)

## Features

- **Maze building** — place walls to force a path; a wave won't start unless enemies can still reach the exit.
- **6 towers & 5 traps**, each upgradeable with distinct scaling.
- **Endless waves** with rotating *deploy styles* so no two waves feel the same.
- **Boss waves** at 5, 15, 25, … with a mix of beetles, spiders, and tanky scorpions trickled in.
- **Map editor** — paint your own walls and save them, or play the built-in Open / Maze / Fun / Spiral maps.
- **Difficulty modifiers** — Hard mode, unlimited lives/money, free walls, round-timer gold bonus, and more, all persisted between sessions.
- **Undo**, drag-to-place, bulk upgrades, lifetime stats, and high-speed graphics reduction for smooth fast-forwarding.

![Options & settings](screenshots/options.jpg)

## Towers

| Tower | Role | Notes |
|-------|------|-------|
| **Bullet** | Cheap single-target | Fire rate climbs with level (caps at 4.0/s) |
| **Cannon** | Splash | Lobs a shell to a spot, AOE on impact |
| **Laser** | Single-target beam | Continuous damage, always one target |
| **Ice** | AOE crowd control | Frost field slows everything in range (no damage) |
| **Sniper** | High single-target | Long range, fire rate doubles every 30 levels |
| **Missile** | Homing splash | Tracks and re-acquires targets; AOE on hit |

## Traps

| Trap | Effect |
|------|--------|
| **Tar** | Slows enemies on contact (5% → 90% by level 10) |
| **Spike** | Contact damage |
| **Poison** | Damage over time **and** makes enemies take extra damage from all sources |
| **Fire** | Heavier damage over time |
| **Volcano** | Erupts periodically, AOE damage to everything in its area |

## Enemies & waves

- **Grunt** — balanced. **Runner** — fast, resists poison. **Tank** — slow, tough, resists fire.
- Each wave rotates a deploy style: **Steady**, **Swarm** (fast packs), **Heavy** (tanks), **Squads** (same-type bursts). The next-wave label tells you which.
- **Boss waves** (5, 15, 25, …) layer growing numbers of bosses onto the normal wave — beetles/spiders plus slower, tankier **scorpions** that grow each boss level.

## Controls

| Input | Action |
|-------|--------|
| Left-click | Place / upgrade a piece |
| Right-click | Sell a piece |
| Alt + drag | Place (or remove walls) in a straight line |
| Alt + left-click | Upgrade a turret 10 levels at once |
| Mouse wheel | Zoom; middle-drag to pan |
| **Space** | Pause |
| **Enter** | Send next wave |
| **+ / -** | Game speed (¼× to 100×) |
| **Z** | Undo |
| **Esc** | Open/close Options |

## Run from source

1. Install [Godot 4.6](https://godotengine.org/download) (uses the GL Compatibility renderer).
2. Open the project (`project.godot`) in the Godot editor and press **Play**, or run headless:
   ```sh
   godot4 --path . 
   ```

## Build / export

Export presets are included for **Windows, Linux, macOS, and Web**. From the editor use *Project → Export*, or from the CLI:

```sh
godot4 --headless --export-release "Windows Desktop" build/SimpleTowerDefense.exe
godot4 --headless --export-release "Linux"           build/SimpleTowerDefense
godot4 --headless --export-release "Web"             build/web/index.html
```

## Project layout

```
project.godot          # Godot project config (autoloads: Events, GameState)
scenes/                # Main scene
scripts/
  main.gd              # Root: wires level, wave manager, HUD
  level.gd             # Grid, pathfinding (BFS), placement, input
  wave_manager.gd      # Wave/boss spawning and deploy styles
  hud.gd               # Bar, menus, popups, help text
  tower.gd / trap.gd   # Placeable combat pieces
  enemy.gd / bullet.gd # Enemies and projectiles
  piece_data.gd        # Static stat tables and scaling formulas
  game_state.gd        # Persistent run state, settings, stats
```

## License

_TODO: add a license._
