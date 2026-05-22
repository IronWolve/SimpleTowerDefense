class_name Level
extends Node2D
## Open grid play field: placement, BFS pathfinding and rendering.

const CELL := 40
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const PLAY_W := 1280.0
const PLAY_H := 600.0
const MIN_ZOOM := 0.5
const MAX_ZOOM := 2.5
## Board dimensions in cells (COLS x ROWS) for board_size 0/1/2.
const BOARD_SIZES: Array[Vector2i] = [
	Vector2i(32, 15), Vector2i(46, 22), Vector2i(64, 30),
]

var COLS := 32
var ROWS := 15
var spawn_cell := Vector2i(0, 7)
var base_cell := Vector2i(31, 7)
var _zoom := 1.0
var _min_zoom := 1.0

var traps: Node2D
var walls: Node2D
var towers: Node2D
var enemies: Node2D
var bullets: Node2D
var hud: HUD
var _overlay: BuildOverlay

var _pieces := {}
## Walls tucked under a tower in the same cell. They stay visible (the tower
## sits on top via z-ordering) and resurface to _pieces when the tower sells.
var _under_walls := {}
## Undo stack: each element is an Array of entries comprising one user action.
## Single placements/sells push a 1-entry array; drags and Alt-x10 upgrades
## bundle every internal step into one group so a single Z reverses them all.
const UNDO_MAX := 50
var _undo_stack: Array = []
var _open_group: Array = []
var _group_open := false
var _preview: Array[Vector2i] = []
var _selected: Structure = null
var _hover_cell := Vector2i(-1, -1)
var _hover_ok := false
var _show_hover := false
var _flash_cell := Vector2i(-1, -1)
var _flash_until := 0
var _hover_check_ms := 0
## Manual mouse-button state, driven by press/release events. Browsers report
## an unreliable `event.button_mask` during motion, so we track it ourselves.
var _left_held := false
var _right_held := false
var _middle_held := false
## Cell where the current wall-drag started; used when Alt is held to draw a
## straight line from that cell to the cursor along the dominant axis.
var _drag_start_cell := Vector2i(-1, -1)
## Coalesced path-recompute: set true to request a single sweep next frame.
var _paths_dirty := false
## Per-frame spatial bucketing of enemies. Updated once in `_process`.
## Keyed by Vector2i bucket coord; each value is an Array[Enemy].
const BUCKET_SIZE := 160  # 4 cells per bucket
var _enemy_buckets: Dictionary = {}

func _ready() -> void:
	var dim: Vector2i = BOARD_SIZES[clampi(GameState.board_size, 0, BOARD_SIZES.size() - 1)]
	COLS = dim.x
	ROWS = dim.y
	spawn_cell = Vector2i(0, ROWS / 2)
	base_cell = Vector2i(COLS - 1, ROWS / 2)
	traps = _make_container("Traps")
	walls = _make_container("Walls")
	towers = _make_container("Towers")
	enemies = _make_container("Enemies")
	bullets = _make_container("Bullets")
	_overlay = BuildOverlay.new()
	_overlay.name = "BuildOverlay"
	_overlay.level = self
	add_child(_overlay)
	Events.piece_selected.connect(_on_piece_selected)
	if not GameState.pending_load.is_empty():
		# Resuming a saved run: rebuild the exact board from the snapshot's pieces
		# (which include map walls) instead of generating a fresh map, then put
		# every saved enemy back exactly where it was.
		_load_pieces(GameState.pending_load)
		_load_enemies(GameState.pending_load)
	else:
		match GameState.map_type:
			"spiral":
				_build_spiral()
			"generate":
				_build_generated_map()
			_:
				if GameState.map_type.begins_with("custom:"):
					_build_custom_map(GameState.map_type.substr(7))
	_setup_zoom()
	_update_preview()

## Stamps a saved 0/1 wall grid from `user://maps/<name>.txt`.
## If the saved grid was built for a different board size, refuses to apply
## it (would silently truncate / leave gaps) and reports via the HUD toast.
func _build_custom_map(map_name: String) -> void:
	var grid: Array = GameState.load_map_grid(map_name)
	if grid.size() != ROWS or (grid.size() > 0 and grid[0].length() != COLS):
		var msg := "Custom map \"%s\" was %dx%d, current board is %dx%d - not loaded" % [
			map_name,
			grid[0].length() if grid.size() > 0 else 0,
			grid.size(), COLS, ROWS]
		push_warning(msg)
		if hud != null and hud.has_method("show_toast"):
			hud.show_toast(msg, 4.5)
		return
	for r in range(ROWS):
		var line: String = grid[r]
		for c in range(COLS):
			# Guard against ragged rows: the size check above only validates the
			# first row's width, so a short later row would index out of bounds.
			# A missing char counts as "0" (open).
			if c < line.length() and line[c] == "1":
				_place_map_wall(Vector2i(c, r))

## Alt-click bulk upgrade: tries to upgrade the structure up to 10 times,
## stopping early when can_upgrade() goes false or gold runs out.
func _alt_upgrade_ten(s: Structure) -> void:
	_bulk_upgrade(s, 10)

## Upgrade a piece up to `limit` times, stopping when it can't upgrade further
## or gold runs out. `limit` also guards against runaway loops (e.g. unlimited
## money on a level-uncapped tower).
func _bulk_upgrade(s: Structure, limit: int) -> void:
	_begin_group()
	var done := 0
	while done < limit and s.can_upgrade():
		var cost: int = s.upgrade_cost()
		if not GameState.spend(cost):
			break
		var refund := 0 if GameState.unlimited_money else cost
		_record_action({"k": "upgrade", "cell": s.cell, "cost": refund})
		s.do_upgrade()
		done += 1
	_end_group()
	if done > 0 and hud != null:
		hud._show_structure_info(s)
		if s.type == "gold" or s.type == "amplifier":  # gold-enhanced total may change
			hud._update_wave_info()

## Spend all available gold upgrading the currently-selected tower/trap (bound
## to Q in the HUD). Stops at the piece's level cap or when gold runs out.
func max_upgrade_selected() -> void:
	var s := _selected
	if s == null or not is_instance_valid(s) or not (s is Tower or s is Trap):
		if hud != null:
			hud.show_toast("Select a tower or trap first", 2.0)
		return
	if not s.can_upgrade():
		if hud != null:
			hud.show_toast("%s is already maxed" % s.display_name(), 2.0)
		return
	var limit := 100 if GameState.unlimited_money else 100000
	var before := GameState.gold
	_bulk_upgrade(s, limit)
	if hud != null:
		var spent := before - GameState.gold
		if spent > 0:
			hud.show_toast("Max upgrade: spent $%s" % GameState.abbrev(spent), 2.0)
		elif GameState.unlimited_money:
			hud.show_toast("Max upgrade", 1.5)
		else:
			hud.show_toast("Not enough gold to upgrade", 2.0)

