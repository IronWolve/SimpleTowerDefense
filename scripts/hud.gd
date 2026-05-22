class_name HUD
extends CanvasLayer
## Bottom control bar: stats, buy buttons, speed, auto-advance toggle.
## Placed pieces use a floating popup for upgrade/sell.

const BAR_Y := 600.0
const APP_NAME := "Simple Tower Defense"
const APP_VERSION := "v34"
const BUY_TYPES := ["tower", "ice", "laser", "cannon", "sniper", "missile",
	"gold", "amplifier",
	"wall", "tar_trap", "spike_trap", "poison_trap", "fire_trap", "volcano_trap"]
const SPEEDS := [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 20.0, 50.0, 100.0]
const _H := "[font_size=17][color=#99a3d1][b]"
const _HE := "[/b][/color][/font_size]\n"
const HELP_TEXT := _H + "Controls" + _HE + \
"""Mouse wheel zooms; hold middle button and drag to pan when zoomed in. Speed button: left-click faster, right-click slower (1/4x to 100x). Pause freezes the game. Hold Alt and drag with any piece selected to place (or remove walls) in a straight line. Alt + left-click a placed turret upgrades it ten levels at once (stops when gold runs out).

[b]Keys:[/b] Space pauses, Enter sends the next wave, +/- adjusts speed, Esc toggles Options (or closes Help).

""" + _H + "Goal" + _HE + \
"""Build a maze of walls to route enemies toward your towers and defend. Enemies that reach the exit cost lives - the run ends at zero. The game is endless; survive as long as you can. Best wave / score is shown on the game-over screen.

""" + _H + "Building" + _HE + \
"""Buy pieces from the bottom bar. Place a tower on a wall to replace it. Left-click a placed piece to upgrade, right-click to sell. Gold comes from kills. A wave won't start unless enemies have a path out.

""" + _H + "Towers" + _HE + \
"""Bullet and Sniper fire single shots; Cannon and Missile deal splash damage; Laser burns a continuous single-target beam; Ice is an AOE frost field - every enemy in range is slowed on each pulse (no damage). Two support towers don't attack: Gold Mine raises the gold you earn from kills (+0.5%/level, all of them stack), and Amplifier adds +0.5%/level damage to the 8 towers touching it (place it in the middle of a cluster).

""" + _H + "Traps" + _HE + \
"""Tar slows, Spike damages on contact, Poison and Fire burn over time (Poison also makes enemies take extra damage from everything), Volcano erupts every second and damages every enemy in its area.

""" + _H + "Enemies & Waves" + _HE + \
"""Runners are fast and resist Poison; Tanks are slow, tough and resist Fire. Each wave rotates a deploy style - Steady, Swarm (fast packs), Heavy (tanks), Squads (same-type bursts) - so no two in a row feel alike; the Next-wave label shows which. Boss waves hit at 5, 15, 25, ... with growing boss counts (1, 2, 3, 5, 7, ...) - a mix of beetles and spiders - trickled in 1-3 at a time alongside that wave's normal enemies. Each boss wave also brings tanky, slow Turtles (1 at wave 5, +1 each boss wave) that get tougher every boss level. Auto sends waves for you. With the 30s round timer on, sending a non-boss wave early grants bonus gold that grows +2% per wave.

""" + _H + "Modifiers (Options)" + _HE + \
"""Toggle in Options: Hard mode (no bonus lives, 40% less starting gold), Unlimited lives / money, No-cost walls, 30s round timer with early-send bonus, hold-drag wall building. Settings persist across sessions.

""" + _H + "Maps & Editor" + _HE + \
"""In Options pick a pre-built map (Open field or Spiral), choose Generated for one continuous single-path labyrinth - no branches or dead ends, with a few solid 3x3 blocks to build tower clusters on (great for the Amplifier), a fresh layout each New Game (spawn/base move to the path's ends), or build your own: enable No-cost walls, lay out your walls in-game, type a name and press Save. Saved maps appear in the dropdown as "Custom - name". Click Maps Folder to open the save directory in your file manager (desktop only).

""" + _H + "Tower Stats   (Level 1 -> Level 10)" + _HE + \
"""[b]Bullet[/b]   15 dmg @ 1.0/s    ->   109 dmg @ 3.25/s   (rate caps at 4.0/s)
[b]Cannon[/b]   31 dmg @ 0.75/s, AOE 56   ->   223 dmg @ 1.29/s, AOE 101
[b]Laser[/b]    39 dmg, beam, single target   ->   286 dmg, beam, single target
[b]Ice[/b]      AOE @ 0.6/s: 5% slow 2.6s   ->   @ 1.0/s: 59% slow 11.6s   (no damage)
[b]Sniper[/b]   162 dmg @ 1.0/s   ->   1 762 dmg @ 1.0/s   (rate x2 / 30 lvl)
[b]Missile[/b]  60 dmg @ 1.0/s, AOE 82   ->   436 dmg @ 1.0/s, AOE 127   (rate x2 / 30 lvl)

""" + _H + "Trap Stats   (Level 1 -> Level 10)" + _HE + \
"""[b]Tar[/b]       slow 5% for as long as the enemy is on it   ->   slow 90% (cap at L10), +10%/level
[b]Spike[/b]     contact: 2 dps or 0.8%/s of max HP   ->   20 dps or 8%/s   (cap 12%/s; halved vs bosses)
[b]Poison[/b]    8 dps DoT for 3.9 s, +5% dmg taken   ->   79 dps for 12.9 s, +14% dmg taken   (+1 s & +1%/level)
[b]Fire[/b]      15 dps DoT for 1.95 s after stepping on it   ->   148 dps for 10.95 s   (+1 s / level)
[b]Volcano[/b]   erupts every 0.8 s, 19 dmg per pulse, AOE 60 (3x3 cells, fixed)   ->   188 dmg per pulse"""

var wave_manager: WaveManager
var level: Level
var selected_type := ""
var _hovered_buy_type := ""

