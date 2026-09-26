@tool
extends Node2D

const Layout = preload("res://scripts/formation_layout.gd")

enum EnemyKind { INFANTRY, MINER, HEAVY, CAVALRY, RECRUIT, HORSE, JAVELIN, ARCHER }
@export var enemy_kind: EnemyKind = EnemyKind.INFANTRY:
	set(value):
		enemy_kind = value
		queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var size: int = get_parent().board_size if get_parent().get_script() == Layout else Layout.SIZE
		var snapped := Layout.cell_center(Layout.cell_at(position,size))
		if position != snapped:
			position = snapped

func _draw() -> void:
	var color: Color = [Color("bdc7c4"),Color("2bdcc8"),Color("ffbd59"),Color("8ab8ff"),Color("c6d4a0"),Color("d9a066"),Color("e38a8a"),Color("a6e08a")][enemy_kind]
	draw_circle(Vector2.ZERO,22,Color("091314"))
	draw_circle(Vector2.ZERO,19,color)
	draw_circle(Vector2.ZERO,13,Color("172221"))
	var label: String = ["歩","地","重","跳","歩1","馬","槍","弓"][enemy_kind]
	var font := ThemeDB.fallback_font
	if font:
		draw_string(font,Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x/2.0,7),label,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("f4f0df"))
