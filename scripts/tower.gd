class_name Tower
extends Structure
## A circular tower: blocks the path AND attacks. Behaviour depends on type.
## "shot" towers fire homing bullets; "beam" towers (laser) deal continuous damage.

## Projectile look per tower type (default is a small bullet).
const BULLET_STYLE := {"cannon": "ball", "missile": "missile"}
## Shared visual style: opaque near-black outline used across every piece.
const OUTLINE := Color(0.04, 0.04, 0.05)

## Minimum seconds between *visible* projectiles. A fast tower still does full
## damage every shot, but only spawns a flying bullet this often; the extra
## shots in between hit instantly. Keeps rapid fire from looking like a solid
## laser stream while still reading as "this tower is shooting".
const VISUAL_SHOT_INTERVAL := 0.22

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
var _visual_cd := 0.0  # counts down to the next visible projectile (see VISUAL_SHOT_INTERVAL)
var _beam_targets: Array = []

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
	if type == "gold":
		# Per-mine numbers live on the 3rd "Amplified -> gold -> map" line below.
		return "gold from kills"
	if type == "amplifier":
		return "+%.1f%% to the 8 pieces touching it: damage, slow, DoT, gold (stacks with other amps)" % (_support_pct() * 100.0)
	if mode == "beam":
		return "beam   %s dmg/sec   range %d   single target" % [
			GameState.abbrev(damage), int(range_radius)]
	if mode == "slow":
		return "AOE slow %d%% for %.1fs   range %d   %.1f/s" % [
			int(slow * 100.0), slow_time, int(range_radius), fire_rate]
	var t := "range %d   dmg %s   %.1f/s" % [int(range_radius), GameState.abbrev(damage), fire_rate]
	if aoe_radius > 0.0:
		t += "   AOE %d" % int(aoe_radius)
	if slow > 0.0:
		t += "   slow %d%%" % int(slow * 100.0)
	return t

## Per-frame tower behaviour. The TWO COOLDOWNS deserve a callout:
##
##   _cooldown        gates DAMAGE delivery (1 / fire_rate seconds per shot).
##                    Every shot still hits for full damage.
##   _visual_cd       gates VISIBLE projectile spawn (VISUAL_SHOT_INTERVAL).
##                    When a shot is throttled, _fire() routes straight to
##                    _direct_hit and skips spawning a Bullet node.
##
## A maxed Bullet (~4 shots/sec) would otherwise look like a solid laser
## stream of bullets; the throttle keeps the *visual* down to ~5/sec while
## damage continues at the real rate. DO NOT collapse these two cooldowns
## into one - you'd either nerf the DPS or restore the laser-stream look.
##
## The `shots < 12` cap is per-frame so a 100x-speed tower can't burn the
## whole frame budget firing; the rest of the catch-up happens next frame.
func _process(delta: float) -> void:
	if GameState.game_over:
		return
	if mode == "support":
		# Gold Mine / Amplifier are passive - their effects are read elsewhere
		# (Level.gold_bonus / Level.amplifier_bonus_at). Nothing to do per frame.
		return
	if mode == "beam":
		_beam_targets = _acquire_beam_targets()
		var bdmg := _boosted_damage()
		for node in _beam_targets:
			(node as Enemy).take_damage(bdmg * delta)
		queue_redraw()
		return
	if mode == "slow":
		_process_slow(delta)
		return
	_cooldown -= delta
	if _visual_cd > 0.0:
		_visual_cd -= delta
	# Fire repeatedly if elapsed time allows, so high game speeds keep up.
	var shots := 0
	while _cooldown <= 0.0 and shots < 12:
		var target := _acquire_target()
		if target == null:
			_cooldown = 0.0
			break
		# Only spawn a visible projectile every so often; faster shots hit
		# instantly so a high fire rate doesn't read as a solid laser beam.
		var show := _visual_cd <= 0.0
		if show:
			_visual_cd += VISUAL_SHOT_INTERVAL
		_fire(target, show)
		_cooldown += 1.0 / fire_rate
		shots += 1

## This support tower's per-level percentage (gold or amplifier), 0.5%/level.
func _support_pct() -> float:
	return PieceData.SUPPORT_PCT_PER_LEVEL * level

## Info-box 3rd line for a tower being boosted by adjacent Amplifiers (damage
## towers, or a Gold Mine's gold rate); "" when not amplified / not applicable.
func enhancement_text() -> String:
	if level_ref == null:
		return ""
	var b := level_ref.amplifier_bonus_at(cell)
	if type == "gold":
		# Always show the flow: amplifier bonus -> this mine's rate -> the
		# board-wide total of every Gold Mine.
		var gamp := minf(Level.GOLD_AMP_CAP, b)
		var mine := _support_pct() * (1.0 + gamp) * 100.0
		var board := level_ref.gold_bonus() * 100.0
		var ga := GameState.arrow()
		if gamp > 0.0:
			return "Amplified +%d%%   %s   gold +%.1f%%   %s   map +%.1f%%" % [
				int(round(gamp * 100.0)), ga, mine, ga, board]
		return "gold +%.1f%%   %s   map total +%.1f%%" % [mine, ga, board]
	if b <= 0.0:
		return ""
	if mode == "slow":
		# Ice: amp lifts the chill toward SLOW_BOOST_CAP.
		var eff := minf(PieceData.SLOW_BOOST_CAP, slow * (1.0 + b))
		return "Amplified  +%d%%   %s   slows %d%%" % [
			int(round(b * 100.0)), GameState.arrow(), int(round(eff * 100.0))]
	if mode != "shot" and mode != "beam":
		return ""
	var unit := "dmg/s" if mode == "beam" else "dmg"
	return "Amplified  +%d%%   %s   %s %s" % [
		int(round(b * 100.0)), GameState.arrow(), GameState.abbrev(damage * (1.0 + b)), unit]

