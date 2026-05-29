# Releases

**Simple Tower Defense 2D** — an endless, maze-building tower defense built in
**Godot 4.6**, everything drawn with vector primitives (no art assets). Route
enemies through your walls and survive as long as you can. Builds ship for
Windows, Linux, macOS, and Web.

## ⬇️ Downloads

Each release attaches four platform zips:

| Platform | File |
|---|---|
| Windows | `SimpleTowerDefense2D_win_vNN.zip` |
| Linux | `SimpleTowerDefense2D_linux_vNN.zip` |
| macOS | `SimpleTowerDefense2D_osx_vNN.zip` |
| Web | `SimpleTowerDefense2D_web_vNN.zip` |

**Notes:** the macOS build is unsigned — right-click → **Open** the first time to
get past Gatekeeper. The Web build must be served over HTTP (a local server or
host), not opened straight from disk.

---

## v54 — Laser beam colour fix + documentation pass

A small visual fix and a big internal documentation pass — no gameplay
changes, no balance changes.

**Laser beam matches its tower**
- The v49 "bullets take the tower's body colour" rule was missed on laser
  beams. They were still using the old per-type `bullet_color`. So the red
  Laser was firing a pink beam, etc. Beams now use the tower's body colour
  same as projectiles — the red Laser beams red, the (hypothetical green)
  Laser would beam green, and so on.
- The vestigial `bullet_color` member is removed from `tower.gd` and the
  `bullet_color` field is removed from every `PieceData.TYPES` entry —
  fully dead code is gone.

**Documentation pass**
Eight functions / modules got proper docstring blocks for things that
were easy to misread on a future change. No code changes - just
comments. Covers:
- The generator's 5 invariants (one continuous path, no empty space,
  blocks only from `_ham_blocked`, etc.) — at the top of
  `_build_generated_map`. Also mirrored in CHECKLIST.md.
- The damage pipeline in `enemy.gd::take_damage` — resists are
  multipliers (not reductions), vuln stacks on top.
- The two-cooldown design in `tower.gd::_process` — `_cooldown` gates
  damage, `_visual_cd` gates the bullet visual; collapsing them
  would either nerf DPS or restore the laser-stream look.
- Tower / trap scaling formulas in `piece_data.gd` written out in
  full so future balance tuning doesn't have to reverse-engineer
  `pow(1 + 0.4 * n, 1.4)` from scratch.
- Spatial buckets in `level.gd` — why they exist, what changes if
  you touch `BUCKET_SIZE`, and the "don't replace with group scans"
  warning.
- `game_state.gd` — score vs. gold semantics, stock dict contract.
- `wave_manager.gd` — HP/reward curves, boss multiplier, turtle
  ride-along, boss-leak constants.

## v53 — Generated maps: revert thinning, add block-shape variety

The v51 / v52 "cluster thinning" was the wrong tool. It removed most of
the wall mass and left maps full of empty space with scattered orphan
dots - not what generated maps should look like. Both versions are
abandoned. v53 reverts the thinning entirely and instead adds variety
**inside** the existing block-placement step.

**Reverted**
- The `_thin_to_clusters` post-process is gone. `_build_generated_map`
  is back to its v50 shape: pick a generator, stamp every wall cell.

**New: varied block shapes**
- `_generate_blocked` still places 3-5 well-separated lattice blocks the
  path winds around, but each block now has a **random shape**:
  - 60% chance — single lattice node (the classic 3×3 wall mass)
  - 30% chance — 2-node domino (3×5 or 5×3 wall mass)
  - 10% chance — 2×2 lattice cluster (5×5 wall mass)
- So most maps look like the classic dense labyrinth; some have one or
  two chunky 5×3 or 5×5 wall masses that give a more "ruined" feel.
- The single-cell-wide corridor and dense maze structure are preserved
  in every output - no empty-space failure mode.
- Verified by dumping a half-dozen generations to ASCII before shipping
  (something the v51 / v52 attempts skipped).

## v52 — Cluster maps: hotfix

The v51 cluster-style generator had two bugs that produced unplayable
maps: a giant intact wall mass survived in the middle of every thinned
map, and the rest of the board came out as salt-and-pepper single dots
instead of L-corner / 2×2 / domino clusters.

**Fixes**
- The "protected" region is now exactly the deliberate 3×3 tower-cluster
  spots the generator picked (tracked by lattice index in `_ham_blocked`),
  not "any cell inside a solid 3×3 window." The earlier check false-fired
  on accidental wall masses left behind when the Hamiltonian search didn't
  reach a corner of the board, protecting huge regions.
- Thinning switched from biased random culling to a **seed-and-grow**
  algorithm that explicitly builds clusters of 2–4 cells (L-corners,
  dominoes, 2×2s, T's, S's) until ~45% of the original wall mass is kept.
  Single-cell singletons literally cannot occur — the algorithm refuses to
  emit a cluster smaller than 2 cells.