## Returns the current wall layout as 0/1 strings, one per row.
## Towers and traps are ignored - this captures the map structure only.
func dump_walls_grid() -> Array[String]:
	var grid: Array[String] = []
	for r in range(ROWS):
		var line := ""
		for c in range(COLS):
			var k := Vector2i(c, r)
			var p: Structure = _pieces.get(k)
			var has_wall: bool = p is Wall or _under_walls.has(k)
			line += "1" if has_wall else "0"
		grid.append(line)
	return grid

## Snapshot the whole run for save/load: board, every placed piece, economy,
## wave state (incl. in-flight spawn jobs) and every live enemy. In-flight
## bullets are intentionally skipped (they re-fire instantly).
func serialize_run() -> Dictionary:
	var wm: WaveManager = hud.wave_manager if hud != null else null
	var pieces: Array = []
	for cell in _pieces:
		var s: Structure = _pieces[cell]
		if s == null:
			continue
		pieces.append({
			"t": s.type, "x": cell.x, "y": cell.y,
			"lvl": s.level, "inv": s.gold_invested, "stock": s.from_stock,
			"under": _under_walls.has(cell),
		})
	var ens: Array = []
	for node in enemies.get_children():
		var e := node as Enemy
		if e != null and e.is_alive():
			ens.append(e.serialize())
	return {
		"v": 2,
		"board_size": GameState.board_size,
		"spawn": [spawn_cell.x, spawn_cell.y],
		"base": [base_cell.x, base_cell.y],
		"gold": GameState.gold, "lives": GameState.lives,
		"wave": GameState.wave, "score": GameState.score,
		"stock": {"wall": GameState.stock_of("wall"), "tower": GameState.stock_of("tower")},
		"wave_state": wm.serialize() if wm != null else {},
		"enemies": ens,
		"pieces": pieces,
	}

## Recreate every saved enemy at its exact state. Called on load after the board
## is rebuilt (so their stored paths are valid against the same layout).
func _load_enemies(data: Dictionary) -> void:
	for ed in data.get("enemies", []):
		var e := Enemy.new()
		enemies.add_child(e)
		e.restore(self, ed)

## Write the auto-save slot (called by WaveManager on each wave clear).
func autosave() -> void:
	GameState.write_save("auto", serialize_run())

## Rebuild the board from a save snapshot: place every piece at its cell/level,
## restore tucked-under walls, set spawn/base, then recompute paths.
func _load_pieces(data: Dictionary) -> void:
	var sp: Array = data.get("spawn", [0, ROWS / 2])
	var bs: Array = data.get("base", [COLS - 1, ROWS / 2])
	spawn_cell = Vector2i(int(sp[0]), int(sp[1]))
	base_cell = Vector2i(int(bs[0]), int(bs[1]))
	for pd in data.get("pieces", []):
		var t: String = pd.get("t", "")
		if not PieceData.TYPES.has(t):
			continue
		var c := Vector2i(int(pd.get("x", 0)), int(pd.get("y", 0)))
		# A tower saved sitting on a wall: restore the wall underneath first.
		if bool(pd.get("under", false)) and PieceData.category(t) == "tower":
			var w := Wall.new()
			w.position = cell_center(c)
			w.cell = c
			walls.add_child(w)
			w.setup_piece("wall", self, true)
			_under_walls[c] = w
		var s := _make_piece(t)
		s.position = cell_center(c)
		s.cell = c
		_container_for(t).add_child(s)
		s.setup_piece(t, self, bool(pd.get("stock", false)))
		s.level = int(pd.get("lvl", 1))
		s.gold_invested = int(pd.get("inv", 0))
		s._apply_stats()
		s.queue_redraw()
		_pieces[c] = s
	_recompute_paths_now()

## Drop one wall at a cell, skipping spawn / base / already-occupied.
func _place_map_wall(c: Vector2i) -> void:
	if c == spawn_cell or c == base_cell:
		return
	if _pieces.has(c):
		return
	var w := Wall.new()
	w.position = cell_center(c)
	w.cell = c
	walls.add_child(w)
	w.setup_piece("wall", self, false)
	_pieces[c] = w

## Erase a placed map wall (used when carving corridors out of a solid fill).
func _erase_map_wall(c: Vector2i) -> void:
	var w: Structure = _pieces.get(c)
	if w == null:
		return
	_pieces.erase(c)
	w.queue_free()

## Pre-builds a serpentine wall maze so enemies wind across the board.
## Builds a full-coverage single-path labyrinth: a Hamiltonian path over the
## coarse lattice (every cell on ONE route - no dead ends, no branches, no
## self-crossing, fills the board) that turns in both directions. Spawn and base
## are moved to the path's two ends on the left/right edges, so they vary per
## game. Built by randomizing a snake seed with backbite, then steering the ends
## to the edges - fast and reliable; falls back to the simple serpentine.
## Lattice columns are the even cells; rows share the middle row's parity.
var _ham_nx := 0
var _ham_ny := 0
var _ham_base_row := 0
var _ham_blocked := {}  # lattice nodes that are solid tower-blocks (path avoids)

func _build_generated_map() -> void:
	# Prefer a labyrinth with a few solid 3x3 tower-blocks (path winds around
	# them, ~85% coverage). Fall back to the full no-block labyrinth, then the
	# simple serpentine, so a map always appears.
	var grid: Array = []
	for _a in range(12):  # blocked gen succeeds ~50%/try; retry so blocks appear
		grid = _generate_blocked()
		if not grid.is_empty():
			break
	if grid.is_empty():
		grid = _generate_hamiltonian()
	if grid.is_empty():
		grid = _generate_serpentine(randf() < 0.5)
	for r in range(ROWS):
		for c in range(COLS):
			if grid[r][c] == 1:
				_place_map_wall(Vector2i(c, r))

## Lattice <-> cell helpers (node index = j * NX + i).
func _hcell(n: int) -> Vector2i:
	var i := n % _ham_nx
	var j := n / _ham_nx
	return Vector2i(2 * i, _ham_base_row + 2 * j)

func _hnbrs(n: int) -> Array:
	var i := n % _ham_nx
	var j := n / _ham_nx
	var o: Array = []
	if i > 0 and not _ham_blocked.has(n - 1): o.append(n - 1)
	if i < _ham_nx - 1 and not _ham_blocked.has(n + 1): o.append(n + 1)
	if j > 0 and not _ham_blocked.has(n - _ham_nx): o.append(n - _ham_nx)
	if j < _ham_ny - 1 and not _ham_blocked.has(n + _ham_nx): o.append(n + _ham_nx)
	return o

