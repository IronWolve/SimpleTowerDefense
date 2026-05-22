extends Node
## Persistent run state. Autoloaded, so it survives scene reloads on restart.

const STARTING_GOLD := 75
const STARTING_LIVES := 20
const STARTING_WALLS := 30
const STARTING_TOWERS := 3
const SETTINGS_PATH := "user://settings.cfg"
## Where custom maps saved from the editor are stored. One .txt per map.
const MAPS_DIR := "user://maps"

var gold := STARTING_GOLD
var lives := STARTING_LIVES
var wave := 0
var score := 0
var game_over := false
var stock := {"wall": STARTING_WALLS, "tower": STARTING_TOWERS}

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

func _ready() -> void:
	load_settings()
	if first_played_unix == 0:
		first_played_unix = int(Time.get_unix_time_from_system())
		save_settings()

func _process(delta: float) -> void:
	# Count wall-clock seconds the user spent in the app (paused time included
	# so the number reflects time invested, not just time-on-task).
	total_play_seconds += delta

func reset() -> void:
	# Capture the just-finished run's high before wiping it.
	_check_best()
	# Hard mode (bonus_lives_per_wave off): start with 40% less gold.
	var hard := not bonus_lives_per_wave
	gold = int(round(STARTING_GOLD * 0.6)) if hard else STARTING_GOLD
	lives = STARTING_LIVES
	wave = 0
	score = 0
	game_over = false
	stock = {"wall": STARTING_WALLS, "tower": STARTING_TOWERS}
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
