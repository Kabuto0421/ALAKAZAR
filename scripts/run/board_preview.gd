extends Control
## The next fight's board, read from its formation scene: holes, the player's start and the enemies.
## Small, it shows the shape and dots for the enemies; large, it names each enemy with its letter.

const FormationLayout = preload("res://scripts/formation_layout.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const COLORS := [Color("bdc7c4"),Color("2bdcc8"),Color("ffbd59"),Color("8ab8ff"),Color("c6d4a0"),Color("d9a066"),Color("e38a8a"),Color("a6e08a"),Color("ff5b62"),Color("6f8fb0"),Color("ff9a4a"),Color("ffd35b"),Color("9ab8c8"),Color("7fffd0"),Color("ffd35b"),Color("d8e2ee"),Color("ff3b6a"),Color("7a8aa0"),Color("48e6d8"),Color("d9a0ff"),Color("ff7ac8"),Color("3fd0e0")]
const LABELS := ["歩","地","重","跳","歩1","馬","槍","弓","突","監","執","ロ","盾","解","金","銀","王","要","嵐","×","道","竜"]

var board_size := 1
var holes: Array[Vector2i] = []
var start := Vector2i.ZERO
var enemies: Array[Dictionary] = []
## Large previews write the enemy's letter inside its tile.
var large := false

func load_scene(scene: PackedScene) -> void:
	var layout: Node = scene.instantiate()
	board_size = layout.board_size
	holes.assign(layout.holes)
	start = layout.player_start
	enemies.clear()
	for placement in layout.get_children():
		enemies.append({"kind": int(placement.enemy_kind), "cell": FormationLayout.cell_at(placement.position, board_size)})
	layout.free()
	queue_redraw()

func _draw() -> void:
	var tile := floorf(minf(size.x, size.y) / float(board_size))
	var origin := (size - Vector2.ONE * tile * board_size) / 2.0
	for y in board_size:
		for x in board_size:
			var cell := Vector2i(x, y)
			var at := origin + Vector2(cell) * tile
			if holes.has(cell):
				draw_rect(Rect2(at, Vector2.ONE * tile), Color("05090a"))
				continue
			draw_rect(Rect2(at, Vector2.ONE * tile), Color("1c2b2b"))
			draw_rect(Rect2(at, Vector2.ONE * tile), Color("2c4040"), false, 1.0)
	var dot := tile * (0.62 if large else 0.7)
	var player_at := origin + (Vector2(start) + Vector2.ONE * 0.5) * tile
	draw_rect(Rect2(player_at - Vector2.ONE * dot / 2.0, Vector2.ONE * dot), Color("7be08a"))
	if large:
		draw_string(FONT, player_at + Vector2(-tile * 0.18, tile * 0.18), "自", HORIZONTAL_ALIGNMENT_LEFT, -1, int(tile * 0.5), Color("0a1417"))
	for enemy in enemies:
		var kind: int = enemy.kind
		var center: Vector2 = origin + (Vector2(enemy.cell) + Vector2.ONE * 0.5) * tile
		draw_circle(center, dot / 2.0, COLORS[kind])
		if large:
			var text: String = LABELS[kind]
			var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tile * 0.46)).x
			draw_string(FONT, center + Vector2(-width / 2.0, tile * 0.16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tile * 0.46), Color("0a1417"))
