class_name BuildOverlay
extends Node2D
## Draws the placement hover and the "can't afford" flash above every piece,
## so the green/red feedback stays visible even over walls and towers.

var level: Level

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if level != null:
		level.draw_build_overlay(self)
