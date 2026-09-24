class_name ShogiSilverMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 銀は前、前斜め、後ろ斜めに進む。剣の移動。
	configure(
		"silver",
		"Silver",
		"S",
		[
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(-1, 1), Vector2i(1, 1),
		],
		[]
	)
