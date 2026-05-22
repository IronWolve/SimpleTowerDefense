class_name Trap
extends Structure
## A square floor device. Does not block; hurts/slows enemies that walk over it.
## Poison and Fire traps apply a lingering damage-over-time effect that keeps
## ticking after the enemy leaves; Spike deals plain contact damage.
## Upgradeable, like towers.

const REACH := 22.0
## Traps whose damage is a lingering DoT, and the damage type they deal.
const DOT_TYPE := {"poison_trap": "poison", "fire_trap": "fire"}
## How long the DoT lingers after the enemy steps off, per type.
## Both extended 30% over the original tuning.
const DOT_TIME := {"poison": 3.9, "fire": 1.95}
## Traps that erupt periodically and damage every enemy inside their reach.
const AOE_TYPES := {"volcano_trap": true}
const ERUPT_PERIOD := 0.8
const ERUPT_FLASH := 0.35

var slow := 0.0
var dmg := 0.0
var color := Color.WHITE
## Detection radius. Wider on area-effect traps (Volcano) via PieceData aoe_radius.
var reach := REACH

var _erupt_timer := 0.0
var _erupt_flash := 0.0

func _apply_stats() -> void:
	var d := PieceData.trap_stats(type, level)
	slow = d["slow"]
	dmg = d["damage"]
	color = d["color"]
	var aoe: float = d["aoe_radius"]
	reach = aoe if aoe > 0.0 else REACH

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
	if slow > 0.0:
		if dmg > 0.0:
			return "slows %d%%   %d dmg/sec" % [int(slow * 100.0), int(dmg)]
		return "slows %d%%" % int(slow * 100.0)
	if DOT_TYPE.has(type):
		var s := "%s burn   %d dmg/sec" % [DOT_TYPE[type], int(dmg)]
		if type == "poison_trap":
			s += "   +%d%% damage taken" % int(_poison_vuln() * 100.0)
		return s
	if AOE_TYPES.has(type):
		# Volcano: pulses every ERUPT_PERIOD seconds. Show per-pulse damage
		# and the effective dps for clarity.
		return "%d/pulse (~%.0f dps)   area %d   every %.1fs" % [
			int(dmg), dmg / ERUPT_PERIOD, int(reach), ERUPT_PERIOD]
	if type == "spike_trap":
		return "%d dmg/s or %d%% max HP/s on contact" % [
			int(dmg), int(_spike_pct() * 100.0)]
	return "%d damage / sec" % int(dmg)

func _process(delta: float) -> void:
	if GameState.game_over:
		return
	if AOE_TYPES.has(type):
		_process_aoe(delta)
	else:
		_process_contact(delta)

## Continuous contact damage: ticks every enemy currently touching the trap.
func _process_contact(delta: float) -> void:
	for node in level_ref.enemies_near(position, reach):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		if slow > 0.0:
			e.apply_slow(slow, 0.39)
		if dmg > 0.0:
			if DOT_TYPE.has(type):
				var dt: String = DOT_TYPE[type]
				# Poison / fire DoT lasts 1 extra second per upgrade level.
				var dur: float = DOT_TIME[dt] + 1.0 * (level - 1)
				e.apply_dot(dmg, dur, dt)
				# Poison also makes the target vulnerable: it takes extra damage
				# from all sources for the same duration (5% at L1, +1%/level,
				# cap 50%; max-wins, no stacking).
				if type == "poison_trap":
					e.apply_vuln(_poison_vuln(), dur)
			elif type == "spike_trap":
				# Spike: the larger of a small flat DPS (kills early trash) or a
				# percent of the enemy's max HP per second (tracks any wave and
				# punishes tanks). Halved vs bosses so a lane can't trivialize them.
				var pct := _spike_pct()
				if e.is_boss:
					pct *= 0.5
				e.take_damage(maxf(dmg, pct * e.max_health) * delta)
			else:
				e.take_damage(dmg * delta)

## Poison's vulnerability: target takes 5% more damage at L1, +1% per level,
## capped at 50% extra.
func _poison_vuln() -> float:
	return minf(0.50, 0.05 + 0.01 * (level - 1))

