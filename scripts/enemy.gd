class_name Enemy
extends Node2D
## An enemy that navigates the grid cell-by-cell from spawn to base.

var cell := Vector2i.ZERO
var base_speed := 60.0
var speed := 60.0
var max_health := 30.0
var health := 30.0
var reward := 6
var leak_damage := 1
var radius := 11.0
var color := Color(0.90, 0.35, 0.35)
var resist := {}
var is_boss := false
var shape := "circle"
## Which boss silhouette to draw when is_boss is true: "beetle", "spider" or "turtle".
var boss_kind := "beetle"
## Rotation applied to the boss silhouette so its head points the way it moves
## (silhouettes are drawn head-up, so this is movement-angle + PI/2). 0 = up.
var _face := 0.0

var _path: Array[Vector2i] = []
var _slow_timer := 0.0
var _slow_factor := 0.0
## Active damage-over-time effects, keyed by type -> {"dps": float, "timer": float}.
## Each type (poison, fire, ...) stacks independently alongside slow.
var _dots := {}
## Vulnerability (poison): while active, all incoming damage is multiplied by
## (1 + _vuln_pct). Max-wins on both the percentage and the duration.
var _vuln_pct := 0.0
var _vuln_timer := 0.0
var _dead := false
var _level: Level

func _ready() -> void:
	add_to_group("enemies")

func setup(lvl: Level, hp: float, spd: float, rwd: int, col: Color, rad: float) -> void:
	_level = lvl
	max_health = hp
	health = hp
	base_speed = spd
	speed = spd
	reward = rwd
	color = col
	radius = rad
	cell = lvl.spawn_cell
	position = lvl.cell_center(cell)
	# Reuse the level's cached spawn->base route instead of recomputing a
	# full-board BFS per enemy (avoids frame hitches on cluster spawns).
	_path = lvl.spawn_path()
	if not _path.is_empty():
		_path.remove_at(0)

## Recompute the route when walls/towers change. Keeps the current target cell.
func repath() -> void:
	if _dead or _path.is_empty():
		return
	_path = _level.bfs_path(_path[0], _level.base_cell)

func occupies(c: Vector2i) -> bool:
	if c == cell:
		return true
	return not _path.is_empty() and _path[0] == c

func cells_remaining() -> int:
	return _path.size()

func is_alive() -> bool:
	return not _dead

func _process(delta: float) -> void:
	if _dead or GameState.game_over:
		return
	for dtype in _dots.keys():
		var d: Dictionary = _dots[dtype]
		d["timer"] -= delta
		take_damage(d["dps"] * delta, dtype)
		if _dead:
			return
		if d["timer"] <= 0.0:
			_dots.erase(dtype)
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 0.0
			speed = base_speed
		else:
			speed = base_speed * (1.0 - _slow_factor)
	if _path.is_empty():
		_reach_base()
		return
	# Face the current heading (used to rotate boss silhouettes).
	if not _path.is_empty():
		var heading := _level.cell_center(_path[0]) - position
		if heading.length_squared() > 0.01:
			_face = heading.angle() + PI / 2.0
	# Advance through as many cells as elapsed time allows (high-speed catch-up).
	var step := speed * delta
	var guard := 0
	while step > 0.0 and not _path.is_empty() and guard < 256:
		guard += 1
		var to_target := _level.cell_center(_path[0]) - position
		var d := to_target.length()
		if d <= step:
			position += to_target
			step -= d
			cell = _path[0]
			_path.remove_at(0)
			if cell == _level.base_cell:
				_reach_base()
				return
		else:
			position += to_target.normalized() * step
			step = 0.0
	# Tick the poison vulnerability window.
	if _vuln_timer > 0.0:
		_vuln_timer -= delta
		if _vuln_timer <= 0.0:
			_vuln_pct = 0.0
	queue_redraw()

func _reach_base() -> void:
	if _dead:
		return
	_dead = true
	GameState.lose_life(leak_damage)
	queue_free()

