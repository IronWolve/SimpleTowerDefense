class_name WaveManager
extends Node
## Endless waves. Each "Send Wave" press adds a concurrent spawn job.
## Every 10th wave is a boss wave; the run only ends when lives reach zero.
## When everything is cleared, a countdown auto-starts the next wave.

const ENEMY_CAP := 40
const COUNTDOWN := 10.0
const BOSS_COUNTDOWN := 30.0
## Inter-wave timer when the round-timer option is on (non-boss rounds).
const LONG_COUNTDOWN := 30.0

## Enemy archetypes that mix into normal waves (boss waves spawn their own).
## hp / spd / reward are multipliers on the wave's base stats. The "weight"
## here is only the fallback; per-wave deploy styles override it (see STYLES).
const ENEMY_TYPES := [
	{"hp": 1.0, "spd": 1.0, "reward": 1.0, "resist": {},
		"color": Color(0.90, 0.35, 0.35), "radius": 11.0, "weight": 6,
		"shape": "circle", "name": "Grunt", "desc": "balanced"},
	{"hp": 0.5, "spd": 1.95, "reward": 1.0, "resist": {"poison": 0.35},
		"color": Color(0.95, 0.85, 0.30), "radius": 9.0, "weight": 3,
		"shape": "triangle", "name": "Runner", "desc": "fast"},
	{"hp": 3.4, "spd": 0.55, "reward": 2.4, "resist": {"fire": 0.35},
		"color": Color(0.62, 0.40, 0.22), "radius": 15.0, "weight": 2,
		"shape": "hexagon", "name": "Tank", "desc": "slow & tough"},
]

## Deploy styles rotate one-per-wave so consecutive waves never feel identical.
## weights = [grunt, runner, tank] composition bias; interval_mult scales the
## base spacing; jitter randomizes each gap; cluster spawns N same-type enemies
## per tick (recognizable packs). Total enemy count is unchanged across styles,
## so gold income and overall threat track the same curve - only texture moves.
const STYLES := [
	{"key": "steady", "name": "Steady", "weights": [6, 3, 2],
		"interval_mult": 1.0, "jitter": [0.6, 1.5], "cluster": [1, 1]},
	{"key": "swarm", "name": "Swarm", "weights": [2, 9, 1],
		"interval_mult": 0.55, "jitter": [0.5, 1.1], "cluster": [2, 4]},
	{"key": "heavy", "name": "Heavy", "weights": [3, 1, 7],
		"interval_mult": 1.6, "jitter": [0.7, 1.4], "cluster": [1, 2]},
	{"key": "squads", "name": "Squads", "weights": [4, 4, 3],
		"interval_mult": 1.25, "jitter": [0.85, 1.25], "cluster": [2, 4]},
]

var level: Level
var auto_advance := true

var _started := 0
var _jobs: Array = []
var _countdown := -1.0
var _bonus_lives_through := 0

func waves_started() -> int:
	return _started

func next_is_boss() -> bool:
	return _boss_count(_started + 1) > 0

## Beetle/spider boss count. Boss waves land on 5, 15, 25, ... and the count
## ramps 1, 2, 3 then +2 each wave: 5->1  15->2  25->3  35->5  45->7 ...
## These all share the standard boss stats and are drawn as a random mix of
## beetles and spiders.
func _boss_count(w: int) -> int:
	if w % 10 != 5:
		return 0
	var n := (w - 5) / 10  # 0, 1, 2, 3, ...
	if n <= 2:
		return n + 1
	return 3 + 2 * (n - 2)

## Scorpion boss count: one on the first boss wave, +1 every boss wave after.
## Scorpions are slower and tankier than the standard bosses (see _scorpion_def).
func _scorpion_count(w: int) -> int:
	if w % 10 != 5:
		return 0
	return (w - 5) / 10 + 1  # wave 5->1, 15->2, 25->3, ...

