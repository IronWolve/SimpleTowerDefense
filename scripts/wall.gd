class_name Wall
extends Structure
## A pure obstacle: blocks enemy movement, used to carve the maze.

## Shared visual style: opaque near-black outline used across every piece.
const OUTLINE := Color(0.04, 0.04, 0.05)

var color := Color(0.46, 0.46, 0.52)

func _apply_stats() -> void:
	color = PieceData.TYPES["wall"]["color"]

func info_text() -> String:
	return "Blocks enemy movement."

func _draw() -> void:
	var h := 18.0
	# Outline backing (fills the whole cell).
	draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), OUTLINE)
	# Body, inset by 2 px so the outline shows.
	var inset := 2.0
	var bw := (h - inset) * 2.0
	draw_rect(Rect2(-h + inset, -h + inset, bw, bw), color)
	# Top-lit edge + bottom AO edge - the "baked top-lighting" tile trick.
	var lit := color.lightened(0.28)
	var dark := color.darkened(0.45)
	draw_rect(Rect2(-h + inset, -h + inset, bw, 2.5), Color(lit.r, lit.g, lit.b, 0.65))
	draw_rect(Rect2(-h + inset, h - inset - 2.5, bw, 2.5), Color(dark.r, dark.g, dark.b, 0.45))
	if selected:
		draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), Color(1, 1, 1, 0.7), false, 2.0)
