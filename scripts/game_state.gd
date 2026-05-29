extends Node
## Persistent run state. Autoloaded, so it survives scene reloads on restart.

const STARTING_GOLD := 240
const STARTING_LIVES := 20
const STARTING_WALLS := 30
const STARTING_TOWERS := 0
## Hard mode starting values (used when bonus_lives_per_wave is off). Explicit
## numbers rather than a multiplier so each lever can be tuned independently.
const HARD_STARTING_GOLD := 120
const HARD_STARTING_LIVES := 10
const HARD_STARTING_WALLS := 15
const SETTINGS_PATH := "user://settings.cfg"
## Where custom maps saved from the editor are stored. One .txt per map.
const MAPS_DIR := "user://maps"

## Save / map format versions. Stamped into every save we write; the loader
## refuses files whose version doesn't match. Bump deliberately whenever the
## on-disk schema changes incompatibly (e.g. a renamed/removed field). Don't
## bump for additive changes that read fine with a `.get(key, default)`.
##
## Tracked in CHECKLIST.md under "Save / load". When you bump one of these,
## tick the matching item and add a one-line note to RELEASES so players know
## why their old saves stopped loading.
const SAVE_FORMAT_VERSION := 2
const MAP_FORMAT_VERSION := 1

## Old project name (from before the v49 rename). Used by the one-shot
## startup migration to find user data left behind when Godot's user:// path
## moved with the rename.
const OLD_PROJECT_NAME := "Tower Defense"
const NEW_PROJECT_NAME := "Simple Tower Defense 2D"

## Spendable currency. Goes up on kills (kill reward + Gold Mine bonus),
## down on placement / upgrade. Capped only by signed-int range. The HUD
## shows it abbreviated above ~10K.
var gold := STARTING_GOLD
var lives := STARTING_LIVES
## Current wave NUMBER. Goes up when WaveManager actually launches a wave;
## a "queued" send-N waves doesn't bump it until each fires. Best-wave stat
## compares against this.
var wave := 0
## Cumulative SCORE for the run. NOT the same as gold - score reflects how
## much enemy reward you generated this run regardless of how you spent it,
## so it's the right comparison for the best-score stat. Kill reward adds
## both gold and score, but sell refunds only return gold.
var score := 0
var game_over := false
## Free-piece stock counters. Only "wall" and "tower" (the basic Bullet
## Tower) get stock. Every other tower and every trap is paid from gold
## the moment it's placed - no free first one. Stock counts down on each
## free placement; when it hits 0, the buy button switches from
## "Wall x30" to "Wall $10" and the player starts paying gold.
##
## DO NOT add other types to this dict without also wiring stock_changed
## events and updating the HUD buy-button render in _refresh_buy_buttons.
var stock := {"wall": STARTING_WALLS, "tower": STARTING_TOWERS}

## Set to a save snapshot just before reload_current_scene() to resume a run
## instead of starting fresh; main.gd and Level read it on the fresh scene.
## Empty dictionary == start a normal new game.
var pending_load := {}

## Persistent option (kept across Reset Game): grant lives per wave cleared.
## On by default; Hard mode in the options menu turns it off.
var bonus_lives_per_wave := true
## Persistent option: never run out of gold.
var unlimited_money := false
## Persistent option: enemies that leak don't subtract from lives.
var unlimited_lives := false
## Persistent option: walls are free to place.
var free_walls := false
## Persistent option: hold left-click and drag to draw walls. On by default.
var drag_draw_walls := true
## Persistent option: 30s inter-wave timer; sending a non-boss wave early
## refunds gold for each second left on the countdown. On by default.
var round_timer_bonus := true
## Persistent option: board size for a new game (0 normal, 1 large, 2 huge).
var board_size := 0
## Persistent option: which pre-built map to use for a new game.
## One of: "none" (open field), "spiral", "generate", or "custom:<name>".
var map_type := "none"
## Seed used the last time we built a Generated map. 0 = "no seed stored
## yet; roll a fresh one on the next generation". On New Game with map_type
## "generate" we ask whether to keep the same map (reuse this seed) or roll
## a new one (clear to 0 first).
var generated_seed: int = 0

## Persistent option: borderless fullscreen on (true) vs windowed (false).
## Toggled in-game with F11. Applied at boot from save_settings file so the
## window comes up the way it was left.
var fullscreen: bool = false

## Best-ever wave reached and best-ever score, persisted across sessions.
var best_wave := 0
var best_score := 0
## Lifetime stats persisted across sessions.
var total_kills := 0
var total_games := 0
var total_play_seconds := 0.0
var best_tower_level := 0
var first_played_unix := 0
var last_played_unix := 0

