# Releases

Version history for **Simple Tower Defense**. Builds for Windows, Linux, macOS,
and Web are produced from the same source via the included export presets.

> Tip: to publish a downloadable release on GitHub, draft a new Release for the
> matching tag and attach the four platform zips
> (`SimpleTowerDefense_{win,linux,osx,web}_vNN.zip`).

---

## v47 — Help & polish
- Hotkeys in the Help screen are now color-highlighted.
- Refreshed the Tower/Trap stat tables to the real current numbers, with a note
  that range/splash cap out while damage and fire rate keep scaling.
- Corrected the Amplifier description (it boosts **all** adjacent effects, not
  just damage).
- **Esc** now exits mass-delete mode (before falling through to Options).
- Quit-save is named `Quit save - Wave N`.

## v43–v46 — Power tools & speed
- **Mass-delete mode (D):** left-drag removes any piece (Alt = a whole line),
  refunding like a sell; right-click or D exits.
- **Send 10 / 100 waves (T / Y)** in addition to Alt-send.
- **Quit** option in Options, with a "save first?" prompt.
- Trap/turret hover stats and the status toast now use a framed panel (white
  text on a dark frame).
- Speed cycle extended up to **1000×** (¼× … 1000×).

## v42 — Max-upgrade hotkey
- Select a tower/trap and press **Q** to spend all your gold upgrading it.

## v40–v41 — True mid-game save/load
- Save the **exact current moment** — board, economy, in-flight waves, and every
  live enemy (HP, position, status effects) — to **unlimited named save files**
  on disk, via a Save/Load popup.
- Auto-save each cleared wave; **Continue** on the game-over screen resumes it.
- Esc closes the save/load popup before the menu.

## v38–v39 — Save/Load foundation; economy readouts
- First save/load implementation and confirm prompts.
- Gold Mine hover shows an "Amplified → gold → board total" line.

## v35–v37 — Slow rework, Amplifier, balance
- **Tar** is pure slow (no damage); **Tar & Ice** share one curve reaching 80%
  by L40, and up to **95% next to an Amplifier**.
- **Amplifier** boosts every adjacent piece's effect — damage, slow, DoT, splash
  (AOE) area, and an adjacent Gold Mine's rate.
- **Per-tower range/AOE caps** so a maxed tower can't blanket the whole map.
- Traps reordered; Tar/Poison/Fire/Spike all cost 50, Volcano 100.
- Abbreviated big numbers (12.3K / 4.5M), Alt-send the next 10 waves, board-size
  dropdown, desktop/web arrow-glyph fix.

## v34 — Support-tower interactions
- Amplifier can boost an adjacent Gold Mine's rate; Gold Mines stack board-wide;
  HUD shows Wave / Enhanced gold totals.
- Removed the old Maze and Fun maps.

## v33 — Support towers & generated maps
- New support towers: **Gold Mine** (more kill gold) and **Amplifier**.
- Procedurally **Generated** single-path labyrinth maps (a fresh layout each
  game, with solid 3×3 blocks for tower clusters).
- Boss/economy rework (beetles, spiders, turtles) and a balance pass.
