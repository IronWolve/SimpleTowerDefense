class_name Enemy
extends Node2D
## An enemy that navigates the grid cell-by-cell from spawn to base.

## Shared visual style: opaque near-black outline used across every piece.
const OUTLINE := Color(0.04, 0.04, 0.05)

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
## Rotation applied to the whole body so it faces its travel direction.
## All enemy bodies are drawn forward = +X (right), so this is just the
## heading angle; Godot's draw_set_transform handles the rotation.
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
## Lagging "ghost" value used by the health-bar damage flash. After a hit it
## sits above `health` and is lerped back down over a few frames, so even
## tiny chips show up briefly as a yellow chunk to the right of the green.
var _flash_health := 0.0

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
	_flash_health = hp
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
	# Face the current heading. Bodies are drawn forward = +X, so the angle is
	# just heading.angle() (no +PI/2 offset). Used for every enemy now.
	if not _path.is_empty():
		var heading := _level.cell_center(_path[0]) - position
		if heading.length_squared() > 0.01:
			_face = heading.angle()
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
	# Decay the damage-flash ghost back down toward current health (exponential
	# catch-up). delta*6 means ~10% of the remaining gap closes per 60-Hz frame,
	# so a chunk is half-gone in ~0.1s but still readable on tiny hits.
	if _flash_health < health:
		_flash_health = health  # heal (or init): snap up, no flash
	else:
		_flash_health = lerp(_flash_health, health, minf(1.0, delta * 6.0))
		if _flash_health - health < max_health * 0.001:
			_flash_health = health
	queue_redraw()

func _reach_base() -> void:
	if _dead:
		return
	_dead = true
	GameState.lose_life(leak_damage)
	queue_free()

## Damage pipeline. THE MATH:
##
##   health -= amount * resist[dtype] * (1 + vuln_pct)
##
## `resist[dtype]` is a MULTIPLIER on incoming damage, NOT a reduction:
##   resist["fire"] = 0.35  means take 35% of fire damage (65% effectively
##   resisted). Missing key defaults to 1.0 (full damage).
##
## `_vuln_pct` (poison vulnerability) is a SEPARATE multiplier applied on
## top - so a fire-resistant Tank that's also poisoned still takes the
## resist hit, then the vuln multiplies whatever's left. Vuln stacks with
## resist, doesn't replace it.
##
## All damage paths land here: bullets, AOE, beams, traps, DoTs. So this
## is the one place per-enemy damage gets resolved.
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
	_flash_health = health
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
	# Drifting "+gold" reward popup, in the wave-info gold colour.
	if _level != null:
		# spawn_float expects a GLOBAL position (it runs to_local on it).
		# Pass global_position so the popup sits on the enemy even when
		# Level is zoomed/panned (scale and position are non-identity).
		_level.spawn_float(global_position, "+%s" % GameState.abbrev(gold_award),
			Color(0.96, 0.84, 0.46))
	queue_free()

func apply_slow(factor: float, duration: float) -> void:
	if _dead:
		return
	_slow_factor = maxf(_slow_factor, factor)
	_slow_timer = maxf(_slow_timer, duration)
	speed = base_speed * (1.0 - _slow_factor)

