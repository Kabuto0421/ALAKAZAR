@tool
extends Node2D

const Layout = preload("res://scripts/formation_layout.gd")

enum EnemyKind { INFANTRY, MINER, HEAVY, CAVALRY }
@export var enemy_kind: EnemyKind = EnemyKind.INFANTRY:
	set(value):
		enemy_kind = value
		queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var snapped := Layout.cell_center(Layout.cell_at(position))
		if position != snapped:
			position = snapped

func _draw() -> void:
	var color: Color = [Color("bdc7c4"),Color("2bdcc8"),Color("ffbd59"),Color("8ab8ff")][enemy_kind]
	draw_circle(Vector2.ZERO,22,Color("091314"))
	draw_circle(Vector2.ZERO,19,color)
	draw_circle(Vector2.ZERO,13,Color("172221"))
	var label: String = ["歩","地","重","跳"][enemy_kind]
	var font := ThemeDB.fallback_font
	if font:
		draw_string(font,Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x/2.0,7),label,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("f4f0df"))
