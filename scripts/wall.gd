class_name Wall
extends Structure
## A pure obstacle: blocks enemy movement, used to carve the maze.

var color := Color(0.46, 0.46, 0.52)

func _apply_stats() -> void:
	color = PieceData.TYPES["wall"]["color"]

func info_text() -> String:
	return "Blocks enemy movement."

func _draw() -> void:
	var h := 18.0
	draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), Color(0.16, 0.16, 0.18))
	draw_rect(Rect2(-h + 3.0, -h + 3.0, (h - 3.0) * 2.0, (h - 3.0) * 2.0), color)
	if selected:
		draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), Color(1, 1, 1, 0.7), false, 2.0)