var _gold_label: Label
var _lives_label: Label
var _wave_label: Label
var _score_label: Label
var _info_label: Label
var _wave_info_label: Label
var _enemy_legend: EnemyLegend
var _start_button: Button
var _pause_button: Button
var _undo_button: Button
var _speed_button: Button
var _auto_button: Button
var _newgame_button: Button
var _board_button: Button
var _map_select: OptionButton
var _map_name_input: LineEdit
var _save_map_button: Button
## Names of saved custom maps, in dropdown-display order.
var _custom_map_names: PackedStringArray = PackedStringArray()
var _hard_toggle: CheckButton
var _money_toggle: CheckButton
var _walls_toggle: CheckButton
var _drag_toggle: CheckButton
var _timer_toggle: CheckButton
var _lives_toggle: CheckButton
var _options_button: Button
var _options_root: ColorRect
var _help_root: ColorRect
var _stats_root: ColorRect
var _stats_body: RichTextLabel
var _stats_body2: RichTextLabel
var _hovered_structure: Structure
var _buy_buttons := {}
var _speed_idx := 2
var _new_game_armed := false
var _new_game_armed_ms := 0
var _was_paused := false
var _end_root: ColorRect
var _toast_label: Label
var _toast_until_ms := 0

var _popup: Button
var _popup_target: Structure
var _popup_action := ""
var _popup_shown_ms := 0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_bar()
	_build_popup()
	_build_options()
	_build_help()
	_build_stats()
	_build_toast()
	_connect_events()
	_refresh_stats()
	_refresh_buy_buttons()
	_update_info()
	_update_start()
	_update_wave_info()

func _process(_delta: float) -> void:
	if _new_game_armed and Time.get_ticks_msec() - _new_game_armed_ms > 3000:
		_disarm_new_game()
	if _toast_label != null and _toast_label.visible \
			and Time.get_ticks_msec() > _toast_until_ms:
		_toast_label.visible = false
	# The upgrade/sell popup auto-closes after 5s if left untouched.
	if _popup != null and _popup.visible \
			and Time.get_ticks_msec() - _popup_shown_ms > 5000:
		dismiss_popup()
	if wave_manager != null and wave_manager.countdown_remaining() >= 0.0:
		_update_start()

## Keyboard shortcuts: Space pauses, Enter sends the next wave, +/- adjust
## speed, Esc opens / closes the options menu.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_on_pause_pressed()
		KEY_ENTER, KEY_KP_ENTER:
			if not GameState.game_over:
				_on_start_pressed()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			# "+" speeds up - same as left-clicking the speed button.
			_step_speed(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_step_speed(-1)
		KEY_Z:
			_on_undo_pressed()
		KEY_ESCAPE:
			# Esc closes the topmost popup, else toggles options.
			if _help_root != null and _help_root.visible:
				_help_root.visible = false
			elif _stats_root != null and _stats_root.visible:
				_stats_root.visible = false
			else:
				_set_options_visible(not _options_root.visible)

func _step_speed(delta: int) -> void:
	_speed_idx = clampi(_speed_idx + delta, 0, SPEEDS.size() - 1)
	Engine.time_scale = SPEEDS[_speed_idx]
	_speed_button.text = _speed_label()

## A right-click anywhere closes an open options menu or popup and returns to normal.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT):
		return
	if _help_root != null and _help_root.visible:
		_help_root.visible = false
		get_viewport().set_input_as_handled()
	elif _stats_root != null and _stats_root.visible:
		_stats_root.visible = false
		get_viewport().set_input_as_handled()
	elif _options_root != null and _options_root.visible:
		_set_options_visible(false)
		get_viewport().set_input_as_handled()
	elif _popup != null and _popup.visible:
		dismiss_popup()
		get_viewport().set_input_as_handled()

## "New Game" restarts the run; first press arms, second press confirms.
func _on_new_game_pressed() -> void:
	if _new_game_armed:
		get_tree().reload_current_scene()
		return
	_new_game_armed = true
	_new_game_armed_ms = Time.get_ticks_msec()
	_newgame_button.text = "Confirm New Game"
	_newgame_button.add_theme_color_override("font_color", Color(0.95, 0.5, 0.45))

func _disarm_new_game() -> void:
	_new_game_armed = false
	_newgame_button.text = "New Game"
	_newgame_button.remove_theme_color_override("font_color")

## Restore every option to its default and sync the toggles to match.
func _on_reset_options_pressed() -> void:
	GameState.map_type = "none"
	GameState.bonus_lives_per_wave = true
	GameState.unlimited_money = false
	GameState.free_walls = false
	GameState.drag_draw_walls = true
	GameState.round_timer_bonus = true
	GameState.unlimited_lives = false
	GameState.board_size = 0
	_map_select.select(0)
	_hard_toggle.set_pressed_no_signal(false)
	_timer_toggle.set_pressed_no_signal(true)
	_money_toggle.set_pressed_no_signal(false)
	_walls_toggle.set_pressed_no_signal(false)
	_lives_toggle.set_pressed_no_signal(false)
	_drag_toggle.set_pressed_no_signal(true)
	_board_button.text = "Board size:  " + _board_name()
	GameState.save_settings()
	_refresh_stats()
	_refresh_buy_buttons()
	_update_start()

## Transient status text shown at top-center for feedback messages.
func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.position = Vector2(0, 14)
	_toast_label.size = Vector2(1280, 22)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 14)
	_toast_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.55))
	_toast_label.visible = false
	add_child(_toast_label)

func show_toast(text: String, seconds: float = 2.5) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.visible = true
	_toast_until_ms = Time.get_ticks_msec() + int(seconds * 1000)