## Backbite the path's last endpoint: rewire it to a random grid-neighbour that
## lies earlier in the path (reversing the tail). If tcol >= 0, prefer the move
## whose new endpoint is nearest that lattice column (steers the end to an edge).
func _backbite(path: Array, pos: Dictionary, tcol: int) -> void:
	var k := path.size()
	var cands: Array = []
	for u in _hnbrs(path[k - 1]):
		# Skip neighbours not on the path (blocked gen doesn't cover every node).
		if not pos.has(u):
			continue
		var j: int = pos[u]
		if j < k - 2:
			cands.append(j)
	if cands.is_empty():
		return
	var jpick: int = cands[randi() % cands.size()]
	if tcol >= 0:
		var bestd := 1 << 30
		for j in cands:
			var d: int = absi((path[j + 1] % _ham_nx) - tcol)
			if d < bestd:
				bestd = d
				jpick = j
	var lo := jpick + 1
	var hi := k - 1
	while lo < hi:
		var t = path[lo]; path[lo] = path[hi]; path[hi] = t
		pos[path[lo]] = lo; pos[path[hi]] = hi
		lo += 1; hi -= 1

## Backbite-randomize the whole path, working BOTH ends by reversing between
## bursts - otherwise one end stays as the boustrophedon seed (visible lanes).
## `bursts` should be even so the path's orientation is preserved.
func _randomize_both_ends(path: Array, pos: Dictionary, bursts: int, per: int) -> void:
	for _b in range(bursts):
		for _it in range(per):
			_backbite(path, pos, -1)
		path.reverse()
		pos.clear()
		for i in range(path.size()): pos[path[i]] = i

## A Warnsdorff self-avoiding fill of the (possibly holed) lattice from `start`:
## always step to the unvisited neighbour with the fewest onward moves. Returns
## the visited path (a simple path); coverage varies, so the caller takes the
## best of several tries.
func _warnsdorff(start: int) -> Array:
	var visited := {start: true}
	var path: Array = [start]
	var cur := start
	while true:
		var opts: Array = []
		for nb in _hnbrs(cur):
			if not visited.has(nb): opts.append(nb)
		if opts.is_empty():
			break
		opts.shuffle()
		var best: int = opts[0]
		var bd := 99
		for o in opts:
			var d := 0
			for n2 in _hnbrs(o):
				if not visited.has(n2): d += 1
			if d < bd:
				bd = d
				best = o
		visited[best] = true
		path.append(best)
		cur = best
	return path

## Labyrinth with a few solid 3x3 tower-blocks: excluding a lattice node walls
## off the 3x3 cell region around it, and the path (Warnsdorff fill, best of
## several tries, then backbite-randomized and steered to the edges) winds
## around them. ~85% of the rest is corridor. Returns [] to fall back.
func _generate_blocked() -> Array:
	_ham_nx = (COLS + 1) / 2
	_ham_base_row = (ROWS / 2) % 2
	_ham_ny = (ROWS - 1 - _ham_base_row) / 2 + 1
	if _ham_nx < 6 or _ham_ny < 5:
		return []  # too small for blocks - let the full labyrinth handle it
	var nx := _ham_nx
	# Pick 3-4 well-separated interior block centres.
	_ham_blocked = {}
	var centres: Array = []
	var want := 3 + (randi() % 2)
	var guard := 0
	while centres.size() < want and guard < 200:
		guard += 1
		var i := 2 + randi() % (nx - 4)
		var j := 1 + randi() % (_ham_ny - 2)
		var n := j * nx + i
		var ok := true
		for c in centres:
			if absi(c % nx - i) + absi(c / nx - j) < 3:
				ok = false
		if ok:
			centres.append(n)
			_ham_blocked[n] = true
	var need := nx * _ham_ny - _ham_blocked.size()
	# Best of several Warnsdorff fills (free endpoints).
	var path: Array = []
	for _s in range(48):
		var start := -1
		for _t in range(20):
			var cand := randi() % (nx * _ham_ny)
			if not _ham_blocked.has(cand):
				start = cand
				break
		if start < 0:
			continue
		var p := _warnsdorff(start)
		if p.size() > path.size():
			path = p
		if path.size() == need:
			break
	if path.size() < int(need * 0.6):
		return []  # too sparse this roll - fall back
	# Randomize the whole interior (both ends), then steer the ends to the edges.
	var pos := {}
	for i in range(path.size()): pos[path[i]] = i
	var n4 := path.size() * 4
	_randomize_both_ends(path, pos, 8, path.size())
	for _it in range(n4):
		if path[path.size() - 1] % nx == nx - 1: break
		_backbite(path, pos, nx - 1)
	path.reverse()
	pos.clear()
	for i in range(path.size()): pos[path[i]] = i
	for _it in range(n4):
		if path[path.size() - 1] % nx == 0: break
		_backbite(path, pos, 0)
	if path[0] % nx != nx - 1 or path[path.size() - 1] % nx != 0:
		return []
	# Build the grid: walls everywhere, carve the path corridor (blocks stay solid
	# because the path never touches their nodes or the gaps around them).
	var g: Array = []
	for r in range(ROWS):
		var row: Array = []
		for c in range(COLS):
			row.append(1)
		g.append(row)
	for i in range(path.size()):
		var c: Vector2i = _hcell(path[i])
		g[c.y][c.x] = 0
		if i > 0:
			var mc: Vector2i = (c + _hcell(path[i - 1])) / 2
			g[mc.y][mc.x] = 0
	var right_end: Vector2i = _hcell(path[0])
	spawn_cell = _hcell(path[path.size() - 1])
	base_cell = Vector2i(COLS - 1, right_end.y)
	for x in range(right_end.x, COLS):
		g[right_end.y][x] = 0
	return g

## Returns a 0/1 grid (1=wall) for the Hamiltonian labyrinth and moves spawn /
## base to the path's two ends, or [] if steering the ends to the edges failed.
func _generate_hamiltonian() -> Array:
	_ham_nx = (COLS + 1) / 2          # even-column lattice cols
	_ham_base_row = (ROWS / 2) % 2    # rows share the middle row's parity
	_ham_ny = (ROWS - 1 - _ham_base_row) / 2 + 1
	_ham_blocked = {}                 # full coverage, no blocks
	if _ham_nx < 2 or _ham_ny < 2:
		return []
	var nx := _ham_nx
	var total := nx * _ham_ny
	# Seed: a column boustrophedon (a valid Hamiltonian path).
	var path: Array = []
	for col in range(nx):
		if col % 2 == 0:
			for j in range(_ham_ny): path.append(j * nx + col)
		else:
			for j in range(_ham_ny - 1, -1, -1): path.append(j * nx + col)
	var pos := {}
	for i in range(path.size()): pos[path[i]] = i
	# Randomize the whole interior (both ends), then steer the ends to the edges.
	_randomize_both_ends(path, pos, 8, total)
	for _it in range(total * 4):
		if path[path.size() - 1] % nx == nx - 1: break
		_backbite(path, pos, nx - 1)
	path.reverse()
	pos.clear()
	for i in range(path.size()): pos[path[i]] = i
	for _it in range(total * 4):
		if path[path.size() - 1] % nx == 0: break
		_backbite(path, pos, 0)
	if path[0] % nx != nx - 1 or path[path.size() - 1] % nx != 0:
		return []  # couldn't place both ends on the edges - fall back
	# Build the wall grid: walls everywhere, then carve the path corridor.
	var g: Array = []
	for r in range(ROWS):
		var row: Array = []
		for c in range(COLS):
			row.append(1)
		g.append(row)
	for i in range(path.size()):
		var c: Vector2i = _hcell(path[i])
		g[c.y][c.x] = 0
		if i > 0:
			var mc: Vector2i = (c + _hcell(path[i - 1])) / 2
			g[mc.y][mc.x] = 0
	# Move spawn / base to the two ends; extend base out to the far edge column.
	var right_end: Vector2i = _hcell(path[0])
	spawn_cell = _hcell(path[path.size() - 1])
	base_cell = Vector2i(COLS - 1, right_end.y)
	for x in range(right_end.x, COLS):
		g[right_end.y][x] = 0
	return g

