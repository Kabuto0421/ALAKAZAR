extends Control
## A yellow "+" badge filling this control (upgraded fairy / forged weapon).

const Icon = preload("res://scripts/items/spirit_icon.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	Icon.paint_plus(self, Vector2(size.x, 0), minf(size.x, size.y))
