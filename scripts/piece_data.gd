class_name PieceData
extends RefCounted
## Static config table for all placeable pieces. Never instantiated.

const TYPES := {
	"wall": {
		"name": "Wall", "short": "Wall", "category": "wall", "mode": "",
		"cost": 10, "stock_key": "wall", "blocks": true,
		"color": Color(0.46, 0.46, 0.52),
		"range": 0.0, "fire_rate": 0.0, "damage": 0.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"tower": {
		"name": "Bullet Tower", "short": "Bullet", "category": "tower", "mode": "shot",
		"cost": 40, "stock_key": "tower", "blocks": true,
		"color": Color(0.28, 0.52, 1.0),
		"range": 75.0, "fire_rate": 1.0, "damage": 13.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"laser": {
		"name": "Laser Tower", "short": "Laser", "category": "tower", "mode": "beam",
		"cost": 200, "stock_key": "", "blocks": true,
		"color": Color(0.88, 0.20, 0.20),
		"range": 82.5, "fire_rate": 1.0, "damage": 34.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"ice": {
		"name": "Ice Tower", "short": "Ice", "category": "tower", "mode": "slow",
		"cost": 80, "stock_key": "", "blocks": true,
		"color": Color(0.40, 0.80, 0.96),
		"range": 69.0, "fire_rate": 0.6, "damage": 6.0,
		"slow": 0.05, "slow_time": 2.6, "aoe_radius": 0.0,
	},
	"cannon": {
		"name": "Cannon Tower", "short": "Cannon", "category": "tower", "mode": "shot",
		"cost": 200, "stock_key": "", "blocks": true,
		"color": Color(0.95, 0.55, 0.20),
		"range": 72.5, "fire_rate": 0.75, "damage": 24.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 56.0,
	},
	"sniper": {
		"name": "Sniper Tower", "short": "Sniper", "category": "tower", "mode": "shot",
		"cost": 400, "stock_key": "", "blocks": true,
		"color": Color(0.25, 0.35, 0.78),
		"range": 115.0, "fire_rate": 1.0, "damage": 140.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"missile": {
		"name": "Missile Tower", "short": "Missile", "category": "tower", "mode": "shot",
		"cost": 400, "stock_key": "", "blocks": true,
		"color": Color(0.30, 0.72, 0.32),
		"range": 102.5, "fire_rate": 1.0, "damage": 52.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 82.0,
	},
	"gold": {
		"name": "Gold Mine", "short": "Gold", "category": "tower", "mode": "support",
		"cost": 60, "stock_key": "", "blocks": true,
		"color": Color(0.95, 0.80, 0.20),
		"range": 0.0, "fire_rate": 0.0, "damage": 0.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"amplifier": {
		"name": "Amplifier", "short": "Amp", "category": "tower", "mode": "support",
		"cost": 80, "stock_key": "", "blocks": true,
		"color": Color(0.80, 0.82, 0.86),
		"range": 0.0, "fire_rate": 0.0, "damage": 0.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"tar_trap": {
		"name": "Tar Trap", "short": "Tar", "category": "trap", "mode": "",
		"cost": 50, "stock_key": "", "blocks": false,
		"color": Color(0.22, 0.22, 0.18),
		"range": 0.0, "fire_rate": 0.0, "damage": 0.0,
		"slow": 0.05, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"spike_trap": {
		"name": "Spike Trap", "short": "Spike", "category": "trap", "mode": "",
		"cost": 50, "stock_key": "", "blocks": false,
		"color": Color(0.22, 0.22, 0.18),
		"range": 0.0, "fire_rate": 0.0, "damage": 1.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"poison_trap": {
		"name": "Poison Trap", "short": "Poison", "category": "trap", "mode": "",
		"cost": 50, "stock_key": "", "blocks": false,
		"color": Color(0.18, 0.26, 0.15),
		"range": 0.0, "fire_rate": 0.0, "damage": 8.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"fire_trap": {
		"name": "Fire Trap", "short": "Fire", "category": "trap", "mode": "",
		"cost": 50, "stock_key": "", "blocks": false,
		"color": Color(0.27, 0.16, 0.13),
		"range": 0.0, "fire_rate": 0.0, "damage": 15.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"volcano_trap": {
		"name": "Volcano Trap", "short": "Volcano", "category": "trap", "mode": "",
		"cost": 100, "stock_key": "", "blocks": false,
		"color": Color(0.30, 0.16, 0.14),
		"range": 0.0, "fire_rate": 0.0, "damage": 19.0,
		"slow": 0.0, "slow_time": 0.0, "aoe_radius": 60.0,
	},
}

## Per-level fraction the support towers grant: Gold Mine adds this much to
## kill gold, Amplifier adds this much damage to each adjacent tower (0.5%/lvl).
const SUPPORT_PCT_PER_LEVEL := 0.005

## Slow effect tuning, shared by Ice (tower) and Tar (trap). A slow piece's
## slow% climbs linearly from its base to SLOW_CAP, hitting the cap exactly at
## SLOW_MAX_LEVEL. An adjacent Amplifier lifts the *effective* slow further at
## runtime, up to SLOW_BOOST_CAP. Only the Amp can push a slow above SLOW_CAP.
const SLOW_CAP := 0.80
const SLOW_BOOST_CAP := 0.95
const SLOW_MAX_LEVEL := 40

## Coverage ceilings (absolute pixels, CELL = 40) so high levels / Amplifiers
## can't blanket the whole map. Range and AOE stop growing here; damage, fire
## rate and effects keep scaling. Reached at modest levels (L13-26).
const RANGE_CAP := {
	"tower": 160.0, "cannon": 180.0, "ice": 160.0,
	"laser": 200.0, "missile": 220.0, "sniper": 300.0,
}
## Splash radius ceilings (also clamps the Amplifier's AOE boost).
const AOE_CAP := {
	"cannon": 120.0, "missile": 160.0, "volcano_trap": 120.0,
}

static func data(type: String) -> Dictionary:
	return TYPES[type]

static func cost(type: String) -> int:
	return TYPES[type]["cost"]

static func category(type: String) -> String:
	return TYPES[type]["category"]

## Effective stats for a tower at a given level. The math, top to bottom:
##
##   DAMAGE
##     base * (1 + dmg_step * n) ^ dmg_exp * dmg_mult
##       where n = level - 1; dmg_step = 0.5 (sniper) else 0.4; dmg_exp = 1.4
##       dmg_mult = 1.10 * 1.05 universal, plus 1.05 * 1.05 again for cannon.
##     So damage scales polynomially, not exponentially - level 100 ≈ 70×
##     base, not 2^100× base. The cannon double-boost is its "AOE specialist
##     tax" - it costs more per shot, so it gets a bit more bang.
##
##   RANGE
##     base + 15 * (n / 2)   -- integer division. +15 every 2 levels, not
##     every level. Clamped to RANGE_CAP[type] so a maxed tower can't
##     blanket the map. Support towers (Gold/Amp, base 0) stay at 0.
##
##   FIRE RATE - per type:
##     bullet (`"tower"`): linear +0.25/level, HARD CAP at 4.0/s so damage
##                         still scales but the rate doesn't compound past it.
##     sniper, missile:    doubles every 30 levels (was 20 - softened to keep
##                         late game in line with enemy HP).
##     ice, laser, cannon: gentle linear +8%/level.
##
##   SLOW (ice & tar share this curve)
##     linear from base_slow at L1 to SLOW_CAP (0.80) at SLOW_MAX_LEVEL (40).
##     An adjacent Amplifier lifts the EFFECTIVE slow at runtime up to
##     SLOW_BOOST_CAP (0.95) - that boost is computed downstream, not here.
##
##   SLOW DURATION
##     base + 1s/level. So Ice L10 ≈ 2.6 + 9 = 11.6s.
##
##   AOE RADIUS (cannon, missile)
##     base + 5/level, clamped to AOE_CAP[type].
##
## Level 1 is unmodified base (n = 0). DON'T call with level < 1.
static func tower_stats(type: String, level: int) -> Dictionary:
	var d: Dictionary = TYPES[type].duplicate(true)
	var n := level - 1
	var dmg_step: float
	var dmg_exp: float
	if type == "sniper":
		dmg_step = 0.5
		dmg_exp = 1.4
	else:
		dmg_step = 0.4
		dmg_exp = 1.4
	# Damage: polynomial scaling * 10% boost * 5% boost (cannon keeps its
	# AOE specialist +5%/+5% on top, ~15.8% above the universal multipliers).
	var dmg_mult := 1.10 * 1.05
	if type == "cannon":
		dmg_mult *= 1.05 * 1.05
	d["damage"] = d["damage"] * pow(1.0 + dmg_step * n, dmg_exp) * dmg_mult
	# Range grows +15, but only every 2 levels now (n / 2 is integer division),
	# so it climbs half as fast. Support towers (Gold/Amp, base range 0) stay at
	# 0 so they never sprout a meaningless range circle.
	if d["range"] > 0.0:
		d["range"] = d["range"] + 15.0 * (n / 2)
		if RANGE_CAP.has(type):
			d["range"] = minf(RANGE_CAP[type], d["range"])
	# Fire rate: per-tower rules.
	if type == "tower":
		# Bullet: base + 0.25 per level, capped at 4.0/s so high levels don't
		# run away (damage still scales, but the rate stops compounding).
		d["fire_rate"] = minf(4.0, d["fire_rate"] + 0.25 * n)
	elif type == "sniper" or type == "missile":
		# Doubles every 30 levels (softened from 20 to keep late game from
		# running away geometrically past enemy HP).
		d["fire_rate"] = d["fire_rate"] * pow(2.0, int(level / 30))
	else:
		# Ice / Laser / Cannon: gentle linear scaling.
		d["fire_rate"] = d["fire_rate"] * (1.0 + 0.08 * n)
	# Slow strength climbs linearly from its base to SLOW_CAP at SLOW_MAX_LEVEL
	# (shared with Tar). An adjacent Amplifier lifts the effective slow further
	# at runtime, up to SLOW_BOOST_CAP.
	if d["slow"] > 0.0:
		var base_slow: float = d["slow"]
		var step := (SLOW_CAP - base_slow) / float(SLOW_MAX_LEVEL - 1)
		d["slow"] = minf(SLOW_CAP, base_slow + step * n)
	# Slow duration: +1s per level (replaces old 30% bump + 0.7s scaling).
	if d["slow_time"] > 0.0:
		d["slow_time"] = d["slow_time"] + 1.0 * n
	# AOE radius (Cannon / Missile): grows with level as before.
	if d["aoe_radius"] > 0.0:
		d["aoe_radius"] = d["aoe_radius"] + 5.0 * n
		if AOE_CAP.has(type):
			d["aoe_radius"] = minf(AOE_CAP[type], d["aoe_radius"])
	return d

## Effective stats for a trap at a given level. The math:
##
##   DAMAGE (poison, fire, volcano)
##     base * (1 + 0.3 * n) ^ 1.4   -- same shape as tower damage but with
##     dmg_step 0.3 instead of 0.4, so traps scale slower than towers.
##
##   SPIKE DAMAGE is a SPECIAL CASE
##     d["damage"] = 2 + 2 * n   (flat scaling, just kills early trash).
##     The real spike pain is a %-of-max-HP tick applied in
##     Trap._process_contact - that's where spikes hurt tanks and bosses
##     even when the flat damage here would be useless against their HP.
##
##   SLOW (tar) - shares the Ice curve from tower_stats: linear from base to
##     SLOW_CAP at SLOW_MAX_LEVEL. An adjacent Amplifier lifts it at runtime
##     up to SLOW_BOOST_CAP.
##
##   VOLCANO AOE RADIUS does NOT grow per level - it stays at the base
##     1-cell-around. Amplifier boosts the effective radius at runtime;
##     this static table doesn't.
##
##   DOT DURATION (poison, fire) is per-level via the trap.gd logic (+1s
##     per level for fire; +1s and +1% vuln per level for poison) - NOT
##     here. This function only returns the base table value for slow_time.
##
## Level 1 is unmodified base (n = 0). DON'T call with level < 1.
static func trap_stats(type: String, level: int) -> Dictionary:
	var d: Dictionary = TYPES[type].duplicate(true)
	var n := level - 1
	if type == "spike_trap":
		# Flat floor only (kills early trash). The real scaling is a percent of
		# the enemy's max HP, applied in Trap._process_contact so it tracks any
		# wave and hurts tanks/bosses where flat damage is worthless.
		d["damage"] = 2.0 + 2.0 * n
	else:
		d["damage"] = d["damage"] * pow(1.0 + 0.3 * n, 1.4)
	if d["slow"] > 0.0:
		# Same linear-to-SLOW_CAP curve as Ice (see tower_stats).
		var base_slow: float = d["slow"]
		var step := (SLOW_CAP - base_slow) / float(SLOW_MAX_LEVEL - 1)
		d["slow"] = minf(SLOW_CAP, base_slow + step * n)
	# Volcano radius does NOT grow per level - stays at the base 1-cell-around.
	return d

## Upgrade price. Towers use a steep triangular curve (their damage scales
## exponentially). Traps scale damage gently, so they use a cheap linear curve
## - the triangular cost was wildly out of line with the small per-level gain.
static func upgrade_cost(type: String, level: int) -> int:
	var base: float = TYPES[type]["cost"]
	if category(type) == "trap":
		return int(round(base * level))
	return int(round(base * level * (level + 1) / 2.0))
