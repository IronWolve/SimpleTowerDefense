class_name EnemyLegend
extends Control
## A small horizontal legend in the HUD bar: each entry is an enemy-shaped
## icon followed by its label, so the next wave's enemies are recognisable.

## Each entry: {"shape": String, "color": Color, "label": String}.
var entries: Array = []

func set_entries(e: Array) -> void:
	entries = e
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var fs := 10
	var lh := 13.0
	var indent := _text(font, fs, 0.0, 6.0, "Enemies:", Color(0.74, 0.80, 0.76)) + 12.0
	# Column 1 holds the normal enemy types; bosses go in a second column so the
	# list stays at 3 lines. Size column 2's x off the widest normal label.
	var col2_x := indent + 18.0
	for e in entries:
		if not _is_boss_shape(e["shape"]):
			var w := font.get_string_size(e["label"], HORIZONTAL_ALIGNMENT_LEFT,
				-1, fs).x
			col2_x = maxf(col2_x, indent + 18.0 + w + 24.0)
	var row1 := 0
	var row2 := 0
	for e in entries:
		if _is_boss_shape(e["shape"]):
			var cy := 9.0 + row2 * lh
			_draw_icon(Vector2(col2_x + 7.0, cy), e["shape"], e["color"])
			_text(font, fs, col2_x + 18.0, cy, e["label"], Color(0.86, 0.89, 0.86))
			row2 += 1
		else:
			var cy := 9.0 + row1 * lh
			_draw_icon(Vector2(indent + 7.0, cy), e["shape"], e["color"])
			_text(font, fs, indent + 18.0, cy, e["label"], Color(0.86, 0.89, 0.86))
			row1 += 1

func _is_boss_shape(shape: String) -> bool:
	return shape == "beetle" or shape == "turtle"

## Draws a string and returns the x just past it.
func _text(font: Font, fs: int, x: float, cy: float, s: String, col: Color) -> float:
	draw_string(font, Vector2(x, cy + fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return x + font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## Top-down icons matching the in-game enemy redesign (forward = right).
## Each fits in a 14x14 box (radius 7) with thin outlines so they read at
## HUD scale.
func _draw_icon(c: Vector2, shape: String, col: Color) -> void:
	var r := 7.0
	var outline := Color(0, 0, 0, 0.85)
	var dark := col.darkened(0.45)
	match shape:
		"triangle":
			# Runner: wedge body pointing right, two side wheels.
			var pts := _runner_pts(c, r)
			draw_colored_polygon(pts, col)
			draw_polyline(_close_loop(pts), outline, 1.0)
			for sy in [-r * 0.50, r * 0.50]:
				draw_rect(Rect2(c.x - r * 0.20, c.y + sy - r * 0.10, r * 0.40, r * 0.20),
					Color(0.18, 0.18, 0.22))
		"hexagon":
			# Tank: hull between two treads, small turret + forward barrel.
			draw_rect(Rect2(c.x - r * 0.85, c.y - r * 0.90, r * 1.70, r * 0.22), outline)
			draw_rect(Rect2(c.x - r * 0.85, c.y + r * 0.68, r * 1.70, r * 0.22), outline)
			draw_rect(Rect2(c.x - r * 0.80, c.y - r * 0.60, r * 1.60, r * 1.20), outline)
			draw_rect(Rect2(c.x - r * 0.72, c.y - r * 0.52, r * 1.44, r * 1.04), col)
			draw_circle(c, r * 0.36, outline)
			draw_circle(c, r * 0.28, col.lightened(0.10))
			draw_rect(Rect2(c.x + r * 0.20, c.y - r * 0.10, r * 0.85, r * 0.20), outline)
			draw_rect(Rect2(c.x + r * 0.24, c.y - r * 0.06, r * 0.78, r * 0.12), dark)
		"beetle":
			# Beetle walker: oval carapace, 4 leg-bumps, two front optics.
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					draw_line(c + Vector2(sx * r * 0.30, sy * r * 0.30),
						c + Vector2(sx * r * 0.85, sy * r * 0.85), outline, 2.0)
			var car := _oval(c, r * 0.78, r * 0.66, 18)
			draw_colored_polygon(car, col)
			draw_polyline(_close_loop(car), outline, 1.0)
			for sy in [-r * 0.28, r * 0.28]:
				draw_circle(c + Vector2(r * 0.46, sy), r * 0.14, Color(1, 0.91, 0.55))
		"turtle":
			# Turtle siege transport: side treads + big domed shell + slit.
			draw_rect(Rect2(c.x - r * 0.95, c.y - r * 0.85, r * 1.90, r * 0.22), outline)
			draw_rect(Rect2(c.x - r * 0.95, c.y + r * 0.62, r * 1.90, r * 0.22), outline)
			var shell := _oval(c, r * 0.85, r * 0.62, 22)
			draw_colored_polygon(shell, col)
			draw_polyline(_close_loop(shell), outline, 1.0)
			draw_circle(c + Vector2(-r * 0.20, -r * 0.18), r * 0.42, Color(1, 1, 1, 0.22))
			draw_rect(Rect2(c.x + r * 0.52, c.y - r * 0.20, r * 0.10, r * 0.40),
				Color(1, 0.91, 0.55, 0.85))
		_:
			# Grunt scout: small boxy hull with 4 corner wheels + dome.
			for sx in [-r * 0.55, r * 0.30]:
				for sy in [-r * 0.55, r * 0.42]:
					draw_rect(Rect2(c.x + sx, c.y + sy, r * 0.30, r * 0.16),
						Color(0.18, 0.18, 0.22))
			draw_rect(Rect2(c.x - r * 0.80, c.y - r * 0.50, r * 1.60, r * 1.00), outline)
			draw_rect(Rect2(c.x - r * 0.72, c.y - r * 0.42, r * 1.44, r * 0.84), col)
			draw_circle(c + Vector2(-r * 0.06, 0), r * 0.30, dark)
			draw_circle(c + Vector2(r * 0.65, 0), r * 0.14, Color(1, 0.91, 0.55))

## Runner wedge polygon: blunt back, pointed nose (right). Used by the legend.
func _runner_pts(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(-r * 0.90, -r * 0.42),
		c + Vector2(r * 0.20, -r * 0.42),
		c + Vector2(r * 1.00, 0.0),
		c + Vector2(r * 0.20, r * 0.42),
		c + Vector2(-r * 0.90, r * 0.42),
	])

## Closes a polygon by appending its first point. Used so polylines draw a
## complete outline.
func _close_loop(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out

func _ngon(c: Vector2, sides: int, rot: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := rot + TAU * i / float(sides)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

func _oval(c: Vector2, rx: float, ry: float, seg: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * i / float(seg)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
