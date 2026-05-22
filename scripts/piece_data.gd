class_name PieceData
extends RefCounted
## Static config table for all placeable pieces. Never instantiated.

const TYPES := {
	"wall": {
		"name": "Wall", "short": "Wall", "category": "wall", "mode": "",
		"cost": 10, "stock_key": "wall", "blocks": true,
		"color": Color(0.46, 0.46, 0.52),
		"range": 0.0, "fire_rate": 0.0, "damage": 0.0,
		"bullet_color": Color.WHITE, "slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"tower": {
		"name": "Bullet Tower", "short": "Bullet", "category": "tower", "mode": "shot",
		"cost": 40, "stock_key": "tower", "blocks": true,
		"color": Color(0.28, 0.52, 1.0),
		"range": 150.0, "fire_rate": 1.0, "damage": 13.0,
		"bullet_color": Color(0.45, 0.68, 1.0), "slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"laser": {
		"name": "Laser Tower", "short": "Laser", "category": "tower", "mode": "beam",
		"cost": 200, "stock_key": "", "blocks": true,
		"color": Color(0.88, 0.20, 0.20),
		"range": 165.0, "fire_rate": 1.0, "damage": 34.0,
		"bullet_color": Color(1.0, 0.45, 0.40), "slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"ice": {
		"name": "Ice Tower", "short": "Ice", "category": "tower", "mode": "slow",
		"cost": 80, "stock_key": "", "blocks": true,
		"color": Color(0.40, 0.80, 0.96),
		"range": 138.0, "fire_rate": 0.6, "damage": 6.0,
		"bullet_color": Color(0.72, 0.95, 1.0), "slow": 0.05, "slow_time": 2.6, "aoe_radius": 0.0,
	},
	"cannon": {
		"name": "Cannon Tower", "short": "Cannon", "category": "tower", "mode": "shot",
		"cost": 200, "stock_key": "", "blocks": true,
		"color": Color(0.95, 0.55, 0.20),
		"range": 145.0, "fire_rate": 0.75, "damage": 24.0,
		"bullet_color": Color(1.0, 0.72, 0.32), "slow": 0.0, "slow_time": 0.0, "aoe_radius": 56.0,
	},
	"sniper": {
		"name": "Sniper Tower", "short": "Sniper", "category": "tower", "mode": "shot",
		"cost": 400, "stock_key": "", "blocks": true,
		"color": Color(0.25, 0.35, 0.78),
		"range": 230.0, "fire_rate": 1.0, "damage": 140.0,
		"bullet_color": Color(0.65, 0.80, 1.0), "slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"missile": {
		"name": "Missile Tower", "short": "Missile", "category": "tower", "mode": "shot",
		"cost": 400, "stock_key": "", "blocks": true,
		"color": Color(0.30, 0.72, 0.32),
		"range": 205.0, "fire_rate": 1.0, "damage": 52.0,
		"bullet_color": Color(1.0, 0.62, 0.30), "slow": 0.0, "slow_time": 0.0, "aoe_radius": 82.0,
	},
	"gold": {
		"name": "Gold Mine", "short": "Gold", "category": "tower", "mode": "support",
		"cost": 60, "stock_key": "", "blocks": true,
		"color": Color(0.95, 0.80, 0.20),
		"range": 0.0, "fire_rate": 0.0, "damage": 0.0,
		"bullet_color": Color.WHITE, "slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"amplifier": {
		"name": "Amplifier", "short": "Amp", "category": "tower", "mode": "support",
		"cost": 80, "stock_key": "", "blocks": true,
		"color": Color(0.80, 0.82, 0.86),
		"range": 0.0, "fire_rate": 0.0, "damage": 0.0,
		"bullet_color": Color.WHITE, "slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"tar_trap": {
		"name": "Tar Trap", "short": "Tar", "category": "trap", "mode": "",
		"cost": 40, "stock_key": "", "blocks": false,
		"color": Color(0.22, 0.22, 0.18),
		"range": 0.0, "fire_rate": 0.0, "damage": 3.0,
		"bullet_color": Color.WHITE, "slow": 0.05, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"spike_trap": {
		"name": "Spike Trap", "short": "Spike", "category": "trap", "mode": "",
		"cost": 45, "stock_key": "", "blocks": false,
		"color": Color(0.22, 0.22, 0.18),
		"range": 0.0, "fire_rate": 0.0, "damage": 1.0,
		"bullet_color": Color.WHITE, "slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"poison_trap": {
		"name": "Poison Trap", "short": "Poison", "category": "trap", "mode": "",
		"cost": 50, "stock_key": "", "blocks": false,
		"color": Color(0.18, 0.26, 0.15),
		"range": 0.0, "fire_rate": 0.0, "damage": 8.0,
		"bullet_color": Color.WHITE, "slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"fire_trap": {
		"name": "Fire Trap", "short": "Fire", "category": "trap", "mode": "",
		"cost": 55, "stock_key": "", "blocks": false,
		"color": Color(0.27, 0.16, 0.13),
		"range": 0.0, "fire_rate": 0.0, "damage": 15.0,
		"bullet_color": Color.WHITE, "slow": 0.0, "slow_time": 0.0, "aoe_radius": 0.0,
	},
	"volcano_trap": {
		"name": "Volcano Trap", "short": "Volcano", "category": "trap", "mode": "",
		"cost": 100, "stock_key": "", "blocks": false,
		"color": Color(0.30, 0.16, 0.14),
		"range": 0.0, "fire_rate": 0.0, "damage": 19.0,
		"bullet_color": Color.WHITE, "slow": 0.0, "slow_time": 0.0, "aoe_radius": 60.0,
	},
}

## Per-level fraction the support towers grant: Gold Mine adds this much to
## kill gold, Amplifier adds this much damage to each adjacent tower (0.5%/lvl).
const SUPPORT_PCT_PER_LEVEL := 0.005

static func data(type: String) -> Dictionary:
	return TYPES[type]

static func cost(type: String) -> int:
	return TYPES[type]["cost"]

static func category(type: String) -> String:
	return TYPES[type]["category"]

## Effective stats for a tower at a given level (level 1 == base). Uncapped.
## Damage uses polynomial scaling plus a global +15% and +10% boost (cannon
## additionally +5%). Range grows linearly +15/level (25% less than before).
## Fire rate has per-type rules so each tower upgrades distinctly.
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
	# Range bonus per level reduced 25% (was +20, now +15).
	d["range"] = d["range"] + 15.0 * n
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
	# Slow strength: scales +6% per level, cap 85%. (Ice base 5% reaches the
	# cap by L15, so upgrades feel meaningful immediately.)
	if d["slow"] > 0.0:
		d["slow"] = minf(0.85, d["slow"] + 0.06 * n)
	# Slow duration: +1s per level (replaces old 30% bump + 0.7s scaling).
	if d["slow_time"] > 0.0:
		d["slow_time"] = d["slow_time"] + 1.0 * n
	# AOE radius (Cannon / Missile): grows with level as before.
	if d["aoe_radius"] > 0.0:
		d["aoe_radius"] = d["aoe_radius"] + 5.0 * n
	return d

## Effective stats for a trap at a given level (level 1 == base).
## Spike has its own linear damage scaling that tracks ~5% of wave-N enemy HP.
## Tar caps at 95% slow. Volcano's AOE radius never grows past its base.
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
		if type == "tar_trap":
			# Base 5%, +10%/level, capped 90% (reaches the cap at level 10).
			d["slow"] = minf(0.90, d["slow"] + 0.10 * n)
		else:
			d["slow"] = minf(0.85, d["slow"] + 0.05 * n)
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