func _build_bar() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, BAR_Y)
	bar.size = Vector2(1280, 120)
	add_child(bar)

	_gold_label = _make_label(Vector2(12, 4), 14)
	_lives_label = _make_label(Vector2(12, 26), 14)
	_wave_label = _make_label(Vector2(12, 48), 14)
	_score_label = _make_label(Vector2(12, 70), 14)
	bar.add_child(_gold_label)
	bar.add_child(_lives_label)
	bar.add_child(_wave_label)
	bar.add_child(_score_label)

	# Row 1: the 8 towers. Row 2: wall + the 5 traps. Buttons are narrow with
	# two-line labels (name / cost) so all 8 fit before the info panel at x=624.
	var bx := 150
	var by := 8
	for idx in BUY_TYPES.size():
		var t: String = BUY_TYPES[idx]
		if idx == 8:
			bx = 150
			by = 56
		var b := _make_button("", Vector2(bx, by), Vector2(56, 44), 10)
		b.toggle_mode = true
		b.toggled.connect(_on_buy_toggled.bind(t))
		b.mouse_entered.connect(_on_buy_hovered.bind(t))
		b.mouse_exited.connect(_on_buy_unhovered.bind(t))
		# Colored underline strip showing the piece's in-game color.
		var strip := ColorRect.new()
		strip.color = PieceData.TYPES[t]["color"]
		strip.position = Vector2(4, 39)
		strip.size = Vector2(48, 3)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.modulate = Color(0.714, 0.714, 0.714)
		b.add_child(strip)
		bar.add_child(b)
		_buy_buttons[t] = b
		bx += 58

	_info_label = _make_label(Vector2(624, 3), 10)
	# Tight line spacing so up to 3 lines fit above the divider.
	_info_label.add_theme_constant_override("line_spacing", 0)
	bar.add_child(_info_label)

	# Divider between the selected-piece info (top, up to 3 lines) and wave info.
	var divider := ColorRect.new()
	divider.color = Color(0.45, 0.50, 0.62, 0.55)
	divider.position = Vector2(620, 48)
	divider.size = Vector2(388, 2)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(divider)

	_wave_info_label = _make_label(Vector2(624, 51), 10)
	_wave_info_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))
	bar.add_child(_wave_info_label)

	_enemy_legend = EnemyLegend.new()
	_enemy_legend.position = Vector2(624, 65)
	_enemy_legend.size = Vector2(384, 53)
	_enemy_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_enemy_legend)

	_options_button = _make_button("Options", Vector2(10, 94), Vector2(64, 22), 10)
	_options_button.pressed.connect(_on_options_pressed)
	bar.add_child(_options_button)

	_start_button = _make_button("Start Wave", Vector2(1070, 6), Vector2(202, 42), 15)
	_start_button.pressed.connect(_on_start_pressed)
	bar.add_child(_start_button)

	# Auto / Pause stack vertically on the left; Speed sits beside them.
	_auto_button = _make_button("Auto: On", Vector2(1070, 62), Vector2(98, 26), 11)
	_auto_button.pressed.connect(_on_auto_pressed)
	bar.add_child(_auto_button)

	_pause_button = _make_button("Pause", Vector2(1070, 90), Vector2(98, 26), 11)
	_pause_button.pressed.connect(_on_pause_pressed)
	bar.add_child(_pause_button)

	_undo_button = _make_button("Undo (Z)", Vector2(80, 94), Vector2(64, 22), 10)
	_undo_button.pressed.connect(_on_undo_pressed)
	bar.add_child(_undo_button)

	_speed_button = _make_button(_speed_label(), Vector2(1174, 62), Vector2(98, 26), 11)
	_speed_button.tooltip_text = "Left-click: faster   Right-click: slower"
	_speed_button.gui_input.connect(_on_speed_input)
	bar.add_child(_speed_button)

func _build_popup() -> void:
	# Purely visual: clicks are detected by Level via popup_hit() so the
	# popup works reliably regardless of CanvasLayer input quirks.
	_popup = Button.new()
	_popup.add_theme_font_size_override("font_size", 10)
	# Brighter disabled text so "can't afford" still reads clearly.
	_popup.add_theme_color_override("font_disabled_color", Color(0.78, 0.78, 0.82))
	# Replace every state's stylebox so the built-in chunky padding goes away;
	# the popup will then auto-size to whatever text we feed it.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.18, 0.22, 0.95)
		if state == "hover":
			sb.bg_color = Color(0.22, 0.25, 0.32, 0.98)
		elif state == "pressed":
			sb.bg_color = Color(0.10, 0.12, 0.16, 0.98)
		elif state == "disabled":
			sb.bg_color = Color(0.12, 0.13, 0.16, 0.92)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.40, 0.46, 0.60, 0.85)
		sb.corner_radius_top_left = 3
		sb.corner_radius_top_right = 3
		sb.corner_radius_bottom_left = 3
		sb.corner_radius_bottom_right = 3
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		_popup.add_theme_stylebox_override(state, sb)
	_popup.visible = false
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popup)