## At or above this game speed, cosmetic effects are skipped to cut visual
## noise and load: shot towers deal damage instantly (no flying bullet), and
## the volcano's eruption shock-wave animation is suppressed.
const FAST_GFX_SCALE := 4.0

func reduced_gfx() -> bool:
	return Engine.time_scale >= FAST_GFX_SCALE

## Arrow glyph for info/help text: a real arrow on desktop, ASCII "->" on web
## (the web build's fallback font can't render the Unicode arrow).
func arrow() -> String:
	return "->" if OS.has_feature("web") else "→"

const _ABBREV_UNITS := ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp"]

## Compact display for large numbers so long runs stay readable:
## 850 -> "850", 12345 -> "12.3K", 4_500_000 -> "4.5M", 1.2e12 -> "1.2T".
## Under 1000 it shows a plain integer; above, 3 significant digits + a suffix.
func abbrev(value: float) -> String:
	var neg := value < 0.0
	var n := absf(value)
	if n < 1000.0:
		return ("-" if neg else "") + str(int(round(n)))
	var mag := 0
	while n >= 1000.0 and mag < _ABBREV_UNITS.size():
		n /= 1000.0
		mag += 1
	var s: String
	if n < 10.0:
		s = "%.2f" % n
	elif n < 100.0:
		s = "%.1f" % n
	else:
		s = "%.0f" % n
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return ("-" if neg else "") + s + _ABBREV_UNITS[mag - 1]

func _ready() -> void:
	_maybe_migrate_user_data()
	load_settings()
	if first_played_unix == 0:
		first_played_unix = int(Time.get_unix_time_from_system())
		save_settings()

## One-shot user-data migration. The v49 rename to "Simple Tower Defense 2D"
## moved Godot's user:// path (it's derived from project.config/name), which
## stranded every save/map/setting under the OLD "Tower Defense" folder. This
## checks the old folder, and if the new folder hasn't been used yet, copies
## saves, the auto/manual slots, named saves, custom maps and settings over.
## Idempotent: once anything's in the new folder, it does nothing.
func _maybe_migrate_user_data() -> void:
	var new_dir := OS.get_user_data_dir()
	# Only run when this is actually the renamed project (someone forks the
	# code under a different name? leave their data alone).
	if not new_dir.contains(NEW_PROJECT_NAME):
		return
	var old_dir := new_dir.replace(NEW_PROJECT_NAME, OLD_PROJECT_NAME)
	if old_dir == new_dir or not DirAccess.dir_exists_absolute(old_dir):
		return
	# Refuse if the new dir already has gameplay content - a player who has
	# already played v49 must not have it overwritten by a stale older copy.
	if _user_dir_has_content(new_dir):
		return
	# Copy single-file slots, then walk subdirectories.
	_copy_file(old_dir + "/save_auto.json",   new_dir + "/save_auto.json")
	_copy_file(old_dir + "/save_manual.json", new_dir + "/save_manual.json")
	_copy_file(old_dir + "/settings.cfg",     new_dir + "/settings.cfg")
	_copy_dir(old_dir + "/saves", new_dir + "/saves")
	_copy_dir(old_dir + "/maps",  new_dir + "/maps")
	print("Migrated user data from %s to %s" % [old_dir, new_dir])

## True if the dir contains any save / map / settings file. Used to gate the
## migration so it never overwrites in-progress v49 data.
func _user_dir_has_content(dir: String) -> bool:
	if FileAccess.file_exists(dir + "/save_auto.json"): return true
	if FileAccess.file_exists(dir + "/save_manual.json"): return true
	if FileAccess.file_exists(dir + "/settings.cfg"): return true
	if _dir_has_files(dir + "/saves"): return true
	if _dir_has_files(dir + "/maps"): return true
	return false

func _dir_has_files(dir: String) -> bool:
	if not DirAccess.dir_exists_absolute(dir):
		return false
	var d := DirAccess.open(dir)
	if d == null:
		return false
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir():
			d.list_dir_end()
			return true
		n = d.get_next()
	d.list_dir_end()
	return false

## Hard cap on files we'll migrate from the old user-data dir. Real saves
## top out around 100 KB; anything bigger is either corrupt or hostile and
## not worth the OOM risk on a low-memory device.
const _MIGRATION_MAX_FILE := 10 * 1024 * 1024  # 10 MiB

func _copy_file(src: String, dst: String) -> void:
	if not FileAccess.file_exists(src):
		return
	var sf := FileAccess.open(src, FileAccess.READ)
	if sf == null:
		return
	var n := sf.get_length()
	if n > _MIGRATION_MAX_FILE:
		sf.close()
		push_warning("Skipped migration of %s: %d bytes exceeds %d cap" %
			[src, n, _MIGRATION_MAX_FILE])
		return
	var data := sf.get_buffer(n)
	sf.close()
	var df := FileAccess.open(dst, FileAccess.WRITE)
	if df == null:
		return
	df.store_buffer(data)
	df.close()

