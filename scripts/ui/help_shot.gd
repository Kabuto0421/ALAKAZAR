extends Control
## One picture in the field manual: real game screenshots (from assets/help,
## taken by tools/capture_help.gd). Several frames play in turn like a flipbook.

const STEP := 1.2
var frames: Array[Texture2D] = []
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
	var fit := minf((size.x - 8) / texture.get_width(), (size.y - 22) / texture.get_height())
	var extent := texture.get_size() * fit
	draw_texture_rect(texture, Rect2((size - extent) / 2 - Vector2(0, 7), extent), false)
	# Frame dots so a flipbook reads as "before -> after".
	if frames.size() > 1:
		var left := size.x / 2 - (frames.size() - 1) * 9
		for k in frames.size():
			draw_circle(Vector2(left + k * 18, size.y - 9), 4, Color("ffd35b") if k == index else Color("3d5753"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("2c4a44"), false, 2)