func take_damage(amount: float, dtype := "physical") -> void:
	if _dead:
		return
	health -= amount * float(resist.get(dtype, 1.0)) * (1.0 + _vuln_pct)
	if health <= 0.0:
		_die()
	else:
		queue_redraw()

## Poison vulnerability: take `pct` more damage from all sources for `duration`
## seconds. Re-applying keeps the higher pct and the longer remaining time.
func apply_vuln(pct: float, duration: float) -> void:
	if _dead:
		return
	_vuln_pct = maxf(_vuln_pct, pct)
	_vuln_timer = maxf(_vuln_timer, duration)

## A damage-over-time effect. Each type stacks independently; re-applying a
## type keeps the stronger tick and the longer remaining duration.
func apply_dot(dps: float, duration: float, dtype: String) -> void:
	if _dead:
		return
	var d: Dictionary = _dots.get(dtype, {})
	if d.is_empty():
		_dots[dtype] = {"dps": dps, "timer": duration}
	else:
		d["dps"] = maxf(d["dps"], dps)
		d["timer"] = maxf(d["timer"], duration)

## --- Save / load: capture and restore an in-flight enemy's full state. ---
func serialize() -> Dictionary:
	var path: Array = []
	for c in _path:
		path.append([c.x, c.y])
	var dots: Dictionary = {}
	for k in _dots:
		dots[k] = {"dps": _dots[k]["dps"], "timer": _dots[k]["timer"]}
	return {
		"cell": [cell.x, cell.y], "pos": [position.x, position.y],
		"base_speed": base_speed, "speed": speed,
		"max_health": max_health, "health": health,
		"reward": reward, "leak": leak_damage, "radius": radius,
		"color": [color.r, color.g, color.b, color.a], "resist": resist,
		"is_boss": is_boss, "shape": shape, "boss_kind": boss_kind, "face": _face,
		"path": path, "slow_t": _slow_timer, "slow_f": _slow_factor,
		"dots": dots, "vuln_p": _vuln_pct, "vuln_t": _vuln_timer,
	}

func restore(lvl: Level, d: Dictionary) -> void:
	_level = lvl
	var cc: Array = d.get("cell", [0, 0])
	cell = Vector2i(int(cc[0]), int(cc[1]))
	var pp: Array = d.get("pos", [0, 0])
	position = Vector2(pp[0], pp[1])
	base_speed = d.get("base_speed", 60.0)
	speed = d.get("speed", base_speed)
	max_health = d.get("max_health", 30.0)
	health = d.get("health", max_health)
	reward = int(d.get("reward", 1))
	leak_damage = int(d.get("leak", 1))
	radius = d.get("radius", 11.0)
	var col: Array = d.get("color", [0.9, 0.35, 0.35, 1.0])
	color = Color(col[0], col[1], col[2], col[3])
	resist = d.get("resist", {})
	is_boss = d.get("is_boss", false)
	shape = d.get("shape", "circle")
	boss_kind = d.get("boss_kind", "beetle")
	_face = d.get("face", 0.0)
	_path = []
	for pc in d.get("path", []):
		_path.append(Vector2i(int(pc[0]), int(pc[1])))
	_slow_timer = d.get("slow_t", 0.0)
	_slow_factor = d.get("slow_f", 0.0)
	_dots = {}
	var dts: Dictionary = d.get("dots", {})
	for k in dts:
		_dots[k] = {"dps": dts[k]["dps"], "timer": dts[k]["timer"]}
	_vuln_pct = d.get("vuln_p", 0.0)
	_vuln_timer = d.get("vuln_t", 0.0)
	queue_redraw()

func _die() -> void:
	if _dead:
		return
	_dead = true
	# Gold Mines boost kill gold (0.5%/level each, board-wide).
	var gold_award := reward
	if _level != null:
		gold_award = int(round(reward * (1.0 + _level.gold_bonus())))
	GameState.add_gold(gold_award)
	GameState.score += reward
	GameState.total_kills += 1
	queue_free()

func apply_slow(factor: float, duration: float) -> void:
	if _dead:
		return
	_slow_factor = maxf(_slow_factor, factor)
	_slow_timer = maxf(_slow_timer, duration)
	speed = base_speed * (1.0 - _slow_factor)