## Spike's bleed: 0.8% of max HP per second per level, capped at 12%/sec.
func _spike_pct() -> float:
	return minf(0.12, 0.008 * level)

## Periodic eruption: damage every enemy in reach in one visible pulse.
func _process_aoe(delta: float) -> void:
	var reduced := GameState.reduced_gfx()
	if _erupt_flash > 0.0:
		_erupt_flash -= delta
		if not reduced:
			queue_redraw()
	_erupt_timer -= delta
	if _erupt_timer > 0.0:
		return
	_erupt_timer += ERUPT_PERIOD
	# Skip the expanding shock-wave animation when graphics are reduced.
	if not reduced:
		_erupt_flash = ERUPT_FLASH
	for node in level_ref.enemies_near(position, reach):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		e.take_damage(dmg)
	if not reduced:
		queue_redraw()

func _draw() -> void:
	var h := 17.0
	draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), color)
	match type:
		"tar_trap":
			draw_circle(Vector2(-6, -4), 5.0, Color(0.04, 0.04, 0.03))
			draw_circle(Vector2(7, 5), 6.0, Color(0.04, 0.04, 0.03))
			draw_circle(Vector2(6, -8), 3.5, Color(0.04, 0.04, 0.03))
		"spike_trap":
			for sx in [-9.0, 0.0, 9.0]:
				draw_colored_polygon(PackedVector2Array([
					Vector2(sx - 5.0, 7.0), Vector2(sx + 5.0, 7.0), Vector2(sx, -10.0)]),
					Color(0.58, 0.58, 0.62))
		"poison_trap":
			for p in [Vector2(-7, 4), Vector2(6, -3), Vector2(0, -10), Vector2(8, 9)]:
				draw_circle(p, 4.5, Color(0.45, 0.85, 0.32))
				draw_arc(p, 4.5, 0.0, TAU, 12, Color(0.16, 0.40, 0.12), 1.5)
		"fire_trap":
			for fx in [-8.0, 0.0, 8.0]:
				draw_colored_polygon(PackedVector2Array([
					Vector2(fx - 5.5, 9.0), Vector2(fx + 5.5, 9.0), Vector2(fx, -11.0)]),
					Color(0.95, 0.50, 0.13))
				draw_colored_polygon(PackedVector2Array([
					Vector2(fx - 2.5, 8.0), Vector2(fx + 2.5, 8.0), Vector2(fx, -3.0)]),
					Color(1.0, 0.86, 0.32))
		"volcano_trap":
			# Always-visible AOE outline so the player sees the damage zone.
			draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48,
				Color(0.95, 0.45, 0.15, 0.22), 1.5)
			# Expanding shock-wave ring during an eruption.
			if _erupt_flash > 0.0:
				var t := 1.0 - _erupt_flash / ERUPT_FLASH
				var r := reach * (0.25 + 0.75 * t)
				draw_circle(Vector2.ZERO, r,
					Color(1.0, 0.55, 0.15, 0.18 * (1.0 - t)))
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 48,
					Color(1.0, 0.65, 0.20, 1.0 - t), 2.5)
			# Mountain, lava-filled crater, plume.
			draw_colored_polygon(PackedVector2Array([
				Vector2(-13, 12), Vector2(13, 12), Vector2(6, -4), Vector2(-6, -4)]),
				Color(0.42, 0.30, 0.24))
			draw_line(Vector2(-6, -4), Vector2(6, -4), Color(0.18, 0.12, 0.10), 2.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5, -4), Vector2(5, -4), Vector2(2, -10), Vector2(-2, -10)]),
				Color(0.95, 0.45, 0.10))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-2.5, -10), Vector2(2.5, -10), Vector2(0, -14)]),
				Color(1.0, 0.85, 0.30))
			draw_circle(Vector2(4, 1), 1.6, Color(0.95, 0.50, 0.15))
			draw_circle(Vector2(-3, 4), 1.4, Color(0.95, 0.50, 0.15))
	draw_string(ThemeDB.fallback_font, Vector2(-6.0, 16.0), str(level),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.92))
	if selected:
		draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), Color(1, 1, 1, 0.7), false, 2.0)