## Returns a fresh 0/1 grid for the serpentine. Vertical 1-wide corridors sit on
## every even column, joined by a single gap to the next. The gap row alternates
## between the bottom edge band and the top edge band, but its exact row is
## RANDOM within that band, so every game winds differently while each lane still
## crosses the middle (keeping spawn/base reachable). The first lane starts at
## the spawn row, the last ends at the base row - no stub dead ends, one path.
func _generate_serpentine(start_down: bool) -> Array:
	var mid := ROWS / 2
	var g: Array = []
	for r in range(ROWS):
		var row: Array = []
		for c in range(COLS):
			row.append(1)
		g.append(row)
	var xs: Array[int] = []
	var x := 0
	while x <= COLS - 1:
		xs.append(x)
		x += 2
	var n := xs.size()
	# Pre-roll each connector's row: alternating bottom/top band, random within.
	var jit: int = maxi(1, ROWS / 4)
	var conns: Array[int] = []
	for i in range(n - 1):
		var bottom: bool = (i % 2 == 0) == start_down
		if bottom:
			conns.append(randi_range(ROWS - 1 - jit, ROWS - 1))
		else:
			conns.append(randi_range(0, jit))
	for i in range(n):
		var cx: int = xs[i]
		var a: int  # one end of this lane
		var b: int  # the other end
		if i == 0:
			a = mid
			b = conns[0] if n > 1 else mid
		elif i == n - 1:
			a = conns[i - 1]
			b = mid
		else:
			a = conns[i - 1]
			b = conns[i]
		for y in range(mini(a, b), maxi(a, b) + 1):
			g[y][cx] = 0
		if i < n - 1:
			g[conns[i]][cx + 1] = 0  # the single connecting gap
	# Spawn ends lane 0; base sits beside the last lane's mid-row end.
	g[spawn_cell.y][spawn_cell.x] = 0
	g[base_cell.y][base_cell.x] = 0
	g[mid][xs[n - 1]] = 0
	return g

## BFS shortest-path length over open (0) cells, or -1 if unreachable.
func _grid_path_len(g: Array, start: Vector2i, goal: Vector2i) -> int:
	if g[start.y][start.x] != 0 or g[goal.y][goal.x] != 0:
		return -1
	var dist := {start: 0}
	var q: Array[Vector2i] = [start]
	var qi := 0
	while qi < q.size():
		var cur: Vector2i = q[qi]
		qi += 1
		if cur == goal:
			return dist[cur]
		for d in DIRS:
			var nb: Vector2i = cur + d
			if in_bounds(nb) and g[nb.y][nb.x] == 0 and not dist.has(nb):
				dist[nb] = int(dist[cur]) + 1
				q.append(nb)
	return -1

## The Huge-board Spiral verbatim. Each row is 64 chars; "1" is a wall and
## "0" is an open / corridor / spawn / base cell. Spawn lives at (0, 15) and
## base at (63, 15); both must remain `0` for the map to be traversable.
const SPIRAL_HUGE_MAP := [
	"0000000000000000000000000000000000000000000000000000000000000000",
	"0111111111111111111111111111111111111111111111111111111111111110",
	"0100000000000000000000000000000000000000000000000000000000001000",
	"0101111111111111111111111111111111111111111111111111111111101011",
	"0101000000000000000000000000000000000000000000000000000000101000",
	"0101011111111111111111111111111111111111111111111111111110101110",
	"0101010000000000000000000000000000000000000000000000000010101000",
	"0101010111111111111111111111111111111111111111111111111010101011",
	"0101010100000000000000000000000000000000000000000000001010101000",
	"0101010101111111111111111111111111111111111111111111101010101110",
	"0101010101000000000000000000000000000000000000000000101010101000",
	"0101010101011111111111111111111111111111111111111110101010101011",
	"0101010101010000000000000000000000000000000000000010101010101000",
	"0101010101010111111111111111111111111111111111111010101010101100",
	"0101010101010100010001000100010001000100010001000010101010101001",
	"0101010101010101000100010001000100010001000100010010101010101010",
	"1001010101010101111111111111111111111111111111111110101010101010",
	"0001010101010100000000000000000000000000000000000000101010101010",
	"0111010101010111111111111111111111111111111111111111101010101010",
	"0001010101010000000000000000000000000000000000000000001010101010",
	"0001010101011111111111111111111111111111111111111111111010101010",
	"1101010101000000000000000000000000000000000000000000000010101010",
	"0001010101111111111111111111111111111111111111111111111110101010",
	"0111010100000000000000000000000000000000000000000000000000101010",
	"0001010111111111111111111111111111111111111111111111111111101010",
	"0001010000000000000000000000000000000000000000000000000000001010",
	"1101011111111111111111111111111111111111111111111111111111111010",
	"0001000000000000000000000000000000000000000000000000000000000010",
	"0111111111111111111111111111111111111111111111111111111111111110",
	"0000000000000000000000000000000000000000000000000000000000000000",
]

## Pre-builds the "Spiral" map. On the Huge board this stamps the literal
## ASCII spec; on smaller boards it falls back to a procedural version with
## concentric rectangle corridors and a short central zigzag.
func _build_spiral() -> void:
	if COLS == 64 and ROWS == 30:
		_build_spiral_from_ascii()
		return
	_build_spiral_procedural()

## Stamp the 0/1 map verbatim. Each character is one cell; "1" is a wall.
## Spawn at (0, ROWS/2) and base at (COLS-1, ROWS/2) are skipped automatically
## inside `_place_map_wall`.
func _build_spiral_from_ascii() -> void:
	for r in range(ROWS):
		if r >= SPIRAL_HUGE_MAP.size():
			continue
		var line: String = SPIRAL_HUGE_MAP[r]
		for c in range(COLS):
			if c < line.length() and line[c] == "1":
				_place_map_wall(Vector2i(c, r))

