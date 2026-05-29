class_name Bullet
extends Node2D
## Homing projectile. Applies slow on hit (ice) and/or area damage (cannon).

const BOOM_TIME := 0.22

var target: Enemy
var speed := 480.0
var damage := 10.0
var color := Color.WHITE
var slow := 0.0
var slow_time := 0.0
var aoe_radius := 0.0
var retarget := false
var style := "bullet"
var level_ref: Level  # set by tower; used for spatial enemy lookups

var _dest := Vector2.ZERO
var _exploding := false
var _boom := 0.0

func setup(t: Enemy, dmg: float, col: Color, sl: float, sl_t: float, aoe: float) -> void:
	target = t
	damage = dmg
	color = col
	slow = sl
	slow_time = sl_t
	aoe_radius = aoe
	if t != null:
		_dest = t.position

func _process(delta: float) -> void:
	if GameState.game_over:
		return
	if _exploding:
		_boom += delta
		queue_redraw()
		if _boom >= BOOM_TIME:
			queue_free()
		return
	# Only missiles home: they keep steering toward the live target and
	# re-acquire a new one if it dies. Other shots fly straight to the spot
	# they were aimed at when fired (set in setup()).
	if retarget:
		if target != null and is_instance_valid(target) and target.is_alive():
			_dest = target.position
		else:
			# Missile: the target is gone - lock onto the next enemy in line.
			target = _find_new_target()
			if target != null:
				_dest = target.position
	var to_dest := _dest - position
	if style != "ball" and to_dest.length() > 0.5:
		rotation = to_dest.angle()
	var step := speed * delta
	if to_dest.length() <= step:
		position = _dest
		_hit()
	else:
		position += to_dest.normalized() * step
		queue_redraw()

func _find_new_target() -> Enemy:
	# Missiles re-acquire from a generous radius around their current position
	# using the level's spatial bucket grid.
	var best: Enemy = null
	var best_d := INF
	var search_radius := 600.0
	var pool: Array
	if level_ref != null:
		pool = level_ref.enemies_near(position, search_radius)
	else:
		pool = get_tree().get_nodes_in_group("enemies")
	for node in pool:
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := position.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _hit() -> void:
	if aoe_radius > 0.0:
		var pool: Array
		if level_ref != null:
			pool = level_ref.enemies_near(_dest, aoe_radius)
		else:
			pool = get_tree().get_nodes_in_group("enemies")
		for node in pool:
			var e := node as Enemy
			if e == null or not e.is_alive():
				continue
			if _dest.distance_to(e.position) <= aoe_radius:
				e.take_damage(damage)
				if slow > 0.0:
					e.apply_slow(slow, slow_time)
		# Bigger spark burst at the impact point for AOE shots.
		if level_ref != null:
			# _dest is in Level-local space; spawn_sparks wants global.
			level_ref.spawn_sparks(level_ref.to_global(_dest), color, 10)
		_exploding = true
		_boom = 0.0
		queue_redraw()
		return
	if target != null and is_instance_valid(target) and target.is_alive():
		target.take_damage(damage)
		if slow > 0.0:
			target.apply_slow(slow, slow_time)
		# Small spark pop on a clean single-target hit.
		if level_ref != null:
			# spawn_sparks expects GLOBAL coords; target.position is Level-local
			# and gets mis-mapped once Level is zoomed/panned.
			level_ref.spawn_sparks(target.global_position, color, 6)
	queue_free()

func _draw() -> void:
	if _exploding:
		var f := _boom / BOOM_TIME
		draw_circle(Vector2.ZERO, aoe_radius * f,
			Color(color.r, color.g, color.b, 0.35 * (1.0 - f)))
		draw_arc(Vector2.ZERO, aoe_radius * f, 0.0, TAU, 32,
			Color(color.r, color.g, color.b, 0.9 * (1.0 - f)), 2.5)
		return
	match style:
		"missile":
			# Flame tail, fins, then body - all pointing along local +x.
			draw_colored_polygon(PackedVector2Array([
				Vector2(-7, -2), Vector2(-13, 0), Vector2(-7, 2)]),
				Color(1.0, 0.80, 0.30, 0.9))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5, -3), Vector2(-9, -7), Vector2(-2, -3)]), color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5, 3), Vector2(-9, 7), Vector2(-2, 3)]), color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(9, 0), Vector2(2, -3), Vector2(-7, -3),
				Vector2(-7, 3), Vector2(2, 3)]), color)
			draw_circle(Vector2(-1, 0), 1.7, Color(1, 1, 1, 0.7))
		"ball":
			draw_circle(Vector2.ZERO, 7.0, color)
			draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 24, Color(0, 0, 0, 0.4), 1.5)
			draw_circle(Vector2(-2.2, -2.2), 2.6, Color(1, 1, 1, 0.55))
		_:
			# A small cartridge silhouette pointing along its travel direction.
			draw_colored_polygon(PackedVector2Array([
				Vector2(6, 0), Vector2(2, -3), Vector2(-5, -3),
				Vector2(-5, 3), Vector2(2, 3)]), color)
			draw_circle(Vector2(2.4, 0), 1.6, Color(1, 1, 1, 0.7))