## Damage after applying any adjacent Amplifier towers' boost.
func _boosted_damage() -> float:
	if level_ref == null:
		return damage
	return damage * (1.0 + level_ref.amplifier_bonus_at(cell))

## AOE splash radius after adjacent-Amplifier boost. Unchanged for non-AOE
## towers (aoe_radius 0), so Gold/Amp/single-target towers are unaffected.
func _boosted_aoe() -> float:
	if level_ref == null or aoe_radius <= 0.0:
		return aoe_radius
	var v := aoe_radius * (1.0 + level_ref.amplifier_bonus_at(cell))
	if PieceData.AOE_CAP.has(type):
		return minf(PieceData.AOE_CAP[type], v)
	return v

## Ice tower: every interval, chill every enemy in range at once. No firing
## visual - the slow status icon on enemies is the only feedback (no flicker).
func _process_slow(delta: float) -> void:
	_cooldown -= delta
	var pulses := 0
	# Adjacent Amplifiers lift the chill toward SLOW_BOOST_CAP.
	var amp := level_ref.amplifier_bonus_at(cell) if level_ref != null else 0.0
	var eff_slow := minf(PieceData.SLOW_BOOST_CAP, slow * (1.0 + amp))
	while _cooldown <= 0.0 and pulses < 12:
		var targets := _acquire_slow_targets()
		if targets.is_empty():
			_cooldown = 0.0
			break
		for node in targets:
			var e := node as Enemy
			# Ice only slows - no direct damage, no cripple (single status icon).
			e.apply_slow(eff_slow, slow_time)
		_cooldown += 1.0 / fire_rate
		pulses += 1

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

func _fire(target: Enemy, show: bool = true) -> void:
	# At high game speed, or when throttling the visible projectile rate, skip the
	# flying bullet and apply damage instantly (same on-hit behaviour).
	if not show or GameState.reduced_gfx():
		_direct_hit(target)
		return
	var b := Bullet.new()
	b.position = position
	# Shots take the tower's BODY colour so each tower's ammo matches it (the old
	# per-type bullet_colors overlapped - missile/cannon both orange, etc.).
	b.setup(target, _boosted_damage(), color, slow, slow_time, _boosted_aoe())
	b.retarget = type == "missile"
	b.style = BULLET_STYLE.get(type, "bullet")
	b.level_ref = level_ref
	level_ref.bullets.add_child(b)

## Instant version of a shot, used when graphics are reduced. Mirrors the
## bullet's on-hit behaviour (area damage + slow, or single-target).
func _direct_hit(target: Enemy) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	var dmg := _boosted_damage()
	var aoe := _boosted_aoe()
	if aoe > 0.0:
		for node in level_ref.enemies_near(target.position, aoe):
			var e := node as Enemy
			if e == null or not e.is_alive():
				continue
			if target.position.distance_to(e.position) <= aoe:
				e.take_damage(dmg)
				if slow > 0.0:
					e.apply_slow(slow, slow_time)
	else:
		target.take_damage(dmg)
		if slow > 0.0:
			target.apply_slow(slow, slow_time)

func _draw() -> void:
	if mode == "beam":
		for node in _beam_targets:
			# Validate BEFORE casting: `as Enemy` on a freed object hard-crashes
			# in release builds. _beam_targets can hold stale refs (e.g. after
			# game over, when _process stops refreshing the list).
			if not is_instance_valid(node):
				continue
			var t := node as Enemy
			if t != null and t.is_alive():
				var lp := t.position - position
				draw_line(Vector2.ZERO, lp, Color(bullet_color, 0.85), 3.0)
				draw_circle(lp, 5.0, bullet_color)
	# Support towers (Gold/Amp) have no range/AOE, so don't draw a range circle.
	if selected and mode != "support" and range_radius > 0.0:
		draw_circle(Vector2.ZERO, range_radius, Color(1, 1, 1, 0.06))
		draw_arc(Vector2.ZERO, range_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.40), 1.5)
	# Soft elliptical ground shadow below the tower (squished circle).
	draw_set_transform(Vector2(0, 14), 0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.30))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Opaque outline ring (2 px visible against the body inside).
	draw_circle(Vector2.ZERO, 17.0, OUTLINE)
	# Body disk.
	draw_circle(Vector2.ZERO, 15.0, color)
	# Top-lit highlight: a small lighter disk offset to upper-left of the body
	# - this is what gives the flat disk a "molded" feel.
	var lit := color.lightened(0.30)
	draw_circle(Vector2(-3.5, -4.5), 8.5, Color(lit.r, lit.g, lit.b, 0.45))
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
		"gold":  # a dollar sign
			var gf := ThemeDB.fallback_font
			var gw := gf.get_string_size("$", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(gf, Vector2(-gw / 2.0, 6.0), "$",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
		"amplifier":  # an upward boost arrow
			draw_line(Vector2(0, 7.5), Vector2(0, -7.5), ink, 2.6)
			draw_line(Vector2(0, -7.5), Vector2(-5.5, -1.0), ink, 2.6)
			draw_line(Vector2(0, -7.5), Vector2(5.5, -1.0), ink, 2.6)