func _build_spiral_procedural() -> void:
	var sy: int = ROWS / 2
	# Fill all interior cells with walls (skips spawn / base automatically).
	for x in range(COLS):
		for y in range(ROWS):
			_place_map_wall(Vector2i(x, y))
	# Carve concentric rectangular corridors at insets 1, 3, 5, ...
	var insets: Array[int] = []
	var n := 0
	while true:
		var ins := 1 + n * 2
		var x0 := ins
		var y0 := ins
		var x1 := COLS - 1 - ins
		var y1 := ROWS - 1 - ins
		if x1 - x0 < 4 or y1 - y0 < 4:
			break
		insets.append(ins)
		for x in range(x0, x1 + 1):
			_erase_map_wall(Vector2i(x, y0))
			_erase_map_wall(Vector2i(x, y1))
		for y in range(y0 + 1, y1):
			_erase_map_wall(Vector2i(x0, y))
			_erase_map_wall(Vector2i(x1, y))
		n += 1
	# Cut a single connecting gap between each pair of adjacent corridors,
	# alternating left / right at the spawn row.
	for k in range(insets.size() - 1):
		var on_left := (k % 2 == 0)
		var ring_inset := insets[k] + 1
		var gap_x := ring_inset if on_left else (COLS - 1 - ring_inset)
		_erase_map_wall(Vector2i(gap_x, sy))
	# Force the path through the inner ring: isolate the base-side cell of
	# corridor 0 so the only route from spawn to base must dip into ring 1.
	if insets.size() > 1:
		var c0_right_x := COLS - 1 - insets[0]
		_place_map_wall(Vector2i(c0_right_x, sy - 1))
		_place_map_wall(Vector2i(c0_right_x, sy + 1))
		_erase_map_wall(Vector2i(c0_right_x - 1, sy))
	# Central zigzag: a horizontal corridor through the innermost area with
	# alternating wall bumps above and below.
	if insets.size() > 0:
		var inner_inset: int = insets[-1] + 2
		var ix0 := inner_inset
		var ix1 := COLS - 1 - inner_inset
		if ix1 > ix0 + 1:
			for x in range(ix0, ix1 + 1):
				_erase_map_wall(Vector2i(x, sy))
			var bump_up := true
			for x in range(ix0, ix1 + 1, 2):
				var by := sy - 1 if bump_up else sy + 1
				_place_map_wall(Vector2i(x, by))
				bump_up = not bump_up

# --- view zoom (mouse wheel) ---
func _setup_zoom() -> void:
	var fit := minf(PLAY_W / float(COLS * CELL), PLAY_H / float(ROWS * CELL))
	_min_zoom = minf(MIN_ZOOM, fit)
	_zoom = minf(1.0, fit)
	scale = Vector2(_zoom, _zoom)
	_clamp_position()

func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var prev := _zoom
	_zoom = clampf(_zoom * factor, _min_zoom, MAX_ZOOM)
	if is_equal_approx(_zoom, prev):
		return
	var local := to_local(screen_pos)
	scale = Vector2(_zoom, _zoom)
	position = screen_pos - Vector2(_zoom, _zoom) * local
	_clamp_position()
	if hud != null:
		hud.dismiss_popup()

func _clamp_position() -> void:
	var bw := COLS * CELL * _zoom
	var bh := ROWS * CELL * _zoom
	if bw <= PLAY_W:
		position.x = (PLAY_W - bw) / 2.0
	else:
		position.x = clampf(position.x, PLAY_W - bw, 0.0)
	if bh <= PLAY_H:
		position.y = (PLAY_H - bh) / 2.0
	else:
		position.y = clampf(position.y, PLAY_H - bh, 0.0)

func _make_container(n: String) -> Node2D:
	var c := Node2D.new()
	c.name = n
	add_child(c)
	return c

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _flash_until:
		queue_redraw()
	# Throttled so the hover path-check BFS doesn't run every frame.
	if now - _hover_check_ms >= 100:
		_hover_check_ms = now
		_refresh_hover_validity()
	# Coalesce path recompute requests - at most once per frame even if many
	# walls were placed (Alt-drag) or removed in quick succession.
	if _paths_dirty:
		_paths_dirty = false
		_recompute_paths_now()
		_update_preview()
	# Rebuild the per-frame enemy bucket grid for fast tower / trap lookups.
	_rebuild_enemy_buckets()

## Keeps the hover green/red current as gold or the grid changes (no mouse move needed).
func _refresh_hover_validity() -> void:
	if not _show_hover or hud == null or hud.selected_type == "":
		return
	var ok := _can_place(_hover_cell, hud.selected_type)
	if ok != _hover_ok:
		_hover_ok = ok
		queue_redraw()

# --- grid helpers ---
## All cells on the axis-aligned line from `a` to `b`, snapping to whichever
## axis has the larger delta (so any diagonal drag becomes a clean line).
func _line_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if a.x < 0 or a.y < 0:
		return out
	var dx := b.x - a.x
	var dy := b.y - a.y
	if absi(dx) >= absi(dy):
		var step := 1 if dx >= 0 else -1
		for x in range(a.x, b.x + step, step):
			out.append(Vector2i(x, a.y))
	else:
		var step := 1 if dy >= 0 else -1
		for y in range(a.y, b.y + step, step):
			out.append(Vector2i(a.x, y))
	return out

func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL / 2.0, c.y * CELL + CELL / 2.0)

func cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < COLS and c.y >= 0 and c.y < ROWS

func _is_blocked(c: Vector2i) -> bool:
	var p: Structure = _pieces.get(c)
	return p != null and p.blocks

func has_path() -> bool:
	return not _preview.is_empty()

## The cached spawn->base route, refreshed by _update_preview() whenever the
## maze changes. Enemies copy this instead of each running their own full-board
## BFS - critical when a cluster (and bosses) spawn in the same frame.
func spawn_path() -> Array[Vector2i]:
	if _preview.is_empty():
		return bfs_path(spawn_cell, base_cell)
	return _preview.duplicate()

# --- pathfinding ---
func bfs_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not in_bounds(start) or not in_bounds(goal):
		return result
	var came := {start: start}
	var queue: Array[Vector2i] = [start]
	var qi := 0
	var found := start == goal
	while qi < queue.size() and not found:
		var cur: Vector2i = queue[qi]
		qi += 1
		for d in DIRS:
			var nb: Vector2i = cur + d
			if came.has(nb) or not in_bounds(nb) or _is_blocked(nb):
				continue
			came[nb] = cur
			if nb == goal:
				found = true
				break
			queue.append(nb)
	if not came.has(goal):
		return result
	var c := goal
	result.append(c)
	while c != start:
		c = came[c]
		result.append(c)
	result.reverse()
	return result

## True if base stays reachable from spawn and every live enemy with `extra` blocked.
func _path_ok_with_extra(extra: Vector2i) -> bool:
	var seen := {base_cell: true}
	var queue: Array[Vector2i] = [base_cell]
	var qi := 0
	while qi < queue.size():
		var cur: Vector2i = queue[qi]
		qi += 1
		for d in DIRS:
			var nb: Vector2i = cur + d
			if seen.has(nb) or nb == extra or not in_bounds(nb) or _is_blocked(nb):
				continue
			seen[nb] = true
			queue.append(nb)
	if not seen.has(spawn_cell):
		return false
	for node in enemies.get_children():
		var e := node as Enemy
		if e != null and e.is_alive() and not seen.has(e.cell):
			return false
	return true

