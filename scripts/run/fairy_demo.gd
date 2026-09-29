extends Control
## A fairy's animated example (the same one the battle panel shows while it is
## selected), scaled to fill a reward card.

const ItemPreview = preload("res://scripts/items/item_preview.gd")

var model: RefCounted
var id := ""
var time := 0.0
## 1: show the class-up version, 0: the base one, -1: as the model has it.
var plus := -1

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1416"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("26403d"), false, 1)
	if model == null or id == "":
		return
	ItemPreview.paint(self, model, id, time, Rect2(Vector2.ZERO, size).grow(-6), plus)