func _copy_dir(src: String, dst: String) -> void:
	if not DirAccess.dir_exists_absolute(src):
		return
	DirAccess.make_dir_recursive_absolute(dst)
	var d := DirAccess.open(src)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir():
			_copy_file(src + "/" + n, dst + "/" + n)
		n = d.get_next()
	d.list_dir_end()

## True when the snapshot can be loaded by this build. We refuse mismatched
## save versions cleanly (with a toast) instead of crashing on missing fields.
func is_save_compatible(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	return int(data.get("v", 0)) == SAVE_FORMAT_VERSION

func _process(delta: float) -> void:
	# Count wall-clock seconds the user spent in the app (paused time included
	# so the number reflects time invested, not just time-on-task).
	total_play_seconds += delta

func reset() -> void:
	# Capture the just-finished run's high before wiping it.
	_check_best()
	# Hard mode (bonus_lives_per_wave off): tighter gold / lives / wall stock.
	var hard := not bonus_lives_per_wave
	gold = HARD_STARTING_GOLD if hard else STARTING_GOLD
	lives = HARD_STARTING_LIVES if hard else STARTING_LIVES
	wave = 0
	score = 0
	game_over = false
	stock = {
		"wall": HARD_STARTING_WALLS if hard else STARTING_WALLS,
		"tower": STARTING_TOWERS,
	}
	total_games += 1
	last_played_unix = int(Time.get_unix_time_from_system())
	save_settings()

## Saves persistent options and best stats so they survive a relaunch.
func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("options", "bonus_lives_per_wave", bonus_lives_per_wave)
	c.set_value("options", "unlimited_money", unlimited_money)
	c.set_value("options", "unlimited_lives", unlimited_lives)
	c.set_value("options", "free_walls", free_walls)
	c.set_value("options", "drag_draw_walls", drag_draw_walls)
	c.set_value("options", "round_timer_bonus", round_timer_bonus)
	c.set_value("options", "map_type", map_type)
	c.set_value("options", "board_size", board_size)
	c.set_value("options", "generated_seed", generated_seed)
	c.set_value("options", "fullscreen", fullscreen)
	c.set_value("stats", "best_wave", best_wave)
	c.set_value("stats", "best_score", best_score)
	c.set_value("stats", "total_kills", total_kills)
	c.set_value("stats", "total_games", total_games)
	c.set_value("stats", "total_play_seconds", total_play_seconds)
	c.set_value("stats", "best_tower_level", best_tower_level)
	c.set_value("stats", "first_played_unix", first_played_unix)
	c.set_value("stats", "last_played_unix", last_played_unix)
	c.save(SETTINGS_PATH)

func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) != OK:
		return
	bonus_lives_per_wave = c.get_value("options", "bonus_lives_per_wave", bonus_lives_per_wave)
	unlimited_money = c.get_value("options", "unlimited_money", unlimited_money)
	unlimited_lives = c.get_value("options", "unlimited_lives", unlimited_lives)
	free_walls = c.get_value("options", "free_walls", free_walls)
	drag_draw_walls = c.get_value("options", "drag_draw_walls", drag_draw_walls)
	round_timer_bonus = c.get_value("options", "round_timer_bonus", round_timer_bonus)
	var stored: String = c.get_value("options", "map_type", "none")
	# Maze and Fun Map were removed; treat any old saved value as Open field.
	if stored in ["maze", "fun"]:
		stored = "none"
	map_type = stored
	board_size = c.get_value("options", "board_size", board_size)
	generated_seed = c.get_value("options", "generated_seed", generated_seed)
	fullscreen = c.get_value("options", "fullscreen", fullscreen)
	best_wave = c.get_value("stats", "best_wave", best_wave)
	best_score = c.get_value("stats", "best_score", best_score)
	total_kills = c.get_value("stats", "total_kills", total_kills)
	total_games = c.get_value("stats", "total_games", total_games)
	total_play_seconds = c.get_value("stats", "total_play_seconds", total_play_seconds)
	best_tower_level = c.get_value("stats", "best_tower_level", best_tower_level)
	first_played_unix = c.get_value("stats", "first_played_unix", first_played_unix)
	last_played_unix = c.get_value("stats", "last_played_unix", last_played_unix)

## Saves a wall grid (one string per row, "0"/"1" per cell) under MAPS_DIR.
func save_map(map_name: String, grid: Array) -> bool:
	_ensure_maps_dir()
	var path := "%s/%s.txt" % [MAPS_DIR, map_name]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	for line in grid:
		f.store_line(line)
	f.close()
	return true

