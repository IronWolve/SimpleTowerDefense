# Change Checklist

A living regression/parity checklist for **Simple Tower Defense 2D**. Sweep the
relevant sections when a change lands; mark items as `[x]` once verified, and
note `[~]` for "intentionally diverges from 3D" with a one-line reason.

The same file lives in `tower_defense_3d/CHECKLIST.md`. When a change touches
gameplay logic in either project, also update the matching item in the other
file (port, diverge, or N/A).

---

## Gameplay numbers — per piece

### Towers (`piece_data.gd::TYPES`)
- [ ] Base damage matches intent for every tower type
- [ ] Base fire rate matches intent
- [ ] Base range matches intent
- [ ] Base AOE radius matches intent (cannon / missile)
- [ ] Base cost matches intent
- [ ] `color` and `bullet_color` (bullet_color now unused for projectiles — kept for stats panels)

### Tower scaling (`piece_data.gd::tower_stats`)
- [ ] Damage step + exponent (`dmg_step`, `dmg_exp`) per type (sniper differs)
- [ ] Damage multipliers (universal 1.10×1.05; cannon extra 1.05×1.05)
- [ ] Range growth rule: `+15 * (n / 2)` (every 2 levels)
- [ ] Fire-rate rule per type: bullet (linear, cap 4.0/s), sniper/missile (×2 per 30 levels), ice/laser/cannon (linear +8%/level)
- [ ] Slow growth: linear from base to `SLOW_CAP` at `SLOW_MAX_LEVEL`

### Caps (`piece_data.gd`)
- [ ] `RANGE_CAP` per type: tower 160, cannon 180, ice 160, laser 200, missile 220, sniper 300
- [ ] `AOE_CAP` per type: cannon 120, missile 160, volcano_trap 120
- [ ] `SLOW_CAP = 0.80`, `SLOW_BOOST_CAP = 0.95`, `SLOW_MAX_LEVEL = 40`
- [ ] `SUPPORT_PCT_PER_LEVEL = 0.005` (Gold Mine / Amplifier)

### Traps (`piece_data.gd::trap_stats` + `trap.gd`)
- [ ] Tar: pure slow, no damage, shares slow curve with Ice
- [ ] Spike: contact DPS + %-of-max-HP, cap 12%/s, halved vs bosses
- [ ] Poison: DoT seconds + vuln% per level
- [ ] Fire: DoT seconds per level
- [ ] Volcano: `ERUPT_PERIOD = 0.8s`, AOE damage, Amplifier grows damage + reach

### Enemies (`enemy.gd`, `wave_manager.gd::ENEMY_TYPES`)
- [ ] HP, base speed, gold reward, radius per type
- [ ] Resists: Runner → poison; Tank → fire
- [ ] `leak_damage` default = 1
- [ ] `BOSS_LEAK = {beetle: 5, spider: 5, turtle: 8}` applied in `_spawn_boss`

### Wave manager (`wave_manager.gd`)
- [ ] Deploy styles: Steady / Swarm / Heavy / Squads weights
- [ ] Boss-wave cadence (5, 15, 25, …) and boss counts (1, 2, 3, 5, 7, …)
- [ ] Turtle cadence (+1 each boss wave)
- [ ] HP / reward growth curves per wave
- [ ] Round-timer bonus: +2% per wave, non-boss waves only

### Economy (`game_state.gd`)
- [ ] Starting gold (normal vs hard, hard = 40% less)
- [ ] Starting lives, bonus-life-per-wave rule
- [ ] Kill gold formula + Gold Mine + Amplifier stacking
- [ ] Sell refund rule

---

## Controls

### Mouse (`level.gd::_unhandled_input`)
- [ ] Left-click: place / select / upgrade
- [ ] Right-click: sell / close popup
- [ ] Middle-drag: pan when zoomed in
- [ ] Wheel: zoom to cursor (`_setup_zoom`, `MIN_ZOOM`, `MAX_ZOOM`)
- [ ] Hover updates info panel and preview cell
- [ ] Drag-to-place walls (when option on)
- [ ] Drag-to-remove walls (when option on)
- [ ] Alt + drag (left): place selected piece in a straight line
- [ ] Alt + drag (right): remove walls in a straight line
- [ ] Alt + left-click on placed tower: +10 levels
- [ ] Popup hit-test routes through HUD (`popup_hit`, `popup_activate`)