func _build_options() -> void:
	_options_root = ColorRect.new()
	_options_root.color = Color(0, 0, 0, 0.6)
	_options_root.size = Vector2(1280, 720)
	_options_root.visible = false
	add_child(_options_root)

	var panel := _make_panel(Vector2(410, 4), Vector2(460, 714))
	_options_root.add_child(panel)

	var app_name := Label.new()
	app_name.text = "2026 - %s by IronWolve" % APP_NAME
	app_name.position = Vector2(0, 4)
	app_name.size = Vector2(460, 18)
	app_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	app_name.add_theme_font_size_override("font_size", 11)
	app_name.add_theme_color_override("font_color", Color(0.62, 0.66, 0.82))
	panel.add_child(app_name)

	var ver_label := Label.new()
	ver_label.text = "Ver. %s" % APP_VERSION
	ver_label.position = Vector2(8, 4)
	ver_label.add_theme_font_size_override("font_size", 11)
	ver_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.82))
	panel.add_child(ver_label)

	var title := Label.new()
	title.text = "Options"
	title.position = Vector2(0, 22)
	title.size = Vector2(460, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	panel.add_child(title)

	var help_btn := _make_button("Help  /  How to Play", Vector2(110, 58), Vector2(240, 42), 17)
	help_btn.pressed.connect(_on_help_pressed)
	panel.add_child(help_btn)

	_board_button = _make_button("Board size:  " + _board_name(),
		Vector2(110, 112), Vector2(240, 42), 16)
	_board_button.pressed.connect(_on_board_pressed)
	panel.add_child(_board_button)

	# New Game restarts the run; Reset Options restores every toggle to default.
	_newgame_button = _make_button("New Game", Vector2(20, 166), Vector2(200, 42), 16)
	_newgame_button.pressed.connect(_on_new_game_pressed)
	panel.add_child(_newgame_button)

	var reset_btn := _make_button("Reset Options", Vector2(240, 166), Vector2(200, 42), 16)
	reset_btn.pressed.connect(_on_reset_options_pressed)
	panel.add_child(reset_btn)

	# Group 1: only takes effect when a new game starts.
	panel.add_child(_make_section("NEW GAME   (applies on New Game)", Vector2(32, 230)))
	_map_select = OptionButton.new()
	_map_select.position = Vector2(30, 252)
	_map_select.size = Vector2(400, 36)
	_map_select.add_theme_font_size_override("font_size", 16)
	_map_select.item_selected.connect(_on_map_selected)
	panel.add_child(_map_select)
	_refresh_map_select()

	# Save-current-map UI: type a name, press Save. Writes user://maps/<name>.txt.
	_map_name_input = LineEdit.new()
	_map_name_input.position = Vector2(30, 294)
	_map_name_input.size = Vector2(180, 30)
	_map_name_input.placeholder_text = "name..."
	_map_name_input.add_theme_font_size_override("font_size", 14)
	panel.add_child(_map_name_input)
	_save_map_button = _make_button("Save", Vector2(220, 294), Vector2(80, 30), 14)
	_save_map_button.pressed.connect(_on_save_map_pressed)
	panel.add_child(_save_map_button)
	# Open the user-saved maps folder in the OS file manager. Hidden on web
	# since the browser sandbox has no usable OS file path.
	var open_folder := _make_button("Maps Folder", Vector2(310, 294), Vector2(120, 30), 14)
	open_folder.pressed.connect(_on_open_maps_folder_pressed)
	if OS.has_feature("web"):
		open_folder.visible = false
	panel.add_child(open_folder)

	# Group 2: modifiers that can be toggled at any time.
	panel.add_child(_make_section("MODIFIERS", Vector2(32, 336)))
	_hard_toggle = _make_toggle("Hard mode   (no bonus lives, less gold)", Vector2(30, 358),
		not GameState.bonus_lives_per_wave, _on_hard_option_toggled)
	panel.add_child(_hard_toggle)
	_lives_toggle = _make_toggle("Unlimited lives", Vector2(30, 402),
		GameState.unlimited_lives, _on_lives_toggled)
	panel.add_child(_lives_toggle)
	_money_toggle = _make_toggle("Unlimited money", Vector2(30, 446),
		GameState.unlimited_money, _on_money_option_toggled)
	panel.add_child(_money_toggle)
	_walls_toggle = _make_toggle("No-cost walls", Vector2(30, 490),
		GameState.free_walls, _on_walls_option_toggled)
	panel.add_child(_walls_toggle)
	# Default-on options last.
	_timer_toggle = _make_toggle("30s round timer (send early for gold)", Vector2(30, 534),
		GameState.round_timer_bonus, _on_round_timer_toggled)
	panel.add_child(_timer_toggle)
	_drag_toggle = _make_toggle("Hold-drag to add / remove walls", Vector2(30, 578),
		GameState.drag_draw_walls, _on_drag_option_toggled)
	panel.add_child(_drag_toggle)

	var stats_btn := _make_button("Stats", Vector2(15, 638), Vector2(140, 46), 16)
	stats_btn.pressed.connect(_on_stats_pressed)
	panel.add_child(stats_btn)
	var close := _make_button("Close", Vector2(305, 638), Vector2(140, 46), 18)
	close.pressed.connect(_on_options_pressed)
	panel.add_child(close)

func _build_help() -> void:
	_help_root = ColorRect.new()
	_help_root.color = Color(0, 0, 0, 0.88)
	_help_root.size = Vector2(1280, 720)
	_help_root.visible = false
	add_child(_help_root)

	var panel := _make_panel(Vector2(230, 64), Vector2(820, 592))
	_help_root.add_child(panel)

	var title := Label.new()
	title.text = "How to Play"
	title.position = Vector2(32, 16)
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	# HELP_TEXT stores "->"; swap to the platform arrow (real "→" on desktop).
	body.text = HELP_TEXT.replace("->", _arrow())
	body.position = Vector2(32, 56)
	body.size = Vector2(756, 456)
	body.add_theme_font_size_override("normal_font_size", 14)
	panel.add_child(body)

	var close := _make_button("Close", Vector2(335, 524), Vector2(150, 46), 18)
	close.pressed.connect(_on_help_pressed)
	panel.add_child(close)

## The Stats overlay: lifetime stats with a Reset button at the bottom.
func _build_stats() -> void:
	_stats_root = ColorRect.new()
	_stats_root.color = Color(0, 0, 0, 0.88)
	_stats_root.size = Vector2(1280, 720)
	_stats_root.visible = false
	add_child(_stats_root)

	var panel := _make_panel(Vector2(330, 90), Vector2(620, 540))
	_stats_root.add_child(panel)

	var title := Label.new()
	title.text = "Lifetime Stats"
	title.position = Vector2(32, 18)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Lifetime records and totals, plus your current run's settings."
	subtitle.position = Vector2(32, 58)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.60, 0.64, 0.82))
	panel.add_child(subtitle)

	_stats_body = RichTextLabel.new()
	_stats_body.bbcode_enabled = true
	_stats_body.fit_content = false
	_stats_body.scroll_active = false
	_stats_body.position = Vector2(32, 96)
	_stats_body.size = Vector2(272, 360)
	_stats_body.add_theme_font_size_override("normal_font_size", 15)
	panel.add_child(_stats_body)

	# Second column: current run modifiers / settings.
	_stats_body2 = RichTextLabel.new()
	_stats_body2.bbcode_enabled = true
	_stats_body2.fit_content = false
	_stats_body2.scroll_active = false
	_stats_body2.position = Vector2(316, 96)
	_stats_body2.size = Vector2(272, 360)
	_stats_body2.add_theme_font_size_override("normal_font_size", 15)
	panel.add_child(_stats_body2)

	var reset_btn := _make_button("Reset All Stats", Vector2(40, 472), Vector2(200, 46), 15)
	reset_btn.pressed.connect(_on_reset_stats_pressed)
	panel.add_child(reset_btn)
	var close := _make_button("Close", Vector2(390, 472), Vector2(190, 46), 18)
	close.pressed.connect(_on_stats_pressed)
	panel.add_child(close)

