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
	var fs := 12
	var lh := 16.0
	var indent := _text(font, fs, 0.0, 9.0, "Enemies:", Color(0.74, 0.80, 0.76)) + 12.0
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
	return shape == "beetle" or shape == "scorpion"

## Draws a string and returns the x just past it.
func _text(font: Font, fs: int, x: float, cy: float, s: String, col: Color) -> float:
	draw_string(font, Vector2(x, cy + fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return x + font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

func _draw_icon(c: Vector2, shape: String, col: Color) -> void:
	var r := 7.0
	match shape:
		"triangle":
			draw_colored_polygon(_ngon(c, 3, -PI / 2.0, r * 1.15), col)
		"hexagon":
			draw_colored_polygon(_ngon(c, 6, PI / 6.0, r), col)
		"beetle":
			draw_circle(c + Vector2(0, -r * 0.78), r * 0.42, col.darkened(0.4))
			draw_colored_polygon(_oval(c, r * 0.8, r * 1.0, 16), col)
			draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.9),
				col.darkened(0.4), 1.6)
		"scorpion":
			var dk := col.darkened(0.4)
			# Two front claws.
			for side in [-1.0, 1.0]:
				draw_circle(c + Vector2(side * r * 0.7, -r * 0.7), r * 0.26, dk)
			# Body.
			draw_colored_polygon(_oval(c, r * 0.55, r * 0.85, 16), col)
			# Curled tail to the lower right.
			draw_line(c + Vector2(0, r * 0.7), c + Vector2(r * 0.5, r * 0.5), dk, 1.8)
			draw_circle(c + Vector2(r * 0.55, r * 0.35), r * 0.18, dk)
		_:
			draw_circle(c, r, col)

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