func _draw() -> void:
	_draw_body()
	_draw_status()
	var frac := clampf(health / max_health, 0.0, 1.0)
	# Health bar runs horizontally across the enemy at its middle.
	var bar_y := -2.0
	draw_rect(Rect2(-radius, bar_y, radius * 2.0, 4.0), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(-radius, bar_y, radius * 2.0 * frac, 4.0), Color(0.30, 0.90, 0.35))

## A distinct silhouette per archetype so types are told apart at a glance.
func _draw_body() -> void:
	var outline := Color(0, 0, 0, 0.5)
	if is_boss:
		# Rotate just the boss silhouette to face its heading, then restore the
		# default transform so the health bar and status icons stay upright.
		draw_set_transform(Vector2.ZERO, _face, Vector2.ONE)
		match boss_kind:
			"spider": _draw_spider()
			"turtle": _draw_turtle()
			_: _draw_beetle()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif shape == "triangle":
		var tri := _ngon(3, -PI / 2.0, radius * 1.18)
		draw_colored_polygon(tri, color)
		_draw_outline(tri, outline)
	elif shape == "hexagon":
		var hex := _ngon(6, PI / 6.0, radius)
		draw_colored_polygon(hex, color)
		_draw_outline(hex, outline)
	else:
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, outline, 2.0)

func _ngon(sides: int, rot: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := rot + TAU * i / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _draw_outline(pts: PackedVector2Array, col: Color) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, col, 2.0)

func _ellipse(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * i / float(segments)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A top-down beetle silhouette for boss enemies (head points up).
func _draw_beetle() -> void:
	var r := radius
	var dark := color.darkened(0.45)
	var outline := Color(0, 0, 0, 0.55)
	# Six legs - drawn first so the shell covers their roots.
	for side in [-1.0, 1.0]:
		for i in range(3):
			var ly := -r * 0.35 + i * r * 0.4
			draw_line(Vector2(side * r * 0.45, ly),
				Vector2(side * r * 1.02, ly + (i - 1) * r * 0.26), dark, 3.0)
	# Head and pincers at the front.
	draw_circle(Vector2(0, -r * 0.85), r * 0.32, dark)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * r * 0.16, -r * 0.95),
			Vector2(side * r * 0.46, -r * 1.18), dark, 3.0)
	# Domed shell with a wing seam and markings.
	var body := _ellipse(r * 0.82, r * 0.98, 22)
	draw_colored_polygon(body, color)
	_draw_outline(body, outline)
	draw_line(Vector2(0, -r * 0.5), Vector2(0, r * 0.9), dark, 2.0)
	draw_circle(Vector2(-r * 0.36, -r * 0.05), r * 0.15, dark)
	draw_circle(Vector2(r * 0.36, -r * 0.05), r * 0.15, dark)

## A top-down spider: round abdomen, smaller head, eight angled legs.
func _draw_spider() -> void:
	var r := radius
	var dark := color.darkened(0.45)
	var outline := Color(0, 0, 0, 0.55)
	# Eight legs - four per side, each a two-segment bent line.
	for side in [-1.0, 1.0]:
		for i in range(4):
			var ly := -r * 0.5 + i * r * 0.34
			var knee := Vector2(side * r * 0.85, ly - r * 0.28)
			draw_line(Vector2(side * r * 0.3, ly), knee, dark, 2.6)
			draw_line(knee, Vector2(side * r * 1.18, ly + r * 0.12), dark, 2.6)
	# Abdomen (rear) and cephalothorax (front).
	var abdomen := _ellipse(r * 0.62, r * 0.72, 20)
	for i in range(abdomen.size()):
		abdomen[i] += Vector2(0, r * 0.28)
	draw_colored_polygon(abdomen, color)
	_draw_outline(abdomen, outline)
	draw_circle(Vector2(0, -r * 0.5), r * 0.4, color)
	draw_arc(Vector2(0, -r * 0.5), r * 0.4, 0.0, TAU, 16, outline, 1.6)
	# Two eye dots on the head.
	draw_circle(Vector2(-r * 0.14, -r * 0.6), r * 0.08, dark)
	draw_circle(Vector2(r * 0.14, -r * 0.6), r * 0.08, dark)

