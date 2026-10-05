extends Control
## The player's HP as a row of hearts (same shape as the battle screen's).

var hp := 0
var max_hp := 5
var step := 28.0
var heart_size := 24.0

func _draw() -> void:
	for i in max_hp:
		var center := Vector2(heart_size / 2.0 + i * step, size.y / 2.0)
		var half := heart_size * 0.5
		var filled := i < hp
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
		draw_colored_polygon(points, Color("ff5b62") if filled else Color("341d25"))
		draw_polyline(points, Color("ff8b8f") if filled else Color("70434a"), 1.2, true)
