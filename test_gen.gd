extends SceneTree
## Regression test for level.gd generated-map invariants. Run after ANY
## change to _build_generated_map, _generate_blocked, _warnsdorff, or the
## backbite functions.
##
## Run: cd <project> && godot4 --headless --script test_gen.gd
##
## What it checks per (board_size x zigzag_flag) trial:
##   - _generate_blocked succeeds (or falls back to hamiltonian/serpentine)
##   - spawn -> base is BFS-reachable through the produced grid
##   - prints two sample maps as ASCII so you can eyeball the path style
##
## Reads any saw / staircase patterns visually from the ASCII output -
## the "max_streak" / "stair3" counters under-report because they work at
## CELL granularity and our lattice is 2-spaced. Trust your eyes on the
## sample dumps, not the integers.
##
## This file lives in the repo root (not scripts/) so it doesn't get
## pulled into a build. It's a dev tool, not gameplay code.

func _initialize() -> void:
	var Level := load("res://scripts/level.gd")
	var sz := {"name": "Huge", "cols": 64, "rows": 30}
	# Wider seed pool, zigzag off.
	var seeds := [11, 22, 33, 44, 55, 66, 77, 88, 99, 111, 222, 333]
	for zz in [false]:
		var totals := {"trials": 0, "any_3plus": 0, "any_5plus": 0,
			"max_streak_sum": 0, "stair_count_sum": 0}
		var samples: Array = []  # save a couple to print
		for s in seeds:
			var level = Level.new()
			level.COLS = sz["cols"]
			level.ROWS = sz["rows"]
			seed(s)
			level._path_zigzag = zz
			var grid: Array = []
			for _r in range(12):
				grid = level._generate_blocked()
				if not grid.is_empty():
					break
			# Set up spawn/base so the BFS flip-validator knows the endpoints,
			# then apply the corner-flip post-process directly.
			if not grid.is_empty():
				level.spawn_cell = Vector2i(0, level.ROWS / 2)
				level.base_cell = Vector2i(level.COLS - 1, level.ROWS / 2)
				# Match what _generate_blocked sets for spawn/base
				# (path[0] = right edge, path[end] = left edge after end-steering)
				for r in range(level.ROWS):
					if grid[r][0] == 0:
						level.spawn_cell = Vector2i(0, r)
						break
				for r in range(level.ROWS):
					if grid[r][level.COLS - 1] == 0:
						level.base_cell = Vector2i(level.COLS - 1, r)
						break
				level._flip_block_corners(grid)
			if grid.is_empty():
				continue
			# Reconstruct the path by walking cells - flood-fill from spawn
			# only along single-cell-wide corridors so we get the path order.
			var path := _trace_path(grid, level.spawn_cell, level.base_cell)
			var streaks := _count_turn_streaks(path)
			var max_streak := 0
			var stair3 := 0
			var stair5 := 0
			for st in streaks:
				if st >= 3:
					stair3 += 1
				if st >= 5:
					stair5 += 1
				if st > max_streak:
					max_streak = st
			totals["trials"] += 1
			if stair3 > 0:
				totals["any_3plus"] += 1
			if stair5 > 0:
				totals["any_5plus"] += 1
			totals["max_streak_sum"] += max_streak
			totals["stair_count_sum"] += stair3
			samples.append({"seed": s, "grid": grid, "level": level,
				"path_len": path.size(), "max_streak": max_streak,
				"stair3": stair3, "stair5": stair5})
		print("=== zigzag=%s ===" % ("YES" if zz else "no "))
		print("trials=%d  any 3+ stairs: %d/%d  any 5+ stairs: %d/%d  avg max-streak: %.1f  avg stair3 count: %.1f" %
			[totals["trials"], totals["any_3plus"], totals["trials"],
			totals["any_5plus"], totals["trials"],
			float(totals["max_streak_sum"]) / maxf(1.0, float(totals["trials"])),
			float(totals["stair_count_sum"]) / maxf(1.0, float(totals["trials"]))])
		# Print first 4 samples (Huge maps are big - 30 rows x 64 cols each).
		for k in range(mini(4, samples.size())):
			var s = samples[k]
			print("--- sample seed=%d path_len=%d max_streak=%d stair3=%d stair5=%d ---" %
				[s["seed"], s["path_len"], s["max_streak"], s["stair3"], s["stair5"]])
			_print_grid(s["grid"], s["level"].spawn_cell, s["level"].base_cell, s["level"])
		print()
	quit()

## Walk the grid as a graph (path cells = 0) and reconstruct the unique
## spawn->base route since it's single-cell wide (each path cell has at
## most 2 path neighbours, so BFS-with-parent gives us the order).
func _trace_path(grid: Array, spawn: Vector2i, base: Vector2i) -> Array:
	var rows := grid.size()
	var cols: int = grid[0].size()
	if grid[spawn.y][spawn.x] != 0 or grid[base.y][base.x] != 0:
		return []
	var parent := {spawn: spawn}
	var queue: Array[Vector2i] = [spawn]
	var qi := 0
	var found := false
	while qi < queue.size() and not found:
		var cur: Vector2i = queue[qi]
		qi += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if nb.x < 0 or nb.x >= cols or nb.y < 0 or nb.y >= rows:
				continue
			if grid[nb.y][nb.x] != 0 or parent.has(nb):
				continue
			parent[nb] = cur
			if nb == base:
				found = true
				break
			queue.append(nb)
	if not found:
		return []
	var route: Array = []
	var c: Vector2i = base
	route.append(c)
	while c != spawn:
		c = parent[c]
		route.append(c)
	route.reverse()
	return route

## For each consecutive pair in the path, classify the move as H or V.
## A "turn streak" is a run of K consecutive moves where each one is on
## a different axis from the previous (so direction alternates).
func _count_turn_streaks(path: Array) -> Array:
	if path.size() < 3:
		return []
	var moves: Array = []
	for i in range(1, path.size()):
		var dx: int = path[i].x - path[i - 1].x
		moves.append(0 if dx == 0 else 1)  # 0=vertical, 1=horizontal
	var streaks: Array = []
	var streak := 1
	for i in range(1, moves.size()):
		if moves[i] != moves[i - 1]:
			streak += 1
		else:
			if streak >= 2:
				streaks.append(streak)
			streak = 1
	if streak >= 2:
		streaks.append(streak)
	return streaks

func _print_grid(grid: Array, spawn: Vector2i, base: Vector2i, level) -> void:
	var blocks := {}
	for n in level._ham_blocked:
		var bc: Vector2i = level._hcell(n)
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				blocks[Vector2i(bc.x + dc, bc.y + dr)] = true
	for r in range(grid.size()):
		var line := ""
		for c in range(grid[r].size()):
			var p := Vector2i(c, r)
			if p == spawn:
				line += "S"
			elif p == base:
				line += "B"
			elif grid[r][c] == 1:
				line += "@" if blocks.has(p) else "#"
			else:
				line += "."
		print(line)