Same 50% chance per Generated map; same persisted seed so a "Same map"
New Game replays the same layout.

## v51 — Cluster-style generated maps + health-bar polish

**Generated maps: ruins-style variant**
Half of the Generated maps you roll now come back with the wall mass thinned
into scattered **L-corner / 2×2 / domino** clusters with open gaps between,
instead of a continuous corridor wall. The path still runs the same way and
the deliberate 3×3 tower-cluster spots are preserved untouched — the rest of
the wall mass gets eroded to give an "abandoned base" / "ruins" feel.

Each Generated layout is rolled fresh from the persisted seed, so a "Same
map" New Game will replay the exact same thinning pattern.

**Health bar**
- **Moved above the body.** The bar used to sit at the enemy's middle,
  competing with the v50 vehicle bodies' turrets and canopies; it's now a
  small bar 8 px above the silhouette so the body draws clean underneath.
- **Wider** (min 32 px, scaling up with radius). Big bosses get ~58 px of
  bar so small hits are actually resolvable.
- **Damage flash.** Any hit shows the slice you just lost as a yellow chunk
  to the right of the green for a fraction of a second before catching back
  up. Even subpixel hits at late waves are now visible.

## v50 — Robot/vehicle enemy redesign

Every enemy in the game has been redrawn as a top-down robot or vehicle, and
they finally **turn to face the direction they're moving** — a small omission
the older shapes hid that the new ones make obvious. Same gameplay, same
stats, same archetypes; just a real visual identity for the roster.

**Regular enemies**
- **Grunt** is now an **armored scout buggy**: boxy hull, four corner wheels,
  domed canopy, paired forward headlights.
- **Runner** is a **race car / speeder**: tapered wedge, side wheels, cockpit
  canopy, rear spoiler, and motion lines trailing behind to sell its speed.
- **Tank** is a **battle tank**: hull between two tread strips, central
  turret with a closed hatch, gun barrel pointing forward.

**Bosses**
- **Beetle** is now a **quadruped walker mech**: oval armored carapace, four
  splayed legs with foot pads, two glowing front optics. Blue.
- **Spider** is a **spider drone**: eight legs in classic spider splay (the
  silhouette finally reads as a spider, not a diamond), single big red front
  cyclops, chassis vent slits. Red.
- **Turtle** is a **heavy siege transport**: huge domed shell, wide tread
  strips top and bottom, four glowing slit windows on the front edge. Green.

**Direction-facing**
- Every enemy now rotates to point along its travel direction. The whole
  body rotates; the health bar and status pips stay world-axis-aligned above
  it, so a Tank rounding a corner has the barrel always leading the way.

**Under the hood**
- Bodies are drawn forward = +X with a single transform; `_face` is now just
  `heading.angle()` instead of the old `+PI/2` boss-only offset.
- Each draw is parameterized by `radius`, so a future balance tweak to enemy
  size won't break the visuals.
- The HUD's enemy legend was redrawn to match — miniature top-down icons
  facing right, so what you see at the bottom of the screen previews the
  next wave's silhouettes.

## v49 — 2D rename, hotkey overhaul, economy & balance pass

Renamed to **Simple Tower Defense 2D**, a chunky hotkey overhaul (the upgrade
keys now match the 3D version), a wider economy pass, and a pile of polish.

**Identity & UI**
- Renamed to **Simple Tower Defense 2D** across the title bar, Options panel,
  Help, README and downloads (`SimpleTowerDefense2D_<plat>_vNN.zip`).
- HUD bar gets a solid dark backing so it reads cleanly against the v48
  graphics (the old default-themed panel had gone too see-through).

**Hotkeys**
- **Q** upgrades the selected tower once; **W** +10 levels; **E** +100;
  **Shift+E** spends all your gold maxing it. (Old `Q` = max-upgrade is now
  `Shift+E`.)
- **D** deletes the piece under the cursor (quick single delete).
- **F** toggles mass-delete (left-drag removes, `Alt`+drag clears a line).
  Old `D` = mass-delete moved to `F` to make room for D = quick delete.
- Speed cycle adds a **500×** stop between 100× and 1000×.

**Gameplay**
- **Bosses leaking actually hurts.** Beetles and spiders cost **5 lives**,
  turtles **8** (normal enemies still cost 1).
- **Visual shot throttle.** Fast towers cap their visible projectiles at
  ~5/second so rapid fire reads as distinct rounds instead of a solid stream;
  the extra shots between hit instantly for full damage.
- **Bullets match their tower's color** (the old per-type palette overlapped —
  Missile and Cannon were both orange, etc.).