func _update_preview() -> void:
	_preview = bfs_path(spawn_cell, base_cell)
	Events.path_changed.emit(not _preview.is_empty())
	queue_redraw()

## Per-frame: rebuild a spatial bucket grid so towers / traps / bullets can
## query nearby enemies in O(bucket) instead of scanning every enemy.
func _rebuild_enemy_buckets() -> void:
	_enemy_buckets.clear()
	for node in enemies.get_children():
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var key := Vector2i(int(e.position.x / BUCKET_SIZE),
			int(e.position.y / BUCKET_SIZE))
		if not _enemy_buckets.has(key):
			_enemy_buckets[key] = []
		_enemy_buckets[key].append(e)

## Total kill-gold bonus from every Gold Mine (0.5%/level each). An adjacent
## Amplifier boosts a mine's contribution too, capped at +50% so it stays sane.
const GOLD_AMP_CAP := 0.5
func gold_bonus() -> float:
	var b := 0.0
	for node in towers.get_children():
		var t := node as Tower
		if t != null and t.type == "gold":
			var amp := minf(GOLD_AMP_CAP, amplifier_bonus_at(t.cell))
			b += PieceData.SUPPORT_PCT_PER_LEVEL * t.level * (1.0 + amp)
	return b

## Total Amplifier damage boost applied to a tower at `cell` (0.5%/level per
## adjacent Amplifier, counting all 8 touching cells).
func amplifier_bonus_at(cell: Vector2i) -> float:
	var b := 0.0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var p: Structure = _pieces.get(cell + Vector2i(dx, dy))
			if p is Tower and (p as Tower).type == "amplifier":
				b += PieceData.SUPPORT_PCT_PER_LEVEL * (p as Tower).level
	return b

## Returns every live enemy within `radius` of `pos`. O(buckets-in-range).
func enemies_near(pos: Vector2, radius: float) -> Array:
	var out: Array = []
	var bx0 := int((pos.x - radius) / BUCKET_SIZE)
	var bx1 := int((pos.x + radius) / BUCKET_SIZE)
	var by0 := int((pos.y - radius) / BUCKET_SIZE)
	var by1 := int((pos.y + radius) / BUCKET_SIZE)
	var r2 := radius * radius
	for bx in range(bx0, bx1 + 1):
		for by in range(by0, by1 + 1):
			var bucket = _enemy_buckets.get(Vector2i(bx, by))
			if bucket == null:
				continue
			for e in bucket:
				if pos.distance_squared_to(e.position) <= r2:
					out.append(e)
	return out

## Public-facing version: just sets the dirty flag. `_process` does the work
## once per frame, regardless of how many call sites fire.
func _recompute_paths() -> void:
	_paths_dirty = true

func _recompute_paths_now() -> void:
	for node in enemies.get_children():
		var e := node as Enemy
		if e != null:
			e.repath()

# --- input ---
func _unhandled_input(event: InputEvent) -> void:
	if GameState.game_over:
		return
	if event is InputEventMouseMotion:
		if _middle_held:
			position += event.relative
			_clamp_position()
			return
		_update_hover(event.position)
		# Drag handling:
		#  - Alt + left-drag with any selected piece: place in a straight line.
		#  - Free-form left-drag for walls (with the option on): paint walls.
		#  - Alt + right-drag for walls: remove in a line.
		#  - Free-form right-drag for walls (option on): remove walls.
		if _left_held and hud != null and hud.selected_type != "":
			var dc := cell_at(to_local(event.position))
			var sel: String = hud.selected_type
			if Input.is_key_pressed(KEY_ALT) and _drag_start_cell.x >= 0:
				_begin_group()
				for c in _line_cells(_drag_start_cell, dc):
					_try_place(c, sel)
				_end_group()
			elif GameState.drag_draw_walls and sel == "wall":
				_try_place(dc, "wall")
		elif _right_held and hud != null and hud.selected_type == "wall":
			var dc := cell_at(to_local(event.position))
			if Input.is_key_pressed(KEY_ALT) and _drag_start_cell.x >= 0:
				_begin_group()
				for c in _line_cells(_drag_start_cell, dc):
					var p: Structure = _pieces.get(c)
					if p is Wall:
						_remove_structure(p)
				_end_group()
			elif GameState.drag_draw_walls:
				var dp: Structure = _pieces.get(dc)
				if dp is Wall:
					_remove_structure(dp)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_left_held = event.pressed
				if event.pressed and hud != null and hud.selected_type != "":
					_drag_start_cell = cell_at(to_local(event.position))
			MOUSE_BUTTON_RIGHT:
				_right_held = event.pressed
				if event.pressed and hud != null and hud.selected_type == "wall":
					_drag_start_cell = cell_at(to_local(event.position))
			MOUSE_BUTTON_MIDDLE:
				_middle_held = event.pressed
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_zoom_at(event.position, 1.12)
				MOUSE_BUTTON_WHEEL_DOWN:
					_zoom_at(event.position, 1.0 / 1.12)
				MOUSE_BUTTON_LEFT:
					_on_click(event.position, false)
				MOUSE_BUTTON_RIGHT:
					_on_click(event.position, true)

func _update_hover(pos: Vector2) -> void:
	if hud == null:
		return
	var c := cell_at(to_local(pos))
	# Report the piece under the cursor so the HUD can show its stats.
	hud.set_hovered_structure(_pieces.get(c))
	if hud.selected_type == "":
		_show_hover = false
		return
	_hover_cell = c
	_hover_ok = _can_place(c, hud.selected_type)
	_show_hover = true

func _on_click(pos: Vector2, is_right: bool) -> void:
	if hud == null:
		return
	# A left-click on the floating popup runs its upgrade/sell action.
	if not is_right and hud.popup_hit(pos):
		hud.popup_activate()
		return
	# A right-click while a popup is open just closes it.
	if is_right and hud.dismiss_popup():
		return
	hud.dismiss_popup()
	var c := cell_at(to_local(pos))
	if not in_bounds(c):
		return
	var existing: Structure = _pieces.get(c)
	var sel := hud.selected_type
	# Wall paint mode: left adds a wall, right sells the wall under the cursor.
	# If the click lands on a tower/trap, fall through so it can be selected.
	if sel == "wall":
		if is_right:
			if existing is Wall:
				_remove_structure(existing)
				return
		else:
			if existing == null:
				_try_place(c, "wall")
				return
			if existing is Wall:
				return
		# existing is Tower/Trap - keep going so the normal selection runs.
	# Right-click: sell.
	if is_right:
		if existing is Wall:
			_select_structure(null)
			_remove_structure(existing)
		elif existing is Tower or existing is Trap:
			_select_structure(existing)
			hud.show_popup(existing, "sell")
		else:
			_select_structure(null)
			hud.clear_selection()
		return
	# Left-click on a placed tower or trap -> upgrade prompt. Hold Alt to
	# attempt ten upgrades at once (always available; stops when gold runs out).
	if existing is Tower or existing is Trap:
		if Input.is_key_pressed(KEY_ALT):
			# Select first so the piece (and its range circle) redraws with the
			# new stats after the bulk upgrade, just like a normal upgrade.
			_select_structure(existing)
			_alt_upgrade_ten(existing)
			return
		_select_structure(existing)
		hud.show_popup(existing, "upgrade")
		return
	# Left-click on a wall: a selected tower replaces it, else show a sell prompt.
	if existing is Wall:
		if sel != "" and PieceData.category(sel) == "tower":
			_select_structure(null)
			_try_place(c, sel)
		else:
			_select_structure(existing)
			hud.show_popup(existing, "sell")
		return
	# Left-click on empty ground -> place the selected piece.
	_select_structure(null)
	if sel != "":
		_try_place(c, sel)