func _draw() -> void:
	# Soft elliptical ground shadow under the enemy (sells the "grounded" feel).
	draw_set_transform(Vector2(0, radius * 0.55), 0, Vector2(1.0, 0.40))
	draw_circle(Vector2.ZERO, radius * 0.95, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_draw_body()
	_draw_status()
	# Health bar sits ABOVE the body (the old centred bar competed with the
	# new vehicle bodies' turret/canopy). Fixed-min width of 32 px so tiny
	# enemies still have enough resolution to read small damage; widens with
	# radius for the bigger bosses.
	var frac := clampf(health / max_health, 0.0, 1.0)
	var flash_frac := clampf(_flash_health / max_health, 0.0, 1.0)
	var bw := maxf(32.0, radius * 2.4)
	var bh := 5.0
	var bx := -bw * 0.5
	var by := -radius - 8.0
	# Black backing.
	draw_rect(Rect2(bx, by, bw, bh), Color(0, 0, 0, 0.72))
	# Yellow flash chunk: the segment of bar that's currently catching up to
	# the green - sells "you just lost this much" even when individual hits
	# would be subpixel against the full bar width.
	if flash_frac > frac:
		draw_rect(Rect2(bx + bw * frac, by, bw * (flash_frac - frac), bh),
			Color(1.0, 0.78, 0.20))
	# Green current-health chunk.
	draw_rect(Rect2(bx, by, bw * frac, bh), Color(0.30, 0.90, 0.35))

## Top-down robot/vehicle bodies. All draw forward = +X, so the whole body
## rotates with _face. After drawing, the transform is reset so the health
## bar and status pips stay world-axis-aligned.
func _draw_body() -> void:
	draw_set_transform(Vector2.ZERO, _face, Vector2.ONE)
	if is_boss:
		match boss_kind:
			"spider": _draw_spider_drone()
			"turtle": _draw_turtle_transport()
			_: _draw_beetle_walker()
	else:
		match shape:
			"triangle": _draw_runner_car()
			"hexagon": _draw_tank()
			_: _draw_grunt_scout()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## --- Top-down vehicle/mech draws. Forward = +X (right). Sizes scale with
## radius so balance tweaks to enemy size don't break the visuals. ---

## Grunt: armored 4-wheel scout buggy. Boxy hull, dome canopy, paired
## headlights up front. Reads as a patrol vehicle.
func _draw_grunt_scout() -> void:
	var r := radius
	var dark := color.darkened(0.50)
	# Four corner wheels (rectangles oriented along the body axis).
	for sx in [-r * 0.50, r * 0.30]:
		for sy in [-r * 0.40, r * 0.40]:
			draw_rect(Rect2(sx, sy - r * 0.14, r * 0.20, r * 0.14), OUTLINE)
			draw_rect(Rect2(sx + r * 0.02, sy - r * 0.10, r * 0.16, r * 0.10),
				Color(0.22, 0.22, 0.24))
	# Hull outline + body.
	var bw := r * 1.10
	var bh := r * 0.66
	draw_rect(Rect2(-bw, -bh, bw * 2.0, bh * 2.0), OUTLINE)
	draw_rect(Rect2(-bw + 2.0, -bh + 2.0, bw * 2.0 - 4.0, bh * 2.0 - 4.0), color)
	# Top-lit strip (left/front-quarter where overhead light hits).
	draw_rect(Rect2(-bw + 2.0, -bh + 2.0, bw * 2.0 - 4.0, 3.0),
		Color(1, 1, 1, 0.18))
	# Round canopy dome with a glass highlight.
	draw_circle(Vector2(-r * 0.05, 0), r * 0.32, OUTLINE)
	draw_circle(Vector2(-r * 0.05, 0), r * 0.27, dark)
	draw_circle(Vector2(-r * 0.14, -r * 0.10), r * 0.16,
		Color(0.78, 0.82, 0.92, 0.55))
	# Paired forward headlights (right edge).
	draw_circle(Vector2(bw - 2.0, -r * 0.28), r * 0.10, Color(1, 0.92, 0.55))
	draw_circle(Vector2(bw - 2.0, r * 0.28), r * 0.10, Color(1, 0.92, 0.55))

## Runner: long sleek race car / speeder, tapered nose, motion lines behind.
## Reads as "fast." Resists poison (sealed cockpit, no biology).
func _draw_runner_car() -> void:
	var r := radius
	var dark := color.darkened(0.45)
	# Trailing motion lines (in body color, behind the rear axle).
	for off in [Vector2(-r * 2.0, 0.0), Vector2(-r * 1.8, -r * 0.40), Vector2(-r * 1.8, r * 0.40)]:
		draw_rect(Rect2(off.x, off.y - r * 0.06, r * 0.55, r * 0.12),
			Color(color.r, color.g, color.b, 0.45))
	# Side wheels (4 small ones).
	for sx in [-r * 0.65, r * 0.20]:
		for sy in [-r * 0.55, r * 0.45]:
			draw_rect(Rect2(sx, sy, r * 0.32, r * 0.16), OUTLINE)
			draw_rect(Rect2(sx + 0.04, sy + 0.04, r * 0.28, r * 0.12),
				Color(0.22, 0.22, 0.24))
	# Body: tapered wedge from blunt back to pointed nose at +X.
	var pts := PackedVector2Array([
		Vector2(-r * 0.95, -r * 0.42),
		Vector2(r * 0.30, -r * 0.42),
		Vector2(r * 1.20, 0.0),
		Vector2(r * 0.30, r * 0.42),
		Vector2(-r * 0.95, r * 0.42),
	])
	_draw_filled_outlined(pts, color, OUTLINE)
	# Top-lit strip along the upper half of the wedge.
	var lit_pts := PackedVector2Array([
		Vector2(-r * 0.90, -r * 0.40), Vector2(r * 0.28, -r * 0.40),
		Vector2(r * 1.05, -r * 0.10), Vector2(-r * 0.90, -r * 0.20),
	])
	draw_colored_polygon(lit_pts, Color(1, 1, 1, 0.22))
	# Cockpit canopy: small oval in the middle.
	draw_circle(Vector2(-r * 0.12, 0), r * 0.30, OUTLINE)
	draw_circle(Vector2(-r * 0.12, 0), r * 0.24,
		Color(0.78, 0.82, 0.92, 0.65))
	# Rear spoiler bar (back end).
	draw_rect(Rect2(-r * 1.05, -r * 0.50, r * 0.12, r * 1.00), OUTLINE)
	draw_rect(Rect2(-r * 1.02, -r * 0.42, r * 0.06, r * 0.84), dark)
	# Forward nose lamp.
	draw_circle(Vector2(r * 1.08, 0), r * 0.10, Color(1, 0.92, 0.55))

## Tank: chunky armored hull between two side treads, central turret, gun
## barrel pointing forward. Reads as "slow & tough." Resists fire.
func _draw_tank() -> void:
	var r := radius
	var dark := color.darkened(0.45)
	# Top tread strip (with tick marks).
	var tw := r * 1.10  # tread half-length
	var ty := r * 0.78  # tread distance from centerline
	draw_rect(Rect2(-tw, -ty - r * 0.18, tw * 2.0, r * 0.18 * 2.0), OUTLINE)
	# Tread tick marks: ~6 short rectangles along the tread.
	var th := r * 0.18 * 1.5
	var tickw := r * 0.14
	for i in range(7):
		var tx := -tw + r * 0.06 + i * (tw * 2.0 - r * 0.12) / 7.0
		draw_rect(Rect2(tx, -ty - r * 0.14, tickw, th),
			Color(0.30, 0.30, 0.34))
	# Bottom tread strip.
	draw_rect(Rect2(-tw, ty - r * 0.18, tw * 2.0, r * 0.18 * 2.0), OUTLINE)
	for i in range(7):
		var tx2 := -tw + r * 0.06 + i * (tw * 2.0 - r * 0.12) / 7.0
		draw_rect(Rect2(tx2, ty - r * 0.14, tickw, th),
			Color(0.30, 0.30, 0.34))
	# Hull between the treads.
	var hw := r * 1.00
	var hh := r * 0.58
	draw_rect(Rect2(-hw, -hh, hw * 2.0, hh * 2.0), OUTLINE)
	draw_rect(Rect2(-hw + 2.0, -hh + 2.0, hw * 2.0 - 4.0, hh * 2.0 - 4.0), color)
	# Top-lit strip across the hull's upper edge.
	draw_rect(Rect2(-hw + 2.0, -hh + 2.0, hw * 2.0 - 4.0, 3.0),
		Color(1, 1, 1, 0.20))
	# Turret: round, centred.
	draw_circle(Vector2(-r * 0.05, 0), r * 0.46, OUTLINE)
	draw_circle(Vector2(-r * 0.05, 0), r * 0.40, color.lightened(0.08))
	# Turret top highlight + central hatch.
	draw_circle(Vector2(-r * 0.18, -r * 0.14), r * 0.22, Color(1, 1, 1, 0.22))
	draw_circle(Vector2(-r * 0.05, 0), r * 0.10, Color(0, 0, 0, 0.55))
	# Gun barrel pointing forward (+X).
	draw_rect(Rect2(r * 0.30, -r * 0.10, r * 1.10, r * 0.20), OUTLINE)
	draw_rect(Rect2(r * 0.34, -r * 0.06, r * 1.02, r * 0.12), dark)
	# Muzzle cap.
	draw_rect(Rect2(r * 1.30, -r * 0.16, r * 0.14, r * 0.32), OUTLINE)

## Beetle boss: quadrupedal walker mech. Oval armored carapace, four splayed
## legs with foot pads, two glowing optics up front. Blue (BEETLE_COLOR).
func _draw_beetle_walker() -> void:
	var r := radius
	# Four legs splayed NW/NE/SW/SE - drawn before the body so the carapace
	# covers the leg roots.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var root := Vector2(sx * r * 0.40, sy * r * 0.40)
			var foot := Vector2(sx * r * 1.05, sy * r * 1.05)
			draw_line(root, foot, OUTLINE, 6.0)
			draw_line(root, foot, color.darkened(0.45), 3.5)
			draw_circle(foot, r * 0.10, OUTLINE)
	# Carapace: oval, longer along travel axis (+X).
	var car := _ellipse(r * 0.95, r * 0.78, 24)
	_draw_filled_outlined(car, color, OUTLINE)
	# Top-lit highlight on the upper-back of the carapace.
	draw_circle(Vector2(-r * 0.25, -r * 0.25), r * 0.36, Color(1, 1, 1, 0.24))
	# Centre seam ridge running along the body axis.
	draw_line(Vector2(-r * 0.80, 0), Vector2(r * 0.80, 0),
		Color(0, 0, 0, 0.45), 1.5)
	# Two glowing front optics on the right (front) edge.
	for sy in [-r * 0.28, r * 0.28]:
		draw_circle(Vector2(r * 0.55, sy), r * 0.14, OUTLINE)
		draw_circle(Vector2(r * 0.55, sy), r * 0.09, Color(1, 0.91, 0.55))

## Spider boss: 8-legged combat drone splayed in classic spider pattern.
## Single big red cyclops optic up front.
func _draw_spider_drone() -> void:
	var r := radius
	var dark := color.darkened(0.45)
	# 8 legs in spider splay (4 per side, knee bends outward). Draw first.
	var leg_data: Array = [
		[Vector2(-r * 0.30, -r * 0.40), Vector2(-r * 0.80, -r * 0.75), Vector2(-r * 1.10, -r * 1.05)],
		[Vector2(-r * 0.45, -r * 0.25), Vector2(-r * 1.05, -r * 0.40), Vector2(-r * 1.30, -r * 0.55)],
		[Vector2(-r * 0.45, r * 0.25), Vector2(-r * 1.05, r * 0.40), Vector2(-r * 1.30, r * 0.55)],
		[Vector2(-r * 0.30, r * 0.40), Vector2(-r * 0.80, r * 0.75), Vector2(-r * 1.10, r * 1.05)],
		[Vector2(r * 0.30, -r * 0.40), Vector2(r * 0.80, -r * 0.75), Vector2(r * 1.10, -r * 1.05)],
		[Vector2(r * 0.45, -r * 0.25), Vector2(r * 1.05, -r * 0.40), Vector2(r * 1.30, -r * 0.55)],
		[Vector2(r * 0.45, r * 0.25), Vector2(r * 1.05, r * 0.40), Vector2(r * 1.30, r * 0.55)],
		[Vector2(r * 0.30, r * 0.40), Vector2(r * 0.80, r * 0.75), Vector2(r * 1.10, r * 1.05)],
	]
	for leg in leg_data:
		draw_polyline(PackedVector2Array(leg), OUTLINE, 4.0)
		draw_polyline(PackedVector2Array(leg), dark, 2.2)
	# Central body: oval, slightly longer along travel.
	var body := _ellipse(r * 0.52, r * 0.42, 22)
	_draw_filled_outlined(body, color, OUTLINE)
	# Top-lit highlight.
	draw_circle(Vector2(-r * 0.12, -r * 0.12), r * 0.22, Color(1, 1, 1, 0.24))
	# Big red front cyclops optic.
	draw_circle(Vector2(r * 0.30, 0), r * 0.16, OUTLINE)
	draw_circle(Vector2(r * 0.30, 0), r * 0.11, Color(1, 0.35, 0.22))
	draw_circle(Vector2(r * 0.30, 0), r * 0.05, Color(1, 0.82, 0.74))
	# Rear chassis vent slits.
	draw_rect(Rect2(-r * 0.36, -r * 0.06, r * 0.20, r * 0.04),
		Color(0, 0, 0, 0.65))
	draw_rect(Rect2(-r * 0.36, r * 0.02, r * 0.20, r * 0.04),
		Color(0, 0, 0, 0.65))

## Turtle boss: heavy low siege transport. Wide tread strips both sides,
## big domed armored shell, slit windows up front.
func _draw_turtle_transport() -> void:
	var r := radius
	# Tread strips top and bottom (matching the tank style but wider).
	var tw := r * 1.08
	var ty := r * 0.82
	draw_rect(Rect2(-tw, -ty - r * 0.20, tw * 2.0, r * 0.40), OUTLINE)
	for i in range(8):
		var tx := -tw + r * 0.06 + i * (tw * 2.0 - r * 0.12) / 8.0
		draw_rect(Rect2(tx, -ty - r * 0.15, r * 0.12, r * 0.30),
			Color(0.30, 0.30, 0.34))
	draw_rect(Rect2(-tw, ty - r * 0.20, tw * 2.0, r * 0.40), OUTLINE)
	for i in range(8):
		var tx2 := -tw + r * 0.06 + i * (tw * 2.0 - r * 0.12) / 8.0
		draw_rect(Rect2(tx2, ty - r * 0.15, r * 0.12, r * 0.30),
			Color(0.30, 0.30, 0.34))
	# Domed armored shell: big oval.
	var shell := _ellipse(r * 0.92, r * 0.68, 28)
	_draw_filled_outlined(shell, color, OUTLINE)
	# Top-lit highlight on upper-back of shell.
	draw_circle(Vector2(-r * 0.22, -r * 0.22), r * 0.50, Color(1, 1, 1, 0.22))
	# Shell panel seams radiating from centre.
	draw_arc(Vector2(0, -r * 0.20), r * 0.60, PI * 0.20, PI * 0.80,
		16, Color(0, 0, 0, 0.40), 1.3)
	draw_arc(Vector2(0, r * 0.20), r * 0.60, PI * 1.20, PI * 1.80,
		16, Color(0, 0, 0, 0.40), 1.3)
	draw_line(Vector2(-r * 0.55, 0), Vector2(r * 0.55, 0),
		Color(0, 0, 0, 0.30), 1.2)
	# Slit windows on the front (right) edge.
	for sy in [-r * 0.20, r * 0.20]:
		draw_rect(Rect2(r * 0.55, sy - r * 0.18, r * 0.06, r * 0.12),
			Color(1, 0.91, 0.55, 0.85))
		draw_rect(Rect2(r * 0.65, sy - r * 0.18, r * 0.06, r * 0.12),
			Color(1, 0.91, 0.55, 0.85))

## Helper: draw a closed polygon filled and outlined with the given colors.
func _draw_filled_outlined(pts: PackedVector2Array, fill: Color, line: Color) -> void:
	draw_colored_polygon(pts, fill)
	_draw_outline(pts, line)

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
