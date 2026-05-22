extends Node2D
## Root scene. Wires together the level, wave manager and HUD.

var level: Level
var wave_manager: WaveManager
var hud: HUD

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameState.reset()

	level = Level.new()
	level.name = "Level"
	add_child(level)

	wave_manager = WaveManager.new()
	wave_manager.name = "WaveManager"
	wave_manager.level = level
	add_child(wave_manager)

	hud = HUD.new()
	hud.name = "HUD"
	hud.wave_manager = wave_manager
	hud.level = level
	add_child(hud)

	level.hud = hud

	Events.game_over.connect(_on_game_over)

func _on_game_over() -> void:
	hud.show_end_screen()