# --- placement ---
func _can_place(c: Vector2i, type: String) -> bool:
	if not in_bounds(c) or c == spawn_cell or c == base_cell:
		return false
	var existing: Structure = _pieces.get(c)
	# A cell is free unless occupied — except a tower may replace a wall.
	if existing != null and not (existing is Wall and PieceData.category(type) == "tower"):
		return false
	if PieceData.category(type) != "trap":
		for node in enemies.get_children():
			var e := node as Enemy
			if e != null and e.is_alive() and e.occupies(c):
				return false
		# Replacing a wall keeps the cell blocked, so the path is unaffected.
		if existing == null and not _path_ok_with_extra(c):
			return false
	return _affordable(type)

func _affordable(type: String) -> bool:
	if type == "wall" and GameState.free_walls:
		return true
	var key: String = PieceData.TYPES[type]["stock_key"]
	if key != "" and GameState.stock_of(key) > 0:
		return true
	return GameState.can_afford(PieceData.cost(type))

func _try_place(c: Vector2i, type: String) -> void:
	if not _can_place(c, type):
		# Not enough gold/stock: flicker the clicked cell red as feedback.
		if not _affordable(type):
			_flash_cell = c
			_flash_until = Time.get_ticks_msec() + 450
			queue_redraw()
		return
	var key: String = PieceData.TYPES[type]["stock_key"]
	var from_stock := false
	var gold_spent := 0
	if type == "wall" and GameState.free_walls:
		pass
	elif key != "" and GameState.stock_of(key) > 0:
		GameState.take_stock(key)
		from_stock = true
	elif GameState.spend(PieceData.cost(type)):
		# Unlimited-money mode pretends to spend but doesn't; don't refund on undo.
		if not GameState.unlimited_money:
			gold_spent = PieceData.cost(type)
	else:
		return
	_record_action({
		"k": "place", "cell": c, "type": type,
		"gold": gold_spent, "from_stock": from_stock, "stock_key": key,
	})
	# A tower placed on a wall sits on top of it; the wall is tucked under and
	# will come back when the tower is sold. Anything else gets removed.
	var existing: Structure = _pieces.get(c)
	if existing != null:
		if existing is Wall and PieceData.category(type) == "tower":
			_under_walls[c] = existing
		else:
			_remove_structure(existing)
	var s := _make_piece(type)
	s.position = cell_center(c)
	s.cell = c
	_container_for(type).add_child(s)
	s.setup_piece(type, self, from_stock)
	_pieces[c] = s
	if s.blocks:
		_recompute_paths()
		_update_preview()
	queue_redraw()

func _make_piece(type: String) -> Structure:
	var cat := PieceData.category(type)
	if cat == "wall":
		return Wall.new()
	if cat == "tower":
		return Tower.new()
	return Trap.new()

func _container_for(type: String) -> Node2D:
	var cat := PieceData.category(type)
	if cat == "wall":
		return walls
	if cat == "tower":
		return towers
	return traps

# --- selection / economy ---
func _select_structure(s: Structure) -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.set_selected(false)
	_selected = s
	if s != null:
		s.set_selected(true)

func _remove_structure(s: Structure) -> void:
	if s == null or not is_instance_valid(s):
		return
	var key: String = PieceData.TYPES[s.type]["stock_key"]
	var stock_returned := s.from_stock and key != ""
	if stock_returned:
		GameState.add_stock(key, 1)
	var refund_gold := 0
	if s.gold_invested > 0:
		refund_gold = s.sell_refund()
		GameState.add_gold(refund_gold)
	# Snapshot enough to recreate this piece if the user presses undo.
	_record_action({
		"k": "remove", "cell": s.cell, "type": s.type, "level": s.level,
		"gold_invested": s.gold_invested, "from_stock": s.from_stock,
		"stock_key": key, "refund_gold": refund_gold,
		"stock_returned": stock_returned,
	})
	_pieces.erase(s.cell)
	# If a wall was tucked under this tower, bring it back to the surface.
	var under: Structure = _under_walls.get(s.cell)
	if under != null:
		_under_walls.erase(s.cell)
		_pieces[s.cell] = under
	var was_blocking := s.blocks
	if _selected == s:
		_selected = null
	s.queue_free()
	# Skip path recompute if the underlying wall keeps the cell blocked.
	if was_blocking and under == null:
		_recompute_paths()
		_update_preview()
	queue_redraw()

func sell_selected() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	_remove_structure(_selected)
	if hud != null:
		hud.dismiss_popup()

func upgrade_selected() -> void:
	var s := _selected
	if s == null or not is_instance_valid(s) or not s.can_upgrade():
		return
	var cost := s.upgrade_cost()
	if not GameState.spend(cost):
		return
	var refund := 0 if GameState.unlimited_money else cost
	_record_action({"k": "upgrade", "cell": s.cell, "cost": refund})
	s.do_upgrade()
	if (s.type == "gold" or s.type == "amplifier") and hud != null:  # gold total may change
		hud._update_wave_info()

# --- undo plumbing ---
func _record_action(entry: Dictionary) -> void:
	if _group_open:
		_open_group.append(entry)
	else:
		_undo_stack.append([entry])
		if _undo_stack.size() > UNDO_MAX:
			_undo_stack.pop_front()

func _begin_group() -> void:
	_group_open = true
	_open_group = []

func _end_group() -> void:
	if _group_open and not _open_group.is_empty():
		_undo_stack.append(_open_group)
		if _undo_stack.size() > UNDO_MAX:
			_undo_stack.pop_front()
	_open_group = []
	_group_open = false

## Reverse the most recent user action. Returns true if anything was undone.
func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	var group: Array = _undo_stack.pop_back()
	# Replay in reverse so a sequence like place-then-upgrade unwinds in order.
	for i in range(group.size() - 1, -1, -1):
		_apply_undo(group[i])
	queue_redraw()
	if hud != null:
		hud.dismiss_popup()
	return true

func _apply_undo(e: Dictionary) -> void:
	match e["k"]:
		"place": _undo_place(e)
		"remove": _undo_remove(e)
		"upgrade": _undo_upgrade(e)