### Keyboard (`hud.gd::_unhandled_key_input`)
- [ ] Space — pause
- [ ] Enter / KP Enter — send next wave
- [ ] +/- — speed step
- [ ] Z — undo
- [ ] **Q** — upgrade selected once
- [ ] **W** — +10 levels
- [ ] **E** — +100 levels
- [ ] **Shift+E** — max upgrade (spend all gold)
- [ ] **D** — delete piece under cursor
- [ ] **F** — toggle mass-delete (left-drag removes; Alt = line)
- [ ] T — send next 10 waves
- [ ] Y — send next 100 waves
- [ ] Esc closing order: quit prompt → save popup → help → stats → exit delete-mode → options
- [ ] Alt+Enter — queue next 10 waves (via Start button)

### Modifier consistency
- [ ] Shift+E vs E both route through level correctly
- [ ] Alt-state checked via `Input.is_key_pressed(KEY_ALT)` AND via `event.shift_pressed` consistently

---

## HUD / UX

### Bar (`hud.gd::_build_bar`)
- [ ] Bar panel stylebox opacity reads cleanly against the v48 graphics (`bg_color` alpha ~0.98)
- [ ] Buy buttons: color strip matches piece color; cost vs stock display correct
- [ ] Info panel: hovered buy / hovered placed / selected routing
- [ ] Framed info popup for trap/turret stats

### Strings & version
- [ ] `APP_NAME = "Simple Tower Defense 2D"` (hud.gd)
- [ ] `APP_VERSION` bumped to current
- [ ] `project.godot::config/name`
- [ ] `export_presets.cfg::application/product_name` + `file_description` (Windows)
- [ ] README.md heading + controls table
- [ ] RELEASES.md top blurb + new entry

### Help text (`HELP_TEXT`)
- [ ] Controls paragraph mentions current Q/W/E/Shift+E + D/F layout
- [ ] Keys legend matches `_unhandled_key_input`
- [ ] Tower / Trap stat tables reflect current numbers
- [ ] Mentions current range caps + growth rule
- [ ] Boss-leak cost wording matches `BOSS_LEAK`

### Other UI
- [ ] Wave info label: shows next wave style, boss/turtle count, gold totals
- [ ] Enemy legend: shapes/colors match `_draw_body`
- [ ] Toast position + auto-hide timing
- [ ] Options menu: every toggle persists and round-trips through `save_settings` / `load_settings`
- [ ] Save/Load popup: list refresh, default-name fallback, delete confirmation toast
- [ ] Stats popup: lifetime numbers + current-run modifiers
- [ ] Game-over screen: best wave/score + Continue button when an auto-save exists

---

## Save / load

### Format versions (`game_state.gd`)
- [ ] `SAVE_FORMAT_VERSION` — current value: **2**. Bump when the save schema changes incompatibly (renamed field, removed field, semantic change). Don't bump for additive changes that read fine via `d.get(key, default)`.
- [ ] `MAP_FORMAT_VERSION` — current value: **1**. Bump when the `user://maps/<name>.txt` format changes (e.g. adds a header line).
- [ ] `serialize_run` stamps `"v": SAVE_FORMAT_VERSION` into every save
- [ ] `is_save_compatible(data)` returns true only on exact match
- [ ] Loader (`hud._load_data`) shows "Save is from an incompatible version (got vN, expected vM)" toast on mismatch (not the generic "not found")
- [ ] When bumping: tick the constant here, add a one-liner to RELEASES so players know why old saves stopped loading
- [ ] Bump history: v2 = first save format with the "v" stamp (pre-v49). v1 = no format stamp (legacy, never loadable post-v49)

### Schema & flow
- [ ] `Level.serialize_run()` schema covers: board pieces, economy, wave_state, live enemies (HP, pos, status), in-flight spawn jobs
- [ ] `Enemy.serialize` / `deserialize` includes `leak_damage`
- [ ] Missing-key fallback defaults are sane (`d.get(key, default)`)
- [ ] Auto-save fires after each cleared wave
- [ ] Quit-save uses "Quit save - Wave N" naming
- [ ] Named saves write to `user://saves/`; map editor saves to `user://maps/`
- [ ] Game-over Continue button only shows when `auto` save exists
- [ ] Loading a save: HUD events re-emit so labels refresh

