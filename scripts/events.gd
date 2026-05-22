extends Node
## Global signal bus. Decouples gameplay systems from the HUD and each other.

signal gold_changed(gold)
signal lives_changed(lives)
signal wave_changed(wave)
signal stock_changed
signal piece_selected(type)
signal path_changed(has_path)
signal game_over