## Reads a saved map's wall grid as an Array of strings, one per row.
func load_map_grid(map_name: String) -> Array:
	var path := "%s/%s.txt" % [MAPS_DIR, map_name]
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	var out: Array = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.length() > 0:
			out.append(line)
	f.close()
	return out

## Names (without `.txt`) of every saved map under MAPS_DIR, sorted.
func list_custom_maps() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(MAPS_DIR):
		return out
	var d := DirAccess.open(MAPS_DIR)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir() and n.ends_with(".txt"):
			out.append(n.substr(0, n.length() - 4))
		n = d.get_next()
	d.list_dir_end()
	out.sort()
	return out

func _ensure_maps_dir() -> void:
	if not DirAccess.dir_exists_absolute(MAPS_DIR):
		DirAccess.make_dir_recursive_absolute(MAPS_DIR)

## --- Save / load a run (JSON snapshot in user://). Two slots: "auto" (written
## each wave clear) and "manual" (the in-game Save Game button). ---
func _save_path(slot: String) -> String:
	return "user://save_%s.json" % slot

func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_save_path(slot))

func write_save(slot: String, data: Dictionary) -> bool:
	var f := FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true

func read_save(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(_save_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}

## --- Named saves on disk (the Save/Load popup). One JSON per name under
## user://saves/, separate from the "auto" slot at the user:// root. ---
const SAVES_DIR := "user://saves"

func _ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)

func _named_save_path(save_name: String) -> String:
	return "%s/%s.json" % [SAVES_DIR, save_name]

## Names (without .json) of saved games, newest first.
func list_saves() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		return out
	var d := DirAccess.open(SAVES_DIR)
	if d == null:
		return out
	var named: Array = []
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir() and n.ends_with(".json"):
			var base := n.substr(0, n.length() - 5)
			named.append([base, FileAccess.get_modified_time(_named_save_path(base))])
		n = d.get_next()
	d.list_dir_end()
	named.sort_custom(func(a, b): return a[1] > b[1])
	for entry in named:
		out.append(entry[0])
	return out

func write_named_save(save_name: String, data: Dictionary) -> bool:
	_ensure_saves_dir()
	var f := FileAccess.open(_named_save_path(save_name), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true

func read_named_save(save_name: String) -> Dictionary:
	var path := _named_save_path(save_name)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}

func delete_named_save(save_name: String) -> void:
	var path := _named_save_path(save_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

## Restore the run-level economy from a save snapshot (board/pieces are rebuilt
## by Level; wave counters by WaveManager). Called by main.gd on a load.
func apply_run_state(data: Dictionary) -> void:
	gold = int(data.get("gold", STARTING_GOLD))
	lives = int(data.get("lives", STARTING_LIVES))
	wave = int(data.get("wave", 0))
	score = int(data.get("score", 0))
	game_over = false
	var st: Dictionary = data.get("stock", {})
	stock = {"wall": int(st.get("wall", 0)), "tower": int(st.get("tower", 0))}
	board_size = int(data.get("board_size", board_size))

## Wipe the persistent best wave / best score back to zero.
func reset_best() -> void:
	best_wave = 0
	best_score = 0
	total_kills = 0
	total_games = 0
	total_play_seconds = 0.0
	best_tower_level = 0
	first_played_unix = int(Time.get_unix_time_from_system())
	last_played_unix = 0
	save_settings()

func _check_best() -> void:
	var changed := false
	if wave > best_wave:
		best_wave = wave
		changed = true
	if score > best_score:
		best_score = score
		changed = true
	if changed:
		save_settings()

func can_afford(cost: int) -> bool:
	return unlimited_money or gold >= cost

func spend(cost: int) -> bool:
	if unlimited_money:
		return true
	if not can_afford(cost):
		return false
	gold -= cost
	Events.gold_changed.emit(gold)
	return true

func add_gold(amount: int) -> void:
	gold += amount
	Events.gold_changed.emit(gold)

func add_lives(amount: int) -> void:
	lives += amount
	Events.lives_changed.emit(lives)

func stock_of(key: String) -> int:
	return stock.get(key, 0)

func take_stock(key: String) -> bool:
	if stock.get(key, 0) > 0:
		stock[key] -= 1
		Events.stock_changed.emit()
		return true
	return false

func add_stock(key: String, amount: int) -> void:
	if stock.has(key):
		stock[key] += amount
		Events.stock_changed.emit()

func lose_life(amount: int) -> void:
	if game_over or unlimited_lives:
		return
	lives = maxi(0, lives - amount)
	Events.lives_changed.emit(lives)
	if lives <= 0:
		game_over = true
		_check_best()
		Events.game_over.emit()
