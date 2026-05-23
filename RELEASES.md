# Releases

**Simple Tower Defense** — an endless, maze-building tower defense built in
**Godot 4.6**, everything drawn with vector primitives (no art assets). Route
enemies through your walls and survive as long as you can. Builds ship for
Windows, Linux, macOS, and Web.

## ⬇️ Downloads

Each release attaches four platform zips:

| Platform | File |
|---|---|
| Windows | `SimpleTowerDefense_win_vNN.zip` |
| Linux | `SimpleTowerDefense_linux_vNN.zip` |
| macOS | `SimpleTowerDefense_osx_vNN.zip` |
| Web | `SimpleTowerDefense_web_vNN.zip` |

**Notes:** the macOS build is unsigned — right-click → **Open** the first time to
get past Gatekeeper. The Web build must be served over HTTP (a local server or
host), not opened straight from disk.

---

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
