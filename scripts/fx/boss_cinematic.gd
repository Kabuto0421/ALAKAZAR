extends Node2D
## The Prison King's big moments, drawn over the whole screen:
##   "intro" — fade to black, the throne-hall title art, his name, fade back in;
##   "rage"  — a red flash, the screen darkens, his portrait bursts in with the warning;
##   "fall"  — white bursts on the king, a full flash, "監獄の王、陥落".
## The battle view waits for LIFE[mode] before play resumes.

const TITLE = preload("res://assets/sprites/boss/boss_title.png")
const PORTRAIT = preload("res://assets/sprites/boss/prison_king_portrait.png")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const LIFE := {"intro": 3.8, "rage": 2.6, "fall": 3.0}
const RED := Color("ff3b4a")
const CYAN := Color("6fe8ff")

var mode := "intro"
var time := 0.0
var screen := Rect2(0, 0, 1152, 720)
## Where the king stands (the fall bursts from there).
var focus := Vector2(576, 360)
## What the rage and the fall shake (the battle board).
var shake_target: Node2D

func _ready() -> void:
	z_index = 100

func _process(delta: float) -> void:
	time += delta
	var parent := shake_target
	if is_instance_valid(parent):
		var shake := 0.0
		if mode == "rage" and time < 1.2:
			shake = 10.0 * (1.0 - time / 1.2)
		elif mode == "fall" and time < 1.4:
			shake = 14.0 * (1.0 - time / 1.4)
		parent.position = Vector2(sin(time * 97.0), cos(time * 83.0)) * shake
	if time >= LIFE[mode]:
		if is_instance_valid(parent):
			parent.position = Vector2.ZERO
		# It rides its own canvas layer, which goes with it.
		var layer := get_parent()
		if layer is CanvasLayer:
			layer.queue_free()
		else:
			queue_free()
		return
	queue_redraw()

func _draw() -> void:
	match mode:
		"intro":
			_draw_intro()
		"rage":
			_draw_rage()
		"fall":
			_draw_fall()

func _fade(t0: float, t1: float) -> float:
	return clampf((time - t0) / (t1 - t0), 0.0, 1.0)

func _text(center: Vector2, text: String, size: int, color: Color, outline: Color) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := center - Vector2(width / 2, -size * 0.35)
	for offset in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2)]:
		draw_string(FONT, at + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline)
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_intro() -> void:
	var dark := _fade(0.0, 0.4) * (1.0 - _fade(3.2, 3.8))
	draw_rect(screen, Color(0, 0, 0, dark))
	var art := _fade(0.5, 1.3) * (1.0 - _fade(2.8, 3.3))
	if art > 0.0:
		# The throne hall, drifting slowly closer.
		var zoom := 1.1 - 0.08 * _fade(0.5, 3.3)
		var size := Vector2(1152, 648) * zoom
		draw_texture_rect(TITLE, Rect2(screen.get_center() - size / 2 + Vector2(0, -20), size), false, Color(1, 1, 1, art))
		# Letterbox bars.
		draw_rect(Rect2(screen.position, Vector2(screen.size.x, 90)), Color(0, 0, 0, art))
		draw_rect(Rect2(screen.position + Vector2(0, screen.size.y - 150), Vector2(screen.size.x, 150)), Color(0, 0, 0, art))
	var words := _fade(1.2, 1.7) * (1.0 - _fade(2.9, 3.3))
	if words > 0.0:
		var base := Vector2(576, 600)
		_text(base + Vector2(0, -58), "最 終 決 戦", 22, Color(CYAN, words), Color(0, 0, 0, words))
		_text(base, "監獄の王", 64, Color(1, 0.95, 0.95, words), Color(RED.darkened(0.5), words))
		_text(base + Vector2(0, 46), "死者を蘇らせる、牢獄の支配者", 20, Color(0.85, 0.85, 0.9, words), Color(0, 0, 0, words))

func _draw_rage() -> void:
	var flash := 1.0 - _fade(0.0, 0.3)
	var dark := _fade(0.05, 0.3) * (1.0 - _fade(2.1, 2.6))
	draw_rect(screen, Color(0.08, 0, 0, dark * 0.72))
	if flash > 0.0:
		draw_rect(screen, Color(1, 0.15, 0.15, flash * 0.7))
	# Red streaks racing across.
	for k in 6:
		var y := screen.position.y + 120 + k * 90
		var x := fmod(time * 1600.0 + k * 377.0, screen.size.x + 400) - 200 + screen.position.x
		draw_line(Vector2(x, y), Vector2(x + 260, y), Color(1, 0.2, 0.2, dark * 0.5), 3)
	# The portrait bursts in from the right, pulsing red.
	var slide := _fade(0.1, 0.45)
	var size := 460.0 * (1.0 + 0.04 * sin(time * 18.0))
	var at := Vector2(lerpf(screen.end.x + 40, 640, slide), 360 - size / 2)
	var pulse := 0.75 + 0.25 * sin(time * 14.0)
	draw_texture_rect(PORTRAIT, Rect2(at, Vector2.ONE * size), false, Color(1, pulse, pulse, dark))
	var words := _fade(0.35, 0.6) * (1.0 - _fade(2.1, 2.5))
	if words > 0.0:
		_text(Vector2(360, 330), "監獄の王が", 36, Color(1, 0.9, 0.9, words), Color(0, 0, 0, words))
		_text(Vector2(360, 390), "怒り狂った", 60, Color(RED, words), Color(0, 0, 0, words))
		_text(Vector2(360, 450), "要塞監獄が兵を2体ずつ送り出す", 20, Color(1, 0.8, 0.8, words), Color(0, 0, 0, words))

func _draw_fall() -> void:
	# Bursts of light tearing out of the king, then a white-out.
	for k in 4:
		var t := time - k * 0.18
		if t > 0.0 and t < 0.9:
			draw_arc(focus, 30 + t * 520.0, 0, TAU, 64, Color(1, 1, 1, (1.0 - t / 0.9) * 0.9), 6, true)
	for k in 10:
		var dir := Vector2.from_angle(k * TAU / 10 + 0.3)
		var t := clampf(time / 1.0, 0.0, 1.0)
		if time < 1.1:
			draw_line(focus + dir * 40 * t, focus + dir * (60 + 480 * t), Color(CYAN, 0.8 * (1.0 - t)), 4)
	var white := _fade(0.8, 1.05) * (1.0 - _fade(1.05, 1.9))
	if white > 0.0:
		draw_rect(screen, Color(1, 1, 1, white))
	var dim := _fade(1.2, 1.5) * (1.0 - _fade(2.5, 3.0))
	if dim > 0.0:
		draw_rect(screen, Color(0, 0, 0, dim * 0.55))
		_text(Vector2(576, 340), "監獄の王、陥落", 60, Color(1, 0.97, 0.9, dim), Color(0.2, 0.1, 0, dim))
		_text(Vector2(576, 400), "鎖は解き放たれた", 22, Color(CYAN, dim), Color(0, 0, 0, dim))