func _undo_place(e: Dictionary) -> void:
	var s: Structure = _pieces.get(e["cell"])
	if s == null or not is_instance_valid(s):
		return
	# Hand back exactly what was paid, not the 70% sell value.
	if e["from_stock"] and e["stock_key"] != "":
		GameState.add_stock(e["stock_key"], 1)
	elif e["gold"] > 0:
		GameState.add_gold(e["gold"])
	_silent_remove(s)

func _undo_remove(e: Dictionary) -> void:
	# Take back the refund that the sell handed out.
	if e["refund_gold"] > 0:
		GameState.gold = maxi(0, GameState.gold - e["refund_gold"])
		Events.gold_changed.emit(GameState.gold)
	if e["stock_returned"] and e["stock_key"] != "":
		var d: Dictionary = GameState.stock
		if d.has(e["stock_key"]):
			d[e["stock_key"]] = maxi(0, d[e["stock_key"]] - 1)
			Events.stock_changed.emit()
	# If the sold piece was a tower sitting on a wall, that wall is currently
	# on top — tuck it back under so the resurrected tower can take its place.
	var existing: Structure = _pieces.get(e["cell"])
	if existing is Wall and PieceData.category(e["type"]) == "tower":
		_under_walls[e["cell"]] = existing
		_pieces.erase(e["cell"])
	var s := _make_piece(e["type"])
	s.position = cell_center(e["cell"])
	s.cell = e["cell"]
	_container_for(e["type"]).add_child(s)
	s.setup_piece(e["type"], self, e["from_stock"])
	s.gold_invested = e["gold_invested"]
	while s.level < e["level"]:
		s.level += 1
	if s.has_method("_apply_stats"):
		s.call("_apply_stats")
	s.queue_redraw()
	_pieces[e["cell"]] = s
	if s.blocks:
		_recompute_paths()
		_update_preview()

func _undo_upgrade(e: Dictionary) -> void:
	var s: Structure = _pieces.get(e["cell"])
	if s == null or not is_instance_valid(s):
		return
	GameState.add_gold(e["cost"])
	s.level = maxi(1, s.level - 1)
	s.gold_invested = maxi(0, s.gold_invested - e["cost"])
	if s.has_method("_apply_stats"):
		s.call("_apply_stats")
	s.queue_redraw()

## Remove a piece without refunding or recording undo (used by undo of place).
func _silent_remove(s: Structure) -> void:
	_pieces.erase(s.cell)
	var under: Structure = _under_walls.get(s.cell)
	if under != null:
		_under_walls.erase(s.cell)
		_pieces[s.cell] = under
	var was_blocking := s.blocks
	if _selected == s:
		_selected = null
	s.queue_free()
	if was_blocking and under == null:
		_recompute_paths()
		_update_preview()
	queue_redraw()

func _on_piece_selected(type: String) -> void:
	if hud != null:
		hud.dismiss_popup()
	if type != "":
		_select_structure(null)
	else:
		_show_hover = false
	queue_redraw()

# --- rendering ---
func _draw() -> void:
	var w := COLS * CELL
	var h := ROWS * CELL
	draw_rect(Rect2(0, 0, w, h), Color(0.15, 0.17, 0.16))
	for x in range(COLS + 1):
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, h), Color(1, 1, 1, 0.045))
	for y in range(ROWS + 1):
		draw_line(Vector2(0, y * CELL), Vector2(w, y * CELL), Color(1, 1, 1, 0.045))
	_draw_door(spawn_cell, Color(0.80, 0.34, 0.30), Color(0.21, 0.13, 0.12))
	_draw_door(base_cell, Color(0.38, 0.58, 0.94), Color(0.15, 0.21, 0.33))
	if _preview.size() > 1:
		var pts := PackedVector2Array()
		for c in _preview:
			pts.append(cell_center(c))
		draw_polyline(pts, Color(0.92, 0.86, 0.40, 0.30), 3.0)

## Draws the spawn / base cell as a small double door.
func _draw_door(c: Vector2i, frame: Color, slab: Color) -> void:
	var ox := float(c.x * CELL)
	var oy := float(c.y * CELL)
	var cx := ox + CELL * 0.5
	draw_rect(Rect2(ox + 3.0, oy + 3.0, CELL - 6.0, CELL - 6.0), frame)
	var s := Rect2(ox + 6.0, oy + 6.0, CELL - 12.0, CELL - 12.0)
	draw_rect(s, slab)
	draw_line(Vector2(cx, s.position.y), Vector2(cx, s.position.y + s.size.y), frame, 1.6)
	var leaf_w := s.size.x * 0.5
	var panel := slab.lightened(0.22)
	for i in range(2):
		var px := s.position.x + i * leaf_w + 3.0
		draw_rect(Rect2(px, s.position.y + 4.0, leaf_w - 6.0, s.size.y - 8.0),
			panel, false, 1.4)
	var ky := oy + CELL * 0.5
	var knob := frame.lightened(0.3)
	draw_circle(Vector2(cx - 3.6, ky), 1.9, knob)
	draw_circle(Vector2(cx + 3.6, ky), 1.9, knob)

## Drawn by BuildOverlay (on top of all pieces) so hover/flash show over walls.
func draw_build_overlay(ci: CanvasItem) -> void:
	if _show_hover and in_bounds(_hover_cell):
		var col := Color(0.35, 0.9, 0.4, 0.45) if _hover_ok else Color(0.95, 0.3, 0.3, 0.45)
		ci.draw_rect(Rect2(_hover_cell.x * CELL + 2, _hover_cell.y * CELL + 2,
			CELL - 4, CELL - 4), col)
		# AOE / range preview around the hover cell while placing.
		if hud != null:
			var sel: String = hud.selected_type
			if sel != "" and PieceData.TYPES.has(sel):
				var cx := _hover_cell.x * CELL + CELL * 0.5
				var cy := _hover_cell.y * CELL + CELL * 0.5
				var d: Dictionary = PieceData.TYPES[sel]
				var cat: String = d.get("category", "")
				# Trap AOE (Volcano): the area it hits every cell around it.
				if cat == "trap":
					var aoe: float = d.get("aoe_radius", 0.0)
					if aoe > 0.0:
						# Dim dark ring so the preview reads distinctly from live towers' rings.
						ci.draw_arc(Vector2(cx, cy), aoe, 0.0, TAU, 48,
							Color(0.30, 0.14, 0.05, 0.85), 1.8)
				# Tower range: the circle the tower will fire / chill within.
				elif cat == "tower":
					var rng: float = d.get("range", 0.0)
					if rng > 0.0:
						ci.draw_arc(Vector2(cx, cy), rng, 0.0, TAU, 48,
							Color(0.05, 0.05, 0.08, 0.85), 1.8)
	var now := Time.get_ticks_msec()
	if now < _flash_until and in_bounds(_flash_cell) and (now / 90) % 2 == 0:
		ci.draw_rect(Rect2(_flash_cell.x * CELL + 2, _flash_cell.y * CELL + 2,
			CELL - 4, CELL - 4), Color(0.95, 0.20, 0.20, 0.88))
