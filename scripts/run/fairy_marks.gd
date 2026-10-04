extends Control
## Under a fairy card's example: a summoned ally's HP and AP in the player's own
## marks (hearts and gold boxes), and the guardian's list of fairies it calls back.

const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const Units = preload("res://scripts/unit_view.gd")
const STEALTH = preload("res://assets/sprites/spirits/stealth_fairy.png")
const WALL = preload("res://assets/sprites/spirits/wall_fairy.png")
const GOLD := Color("ffd35b")

var hp := 0
var ap := 0
## The guardian card: the summons it calls back, as icons with their names.
var calls := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var y := 0.0
	if hp > 0:
		draw_string(FONT, Vector2(0, 17), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e5dfc5"))
		# Long HP rows (a class-up wall's 10) tighten so the AP still fits inside the card.
		var step := clampf((size.x - 34.0 - 8.0 - 28.0 - ap * 22.0 - 4.0) / hp, 9.0, 21.0)
		for i in hp:
			_heart(Vector2(34 + i * step, 11), minf(17.0, step * 0.85 + 2.0))
		var ap_x := 42.0 + hp * step
		draw_string(FONT, Vector2(ap_x, 17), "AP", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
		for i in ap:
			draw_rect(Rect2(ap_x + 26 + i * 22, 3, 18, 16), GOLD)
		y += 26
	if calls:
		var icons := [[STEALTH, Rect2()], [Units.ACORN, Rect2()], [Units.WOLF_SHEET, Rect2(288,36,192,192)], [Units.HOLY_SPIRIT, Rect2()], [Units.GLUTTON, Rect2()], [WALL, Rect2()]]
		var names := ["隠密", "どんぐり", "一匹狼", "聖精霊", "暴食", "壁"]
		var step := size.x / icons.size()
		for k in icons.size():
			var center := Vector2(step * (k + 0.5), y + 11)
			var rect := Rect2(center - Vector2(11, 11), Vector2(22, 22))
			draw_rect(rect.grow(1), Color("192828"))
			if icons[k][1] == Rect2():
				draw_texture_rect(icons[k][0], rect, false)
			else:
				draw_texture_rect_region(icons[k][0], rect, icons[k][1])
			var name: String = names[k]
			var width := FONT.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(FONT, Vector2(center.x - width / 2, y + 33), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e5dfc5"))

## The same heart the player's HP uses.
func _heart(center: Vector2, side: float) -> void:
	var half := side * 0.5
	var points := PackedVector2Array([
		center + Vector2(-half, -half*0.08),
		center + Vector2(-half, -half*0.38),
		center + Vector2(-half*0.68, -half*0.64),
		center + Vector2(-half*0.30, -half*0.74),
		center + Vector2(0, -half*0.36),
		center + Vector2(half*0.30, -half*0.74),
		center + Vector2(half*0.68, -half*0.64),
		center + Vector2(half, -half*0.38),
		center + Vector2(half, -half*0.08),
		center + Vector2(0, half*0.72),
	])
	draw_colored_polygon(points, Color("ff5b62"))
	draw_polyline(points, Color("ff8b8f"), 1.2, true)