### User-data migration (`game_state._maybe_migrate_user_data`)
- [ ] Runs once at startup before `load_settings`
- [ ] Only fires when the NEW user-data dir is empty (no `save_auto.json`, no `save_manual.json`, no `settings.cfg`, no `saves/` or `maps/` content)
- [ ] Old project name: `"Tower Defense"`. New project name: `"Simple Tower Defense 2D"`. When renaming again, both constants need updating.
- [ ] Copies: `save_auto.json`, `save_manual.json`, `settings.cfg`, every file under `saves/`, every file under `maps/`

---

## Performance gates

- [ ] `GameState.reduced_gfx()` threshold = `Engine.time_scale >= 4.0`
- [ ] reduced_gfx disables: flying projectiles (→ instant hits), spawn_float, spawn_sparks
- [ ] `VISUAL_SHOT_INTERVAL = 0.22` throttles visible bullets per tower
- [ ] Per-frame caps: tower shots/frame = 12, ice pulses/frame = 12, enemy cell-steps/frame = 256
- [ ] Pool caps: `_FLOAT_CAP = 60`, `_SPARK_CAP = 300`
- [ ] Bullet uses `level_ref.enemies_near` (spatial buckets) for AOE + retarget
- [ ] Speed cycle reaches 1000× (with 500× step between 100× and 1000×)

---

## Cross-project parity (2D ↔ 3D)

When making a change, classify it per script:
- **port**: applies in both projects, copy across
- **diverge**: intentionally project-specific (note the reason)
- **n/a**: only meaningful in one (e.g. camera_rig)

Status snapshot (update after each change):

| Script | Last parity check | Notes |
|---|---|---|
| `bullet.gd` | v48 | 2D has spark hooks; 3D doesn't |
| `enemy.gd` | v48 | 2D has v48 shadow/highlight + spawn_float; 3D omits (3D meshes handle visuals) |
| `events.gd` | v48 | identical |
| `game_state.gd` | v48 | 3D adds `camera_sensitivity` (3D-only); rest shared |
| `level.gd` | v48 | 3D rewrote input for camera ray-picks; gameplay logic shared |
| `main.gd` | v48 | 3D-only scaffolding (SubViewport, CameraRig, View3D) |
| `piece_data.gd` | v48 | ranges + caps + growth rule now matched 3D |
| `structure.gd` | v48 | identical |
| `tower.gd` | v48 | visual-shot throttle + body-color bullets now matched; 3D adds `bake_mode` (3D-only) |
| `trap.gd` | v48 | 2D has v48 lit/AO strips; 3D adds `bake_mode` (3D-only) |
| `wall.gd` | v48 | 2D has v48 outline + edge strips |
| `wave_manager.gd` | v48 | `BOSS_LEAK` now matched |
| `enemy_legend.gd` | v48 | 3D adds diamond/oval shapes for legend (cosmetic) |

---

## Build / release

- [ ] `godot4 --headless --quit-after 2 --path .` exits clean (no parse errors)
- [ ] Windows export (`SimpleTowerDefense2D_win_vNN.zip`)
- [ ] Linux export (`SimpleTowerDefense2D_linux_vNN.zip`)
- [ ] macOS export (`SimpleTowerDefense2D_osx_vNN.zip`)
- [ ] Web export (`SimpleTowerDefense2D_web_vNN.zip`)
- [ ] Bare `SimpleTowerDefense2D_vNN.exe` copied alongside the zips in `/mnt/c/work/SimpleTowerDefense2D_build_vNN/` for one-click launch (no unzip needed)
- [ ] Old version artifacts removed from deploy directory
- [ ] `APP_VERSION` bumped before exporting
- [ ] RELEASES.md entry written
- [ ] Commit message format matches repo style
- [ ] Commit timed per house rule (after 5pm)
- [ ] `git tag vNN` on the release commit, then `git push --tags`
