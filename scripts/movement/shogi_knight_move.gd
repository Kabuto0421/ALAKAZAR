class_name ShogiKnightMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 桂馬は前方2マス、左右1マスへ跳ぶ。直線移動ではなく step_offset の
	# ジャンプなので、途中セルは見ない。
	configure(
		"knight",
		"Knight",
		"N",
		[Vector2i(-1, -2), Vector2i(1, -2)],
		[]
	)