## The deploy style for wave w (rotates every wave so neighbors always differ).
func _style_for(w: int) -> Dictionary:
	return STYLES[(w - 1) % STYLES.size()]

## Stats of the wave that the next "Start Wave" press will launch.
func next_wave_def() -> Dictionary:
	return _build_def(_started + 1)

## Seconds until the next wave auto-starts, or -1 when no countdown is running.
func countdown_remaining() -> float:
	return _countdown

## Gold the player would earn by pressing Send Wave right now (0 if none).
## The reward grows +2% per wave (linear, uncapped), so late rounds give a
## proportionally larger send-early payout.
func send_bonus() -> int:
	if GameState.round_timer_bonus and _countdown > 0.0 and not next_is_boss():
		var mult := 1.0 + 0.02 * _started
		return int(ceil(_countdown) * mult)
	return 0

func can_start_wave() -> bool:
	return not GameState.game_over and level != null and level.has_path()

func start_next_wave() -> void:
	if not can_start_wave():
		return
	# Reward sending a non-boss wave early - scaled bonus from send_bonus().
	var bonus := send_bonus()
	if bonus > 0:
		GameState.add_gold(bonus)
	_started += 1
	GameState.wave = _started
	var def := _build_def(_started)
	# The normal styled wave always spawns (even on boss waves).
	_jobs.append({
		"kind": "normal", "remaining": def["count"],
		"interval": def["interval"], "timer": 0.0, "def": def,
	})
	# Boss waves layer their bosses on concurrent, randomly-paced timelines:
	# a beetle/spider group plus a slower, tankier scorpion group.
	if def["boss_count"] > 0:
		_jobs.append({
			"kind": "boss", "remaining": def["boss_count"],
			"timer": randf_range(1.0, 5.0), "def": _boss_def(_started),
		})
	if def["scorpion_count"] > 0:
		_jobs.append({
			"kind": "scorpion", "remaining": def["scorpion_count"],
			"timer": randf_range(1.0, 5.0), "def": _scorpion_def(_started),
		})
	# The countdown to the NEXT wave begins as soon as this wave starts.
	_countdown = _initial_countdown()
	Events.wave_changed.emit(_started)

func _build_def(w: int) -> Dictionary:
	var hp := 20.0 + (w - 1) * 18.0
	var spd := minf(135.0, 52.0 + (w - 1) * 3.5)
	var count := mini(ENEMY_CAP, 6 + w * 2)
	var reward := 3 + int(w / 3.0)
	var base_interval := maxf(0.30, 0.85 - (w - 1) * 0.03)
	var s := _style_for(w)
	return {
		"hp": hp, "spd": spd, "count": count, "reward": reward,
		"interval": base_interval * float(s["interval_mult"]),
		"weights": s["weights"], "jitter": s["jitter"], "cluster": s["cluster"],
		"style_name": s["name"], "color": Color(0.90, 0.35, 0.35), "radius": 11.0,
		"boss_count": _boss_count(w), "scorpion_count": _scorpion_count(w),
	}

## Standard boss stats for wave w (beetles & spiders share these). HP trimmed
## (4.0 + w/10, was 6.0) since bosses now arrive alongside a full normal wave.
func _boss_def(w: int) -> Dictionary:
	var hp := (20.0 + (w - 1) * 18.0) * (4.0 + float(w) / 10.0)
	var spd := minf(95.0, minf(135.0, 52.0 + (w - 1) * 3.5) * 0.7)
	var reward := (3 + int(w / 3.0)) * 6
	return {"hp": hp, "spd": spd, "reward": reward,
		"color": Color(0.85, 0.20, 0.20), "radius": 22.0}

