extends Control
## The frame around a reward card, in the material of its rarity: wood (コモン),
## jade (アンコモン), lapis lazuli (レア) and gold (激レア). The material is a tiled
## pixel texture along each side (the grain runs along it), with a bevel of light
## on the outer edge and shade on the inner one, a stud in each corner, and on
## gold a shine that sweeps around the frame.

const Rarity = preload("res://scripts/run/rarity.gd")
const TEXTURES = [
	preload("res://assets/sprites/ui/frame_wood.png"),
	preload("res://assets/sprites/ui/frame_jade.png"),
	preload("res://assets/sprites/ui/frame_lapis.png"),
	preload("res://assets/sprites/ui/frame_gold.png"),
]
## Studs in the corners: wood has iron nails, jade a pale bead, lapis gold studs,
## gold a small ruby.
const STUDS = [Color("3a2a1c"), Color("d8f5e2"), Color("f2cf5a"), Color("e8455a")]
## How thick the frame is.
const THICKNESS := 10.0

var tier := Rarity.COMMON
var hover := false
var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(tier == Rarity.SUPER_RARE)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func set_hover(value: bool) -> void:
	hover = value
	queue_redraw()

func _draw() -> void:
	var t := THICKNESS
	var w := size.x
	var h := size.y
	var texture: Texture2D = TEXTURES[tier]
	# Top and bottom run along the texture; the sides use it turned a quarter.
	draw_texture_rect(texture, Rect2(0, 0, w, t), true)
	draw_texture_rect(texture, Rect2(0, h - t, w, t), true)
	for x in [0.0, w - t]:
		draw_set_transform(Vector2(x + t, t), PI / 2)
		draw_texture_rect(texture, Rect2(0, 0, h - t * 2, t), true)
	draw_set_transform(Vector2.ZERO)
	# Bevel: light along the outer top and left edges, shade along the bottom and
	# right, and a dark line where the frame meets the card.
	var light := Color(1, 1, 1, 0.35)
	var shade := Color(0, 0, 0, 0.35)
	draw_rect(Rect2(0, 0, w, 2), light)
	draw_rect(Rect2(0, 0, 2, h), light)
	draw_rect(Rect2(0, h - 2, w, 2), shade)
	draw_rect(Rect2(w - 2, 0, 2, h), shade)
	draw_rect(Rect2(t - 2, t - 2, w - t * 2 + 4, 2), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(t - 2, t - 2, 2, h - t * 2 + 4), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(t - 2, h - t, w - t * 2 + 4, 2), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(w - t, t - 2, 2, h - t * 2 + 4), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.8), false, 1)
	# A stud in each corner.
	for corner in [Vector2(t / 2, t / 2), Vector2(w - t / 2, t / 2), Vector2(t / 2, h - t / 2), Vector2(w - t / 2, h - t / 2)]:
		draw_rect(Rect2(corner - Vector2(3, 3), Vector2(6, 6)), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(corner - Vector2(2, 2), Vector2(4, 4)), STUDS[tier])
		draw_rect(Rect2(corner - Vector2(2, 2), Vector2(2, 2)), Color(1, 1, 1, 0.55))
	# Gold: a band of light sweeping around the frame.
	if tier == Rarity.SUPER_RARE:
		var perimeter := (w + h) * 2
		var at := fmod(time * 180.0, perimeter + 200.0) - 100.0
		for k in 3:
			var p := at - k * 10.0
			_shine(p, Color(1, 1, 0.9, 0.5 - k * 0.15))
	if hover:
		draw_rect(Rect2(0, 0, w, t), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(0, h - t, w, t), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(0, t, t, h - t * 2), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(w - t, t, t, h - t * 2), Color(1, 1, 1, 0.12))

## A short slanted streak of light at distance `p` along the frame (clockwise from
## the top-left corner).
func _shine(p: float, color: Color) -> void:
	var t := THICKNESS
	var w := size.x
	var h := size.y
	if p < 0.0:
		return
	if p < w:
		draw_line(Vector2(p, 0), Vector2(p - 5, t), color, 3)
	elif p < w + h:
		var y := p - w
		draw_line(Vector2(w, y), Vector2(w - t, y - 5), color, 3)
	elif p < w * 2 + h:
		var x := w - (p - w - h)
		draw_line(Vector2(x, h), Vector2(x + 5, h - t), color, 3)
	elif p < (w + h) * 2:
		var y := h - (p - w * 2 - h)
		draw_line(Vector2(0, y), Vector2(t, y + 5), color, 3)