## A top-down turtle: round domed shell with plates, a head, four stubby legs
## and a little tail. Reads as "slow & armored".
func _draw_turtle() -> void:
	var r := radius
	var dark := color.darkened(0.45)
	var light := color.lightened(0.2)
	var outline := Color(0, 0, 0, 0.55)
	# Head (front), tail (back) and four flippers poking out from under shell.
	draw_circle(Vector2(0, -r * 0.95), r * 0.26, dark)
	draw_circle(Vector2(0, r * 0.95), r * 0.16, dark)
	for s in [-1.0, 1.0]:
		for fy in [-0.55, 0.55]:
			draw_circle(Vector2(s * r * 0.82, fy * r), r * 0.2, dark)
	# Domed shell.
	draw_circle(Vector2.ZERO, r * 0.82, color)
	draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 32, outline, 2.0)
	# Central plate plus a ring of scutes.
	draw_circle(Vector2.ZERO, r * 0.3, light)
	draw_arc(Vector2.ZERO, r * 0.3, 0.0, TAU, 16, dark, 1.6)
	for i in range(6):
		var a := TAU * i / 6.0
		var c := Vector2(cos(a), sin(a)) * r * 0.55
		draw_arc(c, r * 0.18, 0.0, TAU, 10, dark, 1.4)

## A row of small badges just under the enemy, one per active status effect
## (ice / poison / fire / vuln) so the player can see at a glance.
func _draw_status() -> void:
	var kinds: Array[String] = []
	if _slow_timer > 0.0:
		kinds.append("ice")
	if _dots.has("poison"):
		kinds.append("poison")
	if _dots.has("fire"):
		kinds.append("fire")
	if _vuln_timer > 0.0:
		kinds.append("vuln")
	if kinds.is_empty():
		return
	# Wrap to 2 per row so 3-4 status effects don't crowd into a long strip.
	var spacing := 12.0
	var row_h := 12.0
	var per_row := 2
	var base_y := radius + 7.0
	for i in range(kinds.size()):
		var row := i / per_row
		var col := i % per_row
		var row_count := mini(per_row, kinds.size() - row * per_row)
		var x := -(row_count - 1) * spacing * 0.5 + col * spacing
		_draw_status_icon(Vector2(x, base_y + row * row_h), kinds[i])

func _draw_status_icon(p: Vector2, kind: String) -> void:
	draw_circle(p, 5.6, Color(0.05, 0.05, 0.06, 0.88))
	match kind:
		"ice":
			var col := Color(0.62, 0.84, 1.0)
			for i in range(3):
				var arm := Vector2.RIGHT.rotated(PI / 3.0 * i) * 3.5
				draw_line(p - arm, p + arm, col, 1.4)
		"poison":
			draw_circle(p, 3.5, Color(0.46, 0.87, 0.34))
			draw_arc(p, 3.5, 0.0, TAU, 10, Color(0.12, 0.34, 0.10), 1.2)
		"fire":
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(-3.0, 2.7), p + Vector2(3.0, 2.7), p + Vector2(0, -4.0)]),
				Color(0.98, 0.52, 0.13))
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(-1.4, 2.2), p + Vector2(1.4, 2.2), p + Vector2(0, -1.0)]),
				Color(1.0, 0.87, 0.34))
		"vuln":
			# Up-arrow: this enemy takes extra damage while poisoned.
			var vc := Color(1.0, 0.45, 0.45)
			draw_line(p + Vector2(0, 3.0), p + Vector2(0, -3.2), vc, 1.7)
			draw_line(p + Vector2(0, -3.4), p + Vector2(-2.5, -0.8), vc, 1.7)
			draw_line(p + Vector2(0, -3.4), p + Vector2(2.5, -0.8), vc, 1.7)