func _on_stats_pressed() -> void:
	var v := not _stats_root.visible
	_stats_root.visible = v
	if v:
		_refresh_stats_page()

## Two-column rich-text table with a heading row per group.
func _refresh_stats_page() -> void:
	if _stats_body == null:
		return
	var rows: Array = [
		{"head": "Records"},
		{"k": "Best wave",         "v": str(GameState.best_wave)},
		{"k": "Best score",        "v": _fmt_int(GameState.best_score)},
		{"k": "Highest tower lvl", "v": str(GameState.best_tower_level)},
		{"head": "Totals"},
		{"k": "Enemies killed",    "v": _fmt_int(GameState.total_kills)},
		{"k": "Games played",      "v": str(GameState.total_games)},
		{"k": "Time played",       "v": _fmt_play_time(GameState.total_play_seconds)},
		{"head": "Dates"},
		{"k": "First played",      "v": _fmt_date(GameState.first_played_unix)},
		{"k": "Last played",       "v": _fmt_date(GameState.last_played_unix)},
	]
	_stats_body.text = _stats_rows_to_bbcode(rows)
	# Second column: current modifiers / settings for this run.
	var on := func(b: bool) -> String: return "[color=#8cff8c]On[/color]" if b \
		else "[color=#9aa0b4]Off[/color]"
	var srows: Array = [
		{"head": "Difficulty"},
		{"k": "Mode", "v": ("[color=#ff9a7a]Hard[/color]" if not GameState.bonus_lives_per_wave
			else "[color=#8cff8c]Normal[/color]")},
		{"head": "World"},
		{"k": "Map",   "v": _map_display_name(GameState.map_type)},
		{"k": "Board", "v": _board_name()},
		{"head": "Modifiers"},
		{"k": "Round timer",    "v": on.call(GameState.round_timer_bonus)},
		{"k": "Drag-draw walls","v": on.call(GameState.drag_draw_walls)},
		{"k": "No-cost walls",  "v": on.call(GameState.free_walls)},
		{"k": "Unlimited money","v": on.call(GameState.unlimited_money)},
		{"k": "Unlimited lives","v": on.call(GameState.unlimited_lives)},
	]
	_stats_body2.text = _stats_rows_to_bbcode(srows)

## Format a Records/Totals-style row list as BBCode (headings + key/value).
func _stats_rows_to_bbcode(rows: Array) -> String:
	var lines: Array[String] = []
	for r in rows:
		if r.has("head"):
			lines.append("[color=#7ee1c8][b]%s[/b][/color]" % r["head"])
		else:
			lines.append("  [color=#c9cde7]%s[/color]   [color=#ffd884][b]%s[/b][/color]" %
				[r["k"], r["v"]])
	return "\n".join(lines)

## Friendly name for the stored map_type key.
func _map_display_name(key: String) -> String:
	match key:
		"none": return "Open field"
		"spiral": return "Spiral"
		"generate": return "Generated"
		_:
			if key.begins_with("custom:"):
				return key.substr(7)
			return key

func _fmt_int(n: int) -> String:
	# 12345 -> "12,345"
	var s := str(n)
	var neg := s.begins_with("-")
	if neg:
		s = s.substr(1)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if neg else out

func _fmt_play_time(secs: float) -> String:
	var t := int(secs)
	var h := t / 3600
	var m := (t / 60) % 60
	var s := t % 60
	if h > 0:
		return "%dh %dm %ds" % [h, m, s]
	if m > 0:
		return "%dm %ds" % [m, s]
	return "%ds" % s

func _fmt_date(unix: int) -> String:
	if unix <= 0:
		return "-"
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute]

## A small dim heading that visually groups the options below it.
func _make_section(text: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.60, 0.64, 0.82))
	return l