- **Range rebalance.** Base tower ranges roughly halved with per-type caps
  (Bullet/Ice 160, Cannon 180, Laser 200, Missile 220, Sniper 300), and range
  now grows every **2 levels** instead of every level. Damage and fire rate
  keep scaling, so coverage matters early and DPS late.
- **Generated map: Same / New prompt.** New Game on a Generated map now asks
  whether to keep the same layout or roll a new one (the seed persists across
  sessions). Game-over **Restart** always replays the same map.

**Economy**
- **Normal start: 240g, 20 lives, 30 free walls.** The 3 free Bullet Towers
  are gone — that 120g of value rolled into the starting purse, so you spend
  the same total but you choose what to build with it.
- **Hard mode rebalance.** 120g, 10 lives, 15 free walls — explicit numbers
  rather than the old "60% gold" multiplier so each lever can be tuned.

**Project hygiene**
- **MIT License** with a separately-fenced friendly note asking forks/mods to
  drop a line on GitHub. (Not part of the license — license-detection tools
  still see standard MIT.)
- **`CHECKLIST.md`** — a living regression / parity checklist mirrored across
  the 2D and 3D projects (gameplay numbers, controls, HUD, save/load, perf,
  build/release).
- **`TODO.md`** — scratchpad for ideas, balance-to-test, polish, known issues.

## v48 — Updated graphics

A visual polish pass. Every piece now has a soft elliptical ground shadow, a
crisp opaque outline, and a small top-lit highlight that fakes a "molded" feel
on the flat shapes — without changing the no-assets identity. Boxy pieces
(walls, traps) also get a top-lit edge strip and a bottom AO strip to read as
solid floor tiles.

**Effects**
- Kills now spawn a drifting **`+gold`** popup in the wave-info gold colour.
- Bullet impacts (single-target and AOE) burst a small set of **sparks** in the
  projectile's colour.
- Both effects auto-skip during reduced graphics (≥4×) so high-speed runs stay
  smooth, with capped pools.

## v47 — Mass-delete, mid-game save/load & polish

The biggest content drop yet: save your run at any moment, clear the board fast,
and a pile of new hotkeys.

**Power tools & hotkeys**
- **Mass-delete mode (`D`):** left-drag removes any piece, `Alt`+drag clears a
  whole line — each sale refunds gold; `Esc` / right-click / `D` exits.
- **`Q`** maxes out the selected tower (pours all your gold into it).
- **`T` / `Y`** send the next **10 / 100** waves; the speed cycle now reaches
  **1000×**.
- **Quit** option in Options, with a "save first?" prompt.

**Save & Load**
- Save the **exact current moment** — board, economy, in-flight waves, and every
  live enemy (HP, position, status effects) — to **unlimited named saves** on
  disk, via a Save/Load popup.
- Auto-save each cleared wave; **Continue** on the game-over screen resumes it.

**Help & presentation**
- Color-highlighted hotkeys, refreshed Tower/Trap stat tables and the Amplifier
  description; framed trap/turret hover stats and status toast (white on a dark
  panel).

## v42 — Max-upgrade hotkey

- Select a tower/trap and press **`Q`** to spend all your gold upgrading it.

## v40–v41 — True mid-game save/load

- Save and restore the exact state, including live enemies and in-flight spawn
  jobs, to unlimited named save files on disk.
- Auto-save each wave + a **Continue** button; `Esc` closes the save popup first.

## v38–v39 — Save/Load foundation; economy readouts

- First save/load implementation and confirmation prompts.
- Gold Mine hover shows an "Amplified → gold → board total" breakdown.

## v35–v37 — Slow rework, Amplifier & balance

- **Tar** is pure slow (no damage); **Tar & Ice** share one curve reaching 80%
  by level 40, and up to **95% next to an Amplifier**.
- **Amplifier** boosts every adjacent piece's effect — damage, slow, DoT, splash
  (AOE) area, and an adjacent Gold Mine's rate.
- **Per-tower range/AOE caps** so a maxed tower can't blanket the whole map.
- Traps reordered; Tar/Poison/Fire/Spike all cost 50, Volcano 100.
- Abbreviated big numbers (12.3K / 4.5M), Alt-send the next 10 waves, board-size
  dropdown, and a desktop/web arrow-glyph fix.

## v34 — Support-tower interactions

- Amplifier can boost an adjacent Gold Mine's rate; Gold Mines stack board-wide;
  the HUD shows Wave / Enhanced gold totals.
- Removed the old Maze and Fun maps.

## v33 — Support towers & generated maps

- New support towers: **Gold Mine** (more kill gold) and **Amplifier**.
- Procedurally **Generated** single-path labyrinth maps — a fresh layout each
  game, with solid 3×3 blocks for tower clusters.
- Boss/economy rework (beetles, spiders, turtles) and a balance pass.
