class_name Structure
extends Node2D
## Base for placed walls, towers and traps: grid cell, sell/upgrade economy.

var type := ""
var category := ""
var blocks := false
var cell := Vector2i.ZERO
var level := 1
var from_stock := false
var gold_invested := 0
var level_ref: Level
var selected := false

func setup_piece(t: String, lvl: Level, stocked: bool) -> void:
	type = t
	level_ref = lvl
	category = PieceData.category(t)
	blocks = PieceData.TYPES[t]["blocks"]
	from_stock = stocked
	gold_invested = 0 if stocked else PieceData.cost(t)
	level = 1
	_apply_stats()
	queue_redraw()

func can_upgrade() -> bool:
	return false

func upgrade_cost() -> int:
	return 0

func do_upgrade() -> void:
	pass

func sell_refund() -> int:
	return int(round(gold_invested * 0.7))

func display_name() -> String:
	return PieceData.TYPES[type]["name"]

func info_text() -> String:
	return ""

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

## Overridden by subclasses to read effective stats for the current level.
func _apply_stats() -> void:
	pass
