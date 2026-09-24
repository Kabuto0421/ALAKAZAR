extends Node2D
## Title screen: plays the title loop and starts the battle on any click or key.

const BgmPlayer = preload("res://scripts/audio/bgm_player.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LATIN = preload("res://assets/fonts/VT323-Regular.ttf")
const BATTLE_SCENE := "res://main.tscn"
const SCREEN = Vector2(1152,720)
const UI_SCALE := 1.5
const INK = Color("e5dfc5")
const MUTED = Color("92b3ae")
const CYAN = Color("2bdcc8")

var bgm: Node
var clock := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * UI_SCALE
	bgm = BgmPlayer.new()
	add_child(bgm)
	bgm.play_track(BgmPlayer.TITLE)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			bgm.toggle_mute()
			return
		_start()
	elif event is InputEventMouseButton and event.pressed:
		_start()

func _start() -> void:
	set_process_unhandled_input(false)
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _centered(y: float, text: String, size: int, color: Color, font: Font = LATIN) -> void:
	draw_string(font,Vector2(0,y),text,HORIZONTAL_ALIGNMENT_CENTER,SCREEN.x,size,color)

func _draw() -> void:
	for x in range(0,int(SCREEN.x)+1,64):
		draw_line(Vector2(x,0),Vector2(x,SCREEN.y),Color(CYAN,0.05))
	for y in range(0,int(SCREEN.y)+1,64):
		draw_line(Vector2(0,y),Vector2(SCREEN.x,y),Color(CYAN,0.05))
	var scan := fmod(clock*90.0,SCREEN.y)
	draw_rect(Rect2(0,scan,SCREEN.x,2),Color(CYAN,0.08))
	_centered(304,"ALAKAZAR",132,Color(CYAN,0.18))
	_centered(300,"ALAKAZAR",128,CYAN)
	_centered(350,"6x6 TACTICS",32,MUTED)
	_centered(410,"武器と向きを切り替え、包囲を突破せよ",22,INK,FONT)
	_centered(520,"CLICK OR PRESS ANY KEY",30,Color(INK,0.55+0.45*sin(clock*3.0)))
	_centered(690,"M  BGM ON / OFF",20,MUTED)
