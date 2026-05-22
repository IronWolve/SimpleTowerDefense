class_name Tower
extends Structure
## A circular tower: blocks the path AND attacks. Behaviour depends on type.
## "shot" towers fire homing bullets; "beam" towers (laser) deal continuous damage.

## Projectile look per tower type (default is a small bullet).
const BULLET_STYLE := {"cannon": "ball", "missile": "missile"}

var mode := "shot"
var range_radius := 150.0
var fire_rate := 1.7
var damage := 13.0
var color := Color.WHITE
var bullet_color := Color.WHITE
var slow := 0.0
var slow_time := 0.0
var aoe_radius := 0.0

var _cooldown := 0.0
var _beam_targets: Array = []
var _slow_targets: Array = []
var _slow_flash := 0.0

func _apply_stats() -> void:
	var s := PieceData.tower_stats(type, level)
	mode = PieceData.TYPES[type]["mode"]
	range_radius = s["range"]
	fire_rate = s["fire_rate"]
	damage = s["damage"]
	color = s["color"]
	bullet_color = s["bullet_color"]
	slow = s["slow"]
	slow_time = s["slow_time"]
	aoe_radius = s["aoe_radius"]

func can_upgrade() -> bool:
	return true

func upgrade_cost() -> int:
	return PieceData.upgrade_cost(type, level)

func do_upgrade() -> void:
	gold_invested += upgrade_cost()
	level += 1
	if level > GameState.best_tower_level:
		GameState.best_tower_level = level
	_apply_stats()
	queue_redraw()

func display_name() -> String:
	return "%s  Lv.%d" % [PieceData.TYPES[type]["name"], level]

func info_text() -> String:
	if mode == "beam":
		return "beam   %d dmg/sec   range %d   single target" % [
			int(damage), int(range_radius)]
	if mode == "slow":
		return "AOE slow %d%% for %.1fs   range %d   %.1f/s" % [
			int(slow * 100.0), slow_time, int(range_radius), fire_rate]
	var t := "range %d   dmg %d   %.1f/s" % [int(range_radius), int(damage), fire_rate]
	if aoe_radius > 0.0:
		t += "   AOE %d" % int(aoe_radius)
	if slow > 0.0:
		t += "   slow %d%%" % int(slow * 100.0)
	return t

func _process(delta: float) -> void:
	if GameState.game_over:
		return
	if mode == "beam":
		_beam_targets = _acquire_beam_targets()
		for node in _beam_targets:
			(node as Enemy).take_damage(damage * delta)
		queue_redraw()
		return
	if mode == "slow":
		_process_slow(delta)
		return
	_cooldown -= delta
	# Fire repeatedly if elapsed time allows, so high game speeds keep up.
	var shots := 0
	while _cooldown <= 0.0 and shots < 12:
		var target := _acquire_target()
		if target == null:
			_cooldown = 0.0
			break
		_fire(target)
		_cooldown += 1.0 / fire_rate
		shots += 1

## Ice tower: every interval, chill the frontmost enemies in range at once.
func _process_slow(delta: float) -> void:
	_cooldown -= delta
	var pulses := 0
	while _cooldown <= 0.0 and pulses < 12:
		var targets := _acquire_slow_targets()
		if targets.is_empty():
			_cooldown = 0.0
			break
		for node in targets:
			var e := node as Enemy
			# Ice only slows - no direct damage, no cripple (single status icon).
			e.apply_slow(slow, slow_time)
		_slow_targets = targets
		_slow_flash = 0.18
		_cooldown += 1.0 / fire_rate
		pulses += 1
	if _slow_flash > 0.0:
		_slow_flash -= delta
	queue_redraw()

## The laser beam always hits a single target, regardless of level.
func _beam_count() -> int:
	return 1

## The frontmost (closest-to-base) live enemies within range, capped at
## the laser's current beam-target count.
func _acquire_beam_targets() -> Array:
	var inrange := level_ref.enemies_near(position, range_radius)
	inrange.sort_custom(func(a, b): return a.cells_remaining() < b.cells_remaining())
	var cap := _beam_count()
	if inrange.size() > cap:
		inrange.resize(cap)
	return inrange

## Every live enemy within range - the ice tower is an AOE frost field that
## slows its whole radius on each pulse.
func _acquire_slow_targets() -> Array:
	return level_ref.enemies_near(position, range_radius)

func _acquire_target() -> Enemy:
	var best: Enemy = null
	var best_left := 1 << 30
	for node in level_ref.enemies_near(position, range_radius):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var left := e.cells_remaining()
		if left < best_left:
			best_left = left
			best = e
	return best

