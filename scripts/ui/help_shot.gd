extends Control
## One picture in the field manual: real game screenshots (from assets/help,
## taken by tools/capture_help.gd). Several frames play in turn like a flipbook.

const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const STEP := 1.3
var frames: Array[Texture2D] = []
## Optional label per frame ("−1 AP", "0 AP", a weapon name...), shown as a badge.
var tags: Array = []
var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0c181b"))
	if frames.is_empty():
		return
	var index := int(time / STEP) % frames.size()
	var texture := frames[index]
	# Fit the screenshot inside the box, keeping its shape.
	# The picture fills the box above a strip for the frame's tag and the dots.
	var strip := 44.0 if not tags.is_empty() else 20.0
	var fit := minf((size.x - 8) / texture.get_width(), (size.y - strip - 6) / texture.get_height())
	var extent := texture.get_size() * fit
	draw_texture_rect(texture, Rect2(Vector2((size.x - extent.x) / 2, 4), extent), false)
	var tag: String = tags[index] if index < tags.size() else ""
	if tag != "":
		var color := Color("ffd35b") if "AP" in tag and not "0 AP" in tag else Color("2bdcc8") if "0 AP" in tag else Color("ff8b8f") if "敵" in tag else Color("e5dfc5")
		var width := FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 16
		var badge := Rect2(Vector2((size.x - width) / 2, size.y - 46), Vector2(width, 26))
		draw_rect(badge, Color(0.02, 0.05, 0.06, 0.92))
		draw_rect(badge, color, false, 2)
		draw_string(FONT, badge.position + Vector2(8, 19), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
	# Frame dots so a flipbook reads as "before -> after".
	if frames.size() > 1:
		var left := size.x / 2 - (frames.size() - 1) * 9
		for k in frames.size():
			draw_circle(Vector2(left + k * 18, size.y - 9), 4, Color("ffd35b") if k == index else Color("3d5753"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("2c4a44"), false, 2)
