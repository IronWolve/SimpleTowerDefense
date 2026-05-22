extends Node2D
## Root scene. Wires together the level, wave manager and HUD.

var level: Level
var wave_manager: WaveManager
var hud: HUD

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	# Resuming a saved run? Restore economy now; the board and wave counters come
	# back as their nodes are created. Otherwise start a fresh run.
	var loading: bool = not GameState.pending_load.is_empty()
	var save_data: Dictionary = GameState.pending_load
	if loading:
		GameState.apply_run_state(save_data)
	else:
		GameState.reset()

	level = Level.new()
	level.name = "Level"
	add_child(level)  # Level._ready rebuilds the board from pending_load when loading.

	wave_manager = WaveManager.new()
	wave_manager.name = "WaveManager"
	wave_manager.level = level
	add_child(wave_manager)
	if loading:
		wave_manager.restore_state(
			int(save_data.get("started", 0)),
			bool(save_data.get("auto", true)),
			int(save_data.get("bonus_through", 0)))

	hud = HUD.new()
	hud.name = "HUD"
	hud.wave_manager = wave_manager
	hud.level = level
	add_child(hud)

	level.hud = hud

	Events.game_over.connect(_on_game_over)

	if loading:
		GameState.pending_load = {}
		# Push the restored values into the freshly-built HUD.
		Events.gold_changed.emit(GameState.gold)
		Events.lives_changed.emit(GameState.lives)
		Events.stock_changed.emit()
		hud._refresh_stats()
		hud._update_wave_info()
		hud._update_start()

func _on_game_over() -> void:
	hud.show_end_screen()