func _fire(target: Enemy) -> void:
	# At high game speed, skip the flying projectile and apply damage instantly.
	if GameState.reduced_gfx():
		_direct_hit(target)
		return
	var b := Bullet.new()
	b.position = position
	b.setup(target, damage, bullet_color, slow, slow_time, aoe_radius)
	b.retarget = type == "missile"
	b.style = BULLET_STYLE.get(type, "bullet")
	b.level_ref = level_ref
	level_ref.bullets.add_child(b)

## Instant version of a shot, used when graphics are reduced. Mirrors the
## bullet's on-hit behaviour (area damage + slow, or single-target).
func _direct_hit(target: Enemy) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	if aoe_radius > 0.0:
		for node in level_ref.enemies_near(target.position, aoe_radius):
			var e := node as Enemy
			if e == null or not e.is_alive():
				continue
			if target.position.distance_to(e.position) <= aoe_radius:
				e.take_damage(damage)
				if slow > 0.0:
					e.apply_slow(slow, slow_time)
	else:
		target.take_damage(damage)
		if slow > 0.0:
			target.apply_slow(slow, slow_time)

func _draw() -> void:
	if mode == "beam":
		for node in _beam_targets:
			var t := node as Enemy
			if t != null and is_instance_valid(t) and t.is_alive():
				var lp := t.position - position
				draw_line(Vector2.ZERO, lp, Color(bullet_color, 0.85), 3.0)
				draw_circle(lp, 5.0, bullet_color)
	if mode == "slow" and _slow_flash > 0.0:
		var f := _slow_flash / 0.18
		# Frost field covering the whole chilled radius.
		draw_circle(Vector2.ZERO, range_radius, Color(bullet_color, 0.12 * f))
		draw_arc(Vector2.ZERO, range_radius, 0.0, TAU, 48,
			Color(bullet_color, 0.5 * f), 2.0)
		for node in _slow_targets:
			var e := node as Enemy
			if e != null and is_instance_valid(e) and e.is_alive():
				var sp := e.position - position
				_draw_snowflake(sp, 6.5, bullet_color)
	if selected:
		draw_circle(Vector2.ZERO, range_radius, Color(1, 1, 1, 0.06))
		draw_arc(Vector2.ZERO, range_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.40), 1.5)
	draw_circle(Vector2.ZERO, 18.0, Color(0.12, 0.12, 0.15))
	draw_circle(Vector2.ZERO, 15.0, color)
	_draw_type_glyph()
	# Level badge in the lower-right corner.
	var font := ThemeDB.fallback_font
	var lt := str(level)
	var fs := 9
	draw_circle(Vector2(10.0, 10.0), 7.0, Color(0.08, 0.09, 0.12))
	var tw := font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(10.0 - tw / 2.0, 13.5), lt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))

## A small emblem on the tower disk showing its weapon type.
func _draw_type_glyph() -> void:
	var ink := Color(0.08, 0.09, 0.12)
	match type:
		"tower":  # a bullet
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -8), Vector2(3.6, -3.4), Vector2(3.6, 6.5),
				Vector2(-3.6, 6.5), Vector2(-3.6, -3.4)]), ink)
		"ice":  # a snowflake
			for i in range(3):
				var arm := Vector2.RIGHT.rotated(PI / 3.0 * i) * 8.0
				draw_line(-arm, arm, ink, 2.4)
			draw_circle(Vector2.ZERO, 2.0, ink)
		"laser":  # a lightning bolt
			draw_colored_polygon(PackedVector2Array([
				Vector2(3, -9), Vector2(-4, 1), Vector2(0.5, 1),
				Vector2(-3, 9), Vector2(5, -1.5), Vector2(0.5, -1.5)]), ink)
		"cannon":  # a cannonball
			draw_circle(Vector2(0, 1), 7.0, ink)
			draw_circle(Vector2(-2.4, -1.4), 2.2, Color(1, 1, 1, 0.4))
		"sniper":  # a crosshair
			draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 18, ink, 2.2)
			draw_line(Vector2(-9.5, 0), Vector2(9.5, 0), ink, 1.8)
			draw_line(Vector2(0, -9.5), Vector2(0, 9.5), ink, 1.8)
		"missile":  # a finned rocket
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -9), Vector2(3, -4.5), Vector2(3, 5),
				Vector2(-3, 5), Vector2(-3, -4.5)]), ink)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-3, 1), Vector2(-6.5, 6.5), Vector2(-3, 6.5)]), ink)
			draw_colored_polygon(PackedVector2Array([
				Vector2(3, 1), Vector2(6.5, 6.5), Vector2(3, 6.5)]), ink)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-2, 5), Vector2(0, 9.5), Vector2(2, 5)]),
				Color(1.0, 0.78, 0.30))

func _draw_snowflake(c: Vector2, s: float, col: Color) -> void:
	for i in range(3):
		var arm := Vector2.RIGHT.rotated(PI / 3.0 * i) * s
		draw_line(c - arm, c + arm, col, 1.6)
	draw_circle(c, 1.8, col)
