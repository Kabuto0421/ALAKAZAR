class_name ShogiGoldMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 金は後ろ斜め2方向を除く隣接セルへ進む。
	configure(
		"gold",
		"Gold",
		"G",
		[
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(0, 1),
		],
		[]
	)