## Scorpion stats: slower (60% of boss speed) and tankier, getting tankier each
## boss level (x1.5 at wave 5, +0.2x each boss wave). Reward scales with HP.
func _scorpion_def(w: int) -> Dictionary:
	var base: Dictionary = _boss_def(w)
	var n := (w - 5) / 10  # 0, 1, 2, ...
	var tank := 1.5 + 0.2 * n
	return {
		"hp": base["hp"] * tank,
		"spd": base["spd"] * 0.6,
		"reward": int(round(base["reward"] * tank)),
		"color": Color(0.80, 0.45, 0.12), "radius": 24.0,
	}

func _process(delta: float) -> void:
	if GameState.game_over:
		return
	var i := 0
	while i < _jobs.size():
		var job: Dictionary = _jobs[i]
		job["timer"] -= delta
		if job["timer"] <= 0.0:
			if job["kind"] == "boss" or job["kind"] == "scorpion":
				var k := mini(job["remaining"], randi_range(1, 3))
				for _j in range(k):
					if job["kind"] == "scorpion":
						_spawn_boss(job["def"], "scorpion")
					else:
						# Beetles and spiders are a random mix, same stats.
						_spawn_boss(job["def"],
							"spider" if randf() < 0.5 else "beetle")
				job["remaining"] -= k
				job["timer"] = randf_range(1.0, 5.0)
			else:
				var def: Dictionary = job["def"]
				var ti := _pick_type(def["weights"])
				var cmin: int = def["cluster"][0]
				var cmax: int = def["cluster"][1]
				var cl := mini(job["remaining"], randi_range(cmin, cmax))
				for _j in range(cl):
					_spawn_normal(def, ti)
				job["remaining"] -= cl
				var jit: Array = def["jitter"]
				job["timer"] = float(def["interval"]) \
					* randf_range(float(jit[0]), float(jit[1]))
			if job["remaining"] <= 0:
				_jobs.remove_at(i)
				continue
		i += 1
	var cleared := _jobs.is_empty() \
		and get_tree().get_nodes_in_group("enemies").is_empty()
	_check_wave_bonus(cleared)
	_tick_countdown(delta, cleared)

## Grants lives per wave cleared, scaling with the wave number (when enabled).
func _check_wave_bonus(cleared: bool) -> void:
	if cleared and _started > _bonus_lives_through:
		if GameState.bonus_lives_per_wave:
			var gained := 0
			for w in range(_bonus_lives_through + 1, _started + 1):
				gained += w
			GameState.add_lives(gained)
		_bonus_lives_through = _started

func _tick_countdown(delta: float, _cleared: bool) -> void:
	if _countdown <= 0.0:
		return
	_countdown -= delta
	if _countdown > 0.0:
		return
	_countdown = 0.0
	if auto_advance:
		start_next_wave()

## How long the current wave runs solo before the next wave layers on top.
## Boss waves get the longer boss timer regardless of the round-timer option.
func _initial_countdown() -> float:
	if _boss_count(_started) > 0:
		return BOSS_COUNTDOWN
	if GameState.round_timer_bonus:
		return LONG_COUNTDOWN
	return COUNTDOWN

func _spawn_normal(def: Dictionary, type_index: int) -> void:
	var e := Enemy.new()
	level.enemies.add_child(e)
	var t: Dictionary = ENEMY_TYPES[type_index]
	e.resist = t["resist"]
	e.shape = t["shape"]
	e.setup(level, def["hp"] * t["hp"], minf(175.0, def["spd"] * t["spd"]),
		int(round(def["reward"] * t["reward"])), t["color"], t["radius"])

func _spawn_boss(bdef: Dictionary, kind: String) -> void:
	var e := Enemy.new()
	level.enemies.add_child(e)
	e.is_boss = true
	e.boss_kind = kind
	e.setup(level, bdef["hp"], bdef["spd"], bdef["reward"], bdef["color"], bdef["radius"])

## Weighted pick over [grunt, runner, tank] for the given style weights.
func _pick_type(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return 0
	var r := randi() % total
	for i in range(weights.size()):
		r -= int(weights[i])
		if r < 0:
			return i
	return 0
