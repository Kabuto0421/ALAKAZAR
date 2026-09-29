extends Control
## A fairy's animated example (the same one the battle panel shows while it is
## selected), scaled to fill a reward card.

const ItemPreview = preload("res://scripts/items/item_preview.gd")

var model: RefCounted
var id := ""
var time := 0.0
## 1: show the class-up version, 0: the base one, -1: as the model has it.
var plus := -1
## A small note in the top-left corner (e.g. which weapon the example assumes).
var legend := ""
var legend_color := Color.WHITE

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
	var area := Rect2(Vector2.ZERO, size).grow(-6)
	if legend != "":
		draw_string(load("res://scripts/run/choice_card.gd").label_font(), Vector2(6, 15), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, legend_color)
		area = Rect2(6, 20, size.x - 12, size.y - 26)
	ItemPreview.paint(self, model, id, time, area, plus)