func _make_toggle(text: String, pos: Vector2, on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.position = pos
	c.size = Vector2(400, 44)
	c.alignment = HORIZONTAL_ALIGNMENT_LEFT
	c.add_theme_font_size_override("font_size", 17)
	c.button_pressed = on
	c.toggled.connect(cb)
	return c

func _on_options_pressed() -> void:
	_set_options_visible(not _options_root.visible)

## Show/hide the options menu; the game pauses while it is open.
func _set_options_visible(v: bool) -> void:
	if v == _options_root.visible:
		return
	_options_root.visible = v
	if _new_game_armed:
		_disarm_new_game()
	if v:
		_was_paused = get_tree().paused
		get_tree().paused = true
		_refresh_map_select()
	else:
		get_tree().paused = _was_paused

func _on_hard_option_toggled(pressed: bool) -> void:
	GameState.bonus_lives_per_wave = not pressed
	GameState.save_settings()

func _on_help_pressed() -> void:
	_help_root.visible = not _help_root.visible

func _on_money_option_toggled(pressed: bool) -> void:
	GameState.unlimited_money = pressed
	GameState.save_settings()
	_refresh_stats()
	_refresh_buy_buttons()

func _on_walls_option_toggled(pressed: bool) -> void:
	GameState.free_walls = pressed
	GameState.save_settings()
	_refresh_buy_buttons()

func _on_drag_option_toggled(pressed: bool) -> void:
	GameState.drag_draw_walls = pressed
	GameState.save_settings()

func _on_round_timer_toggled(pressed: bool) -> void:
	GameState.round_timer_bonus = pressed
	GameState.save_settings()
	_update_start()

func _on_lives_toggled(pressed: bool) -> void:
	GameState.unlimited_lives = pressed
	GameState.save_settings()
	_refresh_stats()

func _board_name() -> String:
	var dim: Vector2i = Level.BOARD_SIZES[GameState.board_size]
	# Width x Height.
	return "%s  %dx%d" % [["Normal", "Large", "Huge"][GameState.board_size],
		dim.x, dim.y]

func _on_board_pressed() -> void:
	GameState.board_size = (GameState.board_size + 1) % 3
	GameState.save_settings()
	_board_button.text = "Board size:  " + _board_name()

func _on_map_selected(idx: int) -> void:
	GameState.map_type = _map_type_for(idx)
	GameState.save_settings()

## Rebuilds the map dropdown so it includes built-in maps plus every saved
## custom map. Called on options-open and after a save.
func _refresh_map_select() -> void:
	if _map_select == null:
		return
	_map_select.clear()
	_map_select.add_item("Map:  Open field")  # 0 -> "none"
	_map_select.add_item("Map:  Spiral")      # 1 -> "spiral"
	_map_select.add_item("Map:  Generated")   # 2 -> "generate"
	_custom_map_names = GameState.list_custom_maps()
	for name in _custom_map_names:
		_map_select.add_item("Map:  Custom - " + name)
	_map_select.select(_map_index_for(GameState.map_type))

func _map_index_for(t: String) -> int:
	match t:
		"spiral": return 1
		"generate": return 2
		_:
			if t.begins_with("custom:"):
				var name := t.substr(7)
				var k := _custom_map_names.find(name)
				if k >= 0:
					return 3 + k
			return 0

func _map_type_for(idx: int) -> String:
	match idx:
		1: return "spiral"
		2: return "generate"
		_:
			if idx >= 3 and idx - 3 < _custom_map_names.size():
				return "custom:" + _custom_map_names[idx - 3]
			return "none"

## Clears every lifetime stat back to zero and refreshes both the dashboard
## numbers and the open Stats page.
func _on_reset_stats_pressed() -> void:
	GameState.reset_best()
	_refresh_stats()
	_refresh_stats_page()
	show_toast("Stats cleared")

func _on_open_maps_folder_pressed() -> void:
	GameState._ensure_maps_dir()
	OS.shell_open(ProjectSettings.globalize_path(GameState.MAPS_DIR))

## Dumps the current Level's wall grid to a saved file, then refreshes the
## map dropdown so the new file is selectable.
func _on_save_map_pressed() -> void:
	if level == null:
		return
	var name: String = _map_name_input.text.strip_edges()
	if name == "":
		name = "unnamed"
	# Drop characters that wouldn't make a safe filename.
	var clean := ""
	for ch in name:
		if ch == "/" or ch == "\\" or ch == ":" or ch == "*" or ch == "?" \
				or ch == "\"" or ch == "<" or ch == ">" or ch == "|":
			continue
		clean += ch
	if clean == "":
		clean = "unnamed"
	var grid: Array = level.dump_walls_grid()
	if GameState.save_map(clean, grid):
		_map_name_input.text = ""
		_refresh_map_select()
		var where := "browser storage" if OS.has_feature("web") else "Maps Folder"
		show_toast("Map \"%s\" saved to %s" % [clean, where])
	else:
		show_toast("Save failed")

func _make_label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	return l

func _make_button(text: String, pos: Vector2, size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.modulate = Color(1.4, 1.4, 1.4)
	b.add_theme_font_size_override("font_size", font_size)
	# Don't let buttons hold keyboard focus - Esc / Enter / Space were silently
	# activating whichever button auto-focused when an overlay opened.
	b.focus_mode = Control.FOCUS_NONE
	return b

## A dark menu panel so the lighter buttons stand out clearly.
func _make_panel(pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10)
	sb.border_color = Color(0.52, 0.52, 0.64)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _connect_events() -> void:
	Events.gold_changed.connect(func(_v): _refresh_stats(); _refresh_buy_buttons(); _refresh_popup())
	Events.lives_changed.connect(func(_v): _refresh_stats())
	Events.wave_changed.connect(func(_v): _refresh_stats(); _update_start(); _update_wave_info())
	Events.stock_changed.connect(_refresh_buy_buttons)
	Events.path_changed.connect(func(_v): _update_start(); _update_wave_info())
	Events.game_over.connect(func(): dismiss_popup(); _update_start())

func _refresh_stats() -> void:
	_gold_label.text = "Gold:  unlimited" if GameState.unlimited_money else "Gold:  %d" % GameState.gold
	_lives_label.text = "Lives:  unlimited" if GameState.unlimited_lives \
		else "Lives:  %d" % GameState.lives
	_wave_label.text = "Wave:  %d" % GameState.wave
	_score_label.text = "Score:  %d" % GameState.score

func _refresh_buy_buttons() -> void:
	for t in BUY_TYPES:
		var d: Dictionary = PieceData.TYPES[t]
		var key: String = d["stock_key"]
		# Two lines: name on top, cost / stock below.
		if t == "wall" and GameState.free_walls:
			_buy_buttons[t].text = "Wall\nfree"
		elif key != "" and GameState.stock_of(key) > 0:
			_buy_buttons[t].text = "%s\nx%d" % [d["short"], GameState.stock_of(key)]
		else:
			_buy_buttons[t].text = "%s\n$%d" % [d["short"], d["cost"]]

## Two-or-three line info for a placed piece: name, stats, and (if a damage
## tower is being amplified) an enhancement line.
func _structure_info_text(s: Structure) -> String:
	var txt := "%s\n%s" % [s.display_name(), s.info_text()]
	if s is Tower:
		var enh: String = (s as Tower).enhancement_text()
		if enh != "":
			txt += "\n" + enh
	return txt

func _update_info() -> void:
	if _hovered_structure != null and is_instance_valid(_hovered_structure):
		_info_label.text = _structure_info_text(_hovered_structure)
	elif _hovered_buy_type != "":
		_info_label.text = _type_info(_hovered_buy_type)
	elif selected_type != "":
		_info_label.text = _type_info(selected_type)
	else:
		_info_label.text = ""

func _on_buy_hovered(t: String) -> void:
	_hovered_buy_type = t
	_update_info()

func _on_buy_unhovered(t: String) -> void:
	if _hovered_buy_type == t:
		_hovered_buy_type = ""
		_update_info()

## Force the info panel to a placed piece's current name and stats.
func _show_structure_info(s: Structure) -> void:
	if s != null and is_instance_valid(s):
		_info_label.text = _structure_info_text(s)

func _update_wave_info() -> void:
	if wave_manager == null:
		return
	var n := wave_manager.waves_started() + 1
	var d := wave_manager.next_wave_def()
	var style: String = d.get("style_name", "")
	var bosses: int = d.get("boss_count", 0)
	var turtles: int = d.get("turtle_count", 0)
	var total_bosses := bosses + turtles
	var tag := "Wave %d - %s" % [n, style]
	if total_bosses > 0:
		tag = "Wave %d - %s + %d BOSS" % [n, style, total_bosses]
	var total := int(d.get("total_reward", 0))
	# With Gold Mines on the board, also show the gold-enhanced total.
	var bonus := level.gold_bonus() if level != null else 0.0
	var gold_str := "$%d total" % total
	if bonus > 0.0:
		gold_str = "Wave $%d / Enhanced $%d" % [total, int(round(total * (1.0 + bonus)))]
	_wave_info_label.text = "Next - %s:   %d HP   %d enemies   %s" % [
		tag, int(d["hp"]), int(d["count"]), gold_str]
	var ents := []
	for t in WaveManager.ENEMY_TYPES:
		ents.append({"shape": t["shape"], "color": t["color"],
			"label": "%s (%s)" % [t["name"], t["desc"]]})
	if bosses > 0:
		ents.append({"shape": "beetle", "color": WaveManager.BEETLE_COLOR,
			"label": "Boss x%d" % bosses})
	if turtles > 0:
		ents.append({"shape": "turtle", "color": WaveManager.TURTLE_COLOR,
			"label": "Turtle x%d (tanky)" % turtles})
	_enemy_legend.set_entries(ents)

## Called by Level with the piece under the cursor (or null) for the info panel.
func set_hovered_structure(s: Structure) -> void:
	if s == _hovered_structure:
		return
	_hovered_structure = s
	_update_info()

func _type_info(t: String) -> String:
	var d: Dictionary = PieceData.TYPES[t]
	var line2 := ""
	match d["category"]:
		"wall":
			line2 = "Blocks enemies - shape the maze."
		"tower":
			var pct := PieceData.SUPPORT_PCT_PER_LEVEL * 100.0
			if d["mode"] == "support":
				if t == "gold":
					line2 = "+%.1f%%/level gold from kills (all stack)" % pct
				else:
					line2 = "+%.1f%%/level damage to the 8 towers touching it" % pct
			elif d["mode"] == "beam":
				line2 = "continuous beam   %d dmg/s   range %d" % [
					int(d["damage"]), int(d["range"])]
			elif d["mode"] == "slow":
				line2 = "AOE slow   %d%% for %.1fs   range %d" % [
					int(d["slow"] * 100.0), d["slow_time"], int(d["range"])]
			else:
				line2 = "range %d   dmg %d   %.1f/s" % [
					int(d["range"]), int(d["damage"]), d["fire_rate"]]
				if d["aoe_radius"] > 0.0:
					line2 += "   AOE %d" % int(d["aoe_radius"])
				if d["slow"] > 0.0:
					line2 += "   slow %d%%" % int(d["slow"] * 100.0)
		_:
			if d["slow"] > 0.0:
				line2 = "slows %d%%   %d dmg/s   enemies walk over it" % [
					int(d["slow"] * 100.0), int(d["damage"])]
			else:
				line2 = "%d dmg/s   enemies walk over it" % int(d["damage"])
	return "%s  -  $%d\n%s" % [d["name"], d["cost"], line2]

func _update_start() -> void:
	if wave_manager == null or level == null:
		return
	if GameState.game_over:
		_start_button.disabled = true
		return
	if not level.has_path():
		_start_button.text = "Path Blocked!"
		_start_button.disabled = true
		return
	var n := wave_manager.waves_started() + 1
	var label := ("Send BOSS Wave %d" if wave_manager.next_is_boss() else "Send Wave %d") % n
	var cd := wave_manager.countdown_remaining()
	if cd >= 0.0:
		var b := wave_manager.send_bonus()
		if b > 0:
			label += "\n(auto in %ds,  +%dg)" % [ceili(cd), b]
		else:
			label += "\n(auto in %ds)" % ceili(cd)
	_start_button.text = label
	_start_button.disabled = false

func _on_buy_toggled(pressed: bool, type: String) -> void:
	if pressed:
		selected_type = type
	elif selected_type == type:
		selected_type = ""
	_sync_buy_buttons()
	_update_info()
	Events.piece_selected.emit(selected_type)

func _sync_buy_buttons() -> void:
	for t in _buy_buttons:
		_buy_buttons[t].set_pressed_no_signal(t == selected_type)

func clear_selection() -> void:
	if selected_type == "":
		return
	selected_type = ""
	_sync_buy_buttons()
	_update_info()
	Events.piece_selected.emit("")

## Left-click steps speed up, right-click steps it down (clamped at the ends).
func _on_speed_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_speed_idx = mini(_speed_idx + 1, SPEEDS.size() - 1)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_speed_idx = maxi(_speed_idx - 1, 0)
	else:
		return
	Engine.time_scale = SPEEDS[_speed_idx]
	_speed_button.text = _speed_label()

func _speed_text(s: float) -> String:
	if s < 1.0:
		return "Speed 1/%dx" % int(round(1.0 / s))
	return "Speed %dx" % int(s)

## Compact speed-button caption (the L/R click hint lives in the tooltip).
func _speed_label() -> String:
	return _speed_text(SPEEDS[_speed_idx])

func _on_auto_pressed() -> void:
	if wave_manager == null:
		return
	wave_manager.auto_advance = not wave_manager.auto_advance
	_auto_button.text = "Auto: On" if wave_manager.auto_advance else "Auto: Off"
	_update_start()

# --- floating upgrade/sell popup ---
func show_popup(s: Structure, action: String) -> void:
	_popup_target = s
	_popup_action = action
	_popup.visible = true
	_popup_shown_ms = Time.get_ticks_msec()
	_show_structure_info(s)
	_refresh_popup()
	_reposition_popup()

func dismiss_popup() -> bool:
	if _popup == null or not _popup.visible:
		return false
	_popup.visible = false
	_popup_target = null
	return true

func _refresh_popup() -> void:
	if _popup == null or not _popup.visible:
		return
	var s := _popup_target
	if s == null or not is_instance_valid(s):
		dismiss_popup()
		return
	if _popup_action == "upgrade":
		var c: int = s.upgrade_cost()
		_popup.text = "Upgrade $%d\n%s" % [c, _dps_delta_text(s)]
		var affordable := GameState.can_afford(c)
		_popup.disabled = not affordable
		# Green when you can buy it; default near-white otherwise (disabled
		# state has its own color override set in _build_popup).
		_popup.add_theme_color_override("font_color",
			Color(0.55, 1.0, 0.55) if affordable else Color(0.92, 0.94, 0.98))
		_popup.add_theme_color_override("font_hover_color",
			Color(0.70, 1.0, 0.70) if affordable else Color(1.0, 1.0, 1.0))
	else:
		if s.gold_invested > 0:
			_popup.text = "Sell\n+$%d" % s.sell_refund()
		else:
			_popup.text = "Sell\n(return)"
		_popup.disabled = false
		_popup.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
		_popup.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	# Shrink-fit to the current text and keep the popup anchored above the piece.
	_popup.custom_minimum_size = Vector2.ZERO
	_popup.size = Vector2.ZERO
	_popup.reset_size()
	_reposition_popup()

func _reposition_popup() -> void:
	if _popup_target == null or not is_instance_valid(_popup_target):
		return
	var s := _popup_target
	# Sit just above the structure; offset trimmed 25% so it hugs the turret tighter.
	var p := s.global_position + Vector2(-_popup.size.x / 2.0, -(18.0 + 4.0 + _popup.size.y) * 0.75)
	p.x = clampf(p.x, 4.0, 1280.0 - _popup.size.x - 4.0)
	p.y = maxf(p.y, 4.0)
	_popup.position = p

## Second line of the upgrade popup: DPS now -> DPS after upgrade.
## For beams and DoT traps damage is already a per-second value; for everything
## else we multiply by fire_rate (or eruption rate for volcano).
## The arrow glyph for "before -> after" text. Delegates to GameState.arrow()
## so desktop gets the real "→" and web gets ASCII "->" (its font lacks the arrow).
func _arrow() -> String:
	return GameState.arrow()

func _dps_delta_text(s: Structure) -> String:
	var now := _dps_at(s, s.level)
	var nxt := _dps_at(s, s.level + 1)
	if now <= 0.0 and nxt <= 0.0:
		return ""
	return "DPS %d %s %d" % [int(round(now)), _arrow(), int(round(nxt))]

func _dps_at(s: Structure, level: int) -> float:
	var cat: String = PieceData.category(s.type)
	if cat == "tower":
		var st: Dictionary = PieceData.tower_stats(s.type, level)
		var mode: String = PieceData.TYPES[s.type]["mode"]
		if mode == "beam":
			return st["damage"]
		return st["damage"] * st["fire_rate"]
	if cat == "trap":
		var st2: Dictionary = PieceData.trap_stats(s.type, level)
		if s.type == "volcano_trap":
			return st2["damage"] / 0.8  # Trap.ERUPT_PERIOD
		return st2["damage"]
	return 0.0

## True if `pos` (viewport coords) lands on the visible popup.
func popup_hit(pos: Vector2) -> bool:
	return _popup != null and _popup.visible \
		and Rect2(_popup.position, _popup.size).has_point(pos)

## Run the popup's action (called by Level when the popup is clicked).
func popup_activate() -> void:
	if level == null or _popup_target == null or not is_instance_valid(_popup_target):
		dismiss_popup()
		return
	if _popup_action == "upgrade":
		level.upgrade_selected()
		_refresh_popup()
		_popup_shown_ms = Time.get_ticks_msec()
		_show_structure_info(_popup_target)
	else:
		level.sell_selected()

func _on_start_pressed() -> void:
	if wave_manager != null:
		wave_manager.start_next_wave()
	_update_start()

func _on_pause_pressed() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_pause_button.text = "Resume" if paused else "Pause"

func _on_undo_pressed() -> void:
	if level == null:
		return
	if not level.undo():
		show_toast("Nothing to undo")

func show_end_screen() -> void:
	if _end_root != null:
		return
	dismiss_popup()
	_end_root = ColorRect.new()
	_end_root.color = Color(0, 0, 0, 0.80)
	_end_root.size = Vector2(1280, 720)
	add_child(_end_root)

	var center := CenterContainer.new()
	center.size = Vector2(1280, 720)
	_end_root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 26)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	vbox.add_child(title)

	var sub := Label.new()
	var sub_text := "Reached wave %d        Final score: %d" % [GameState.wave, GameState.score]
	if GameState.best_wave > 0 or GameState.best_score > 0:
		sub_text += "\nBest:  wave %d   /   score %d" % [
			GameState.best_wave, GameState.best_score]
	sub.text = sub_text
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	vbox.add_child(sub)

	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(220, 64)
	restart.add_theme_font_size_override("font_size", 26)
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(restart)
