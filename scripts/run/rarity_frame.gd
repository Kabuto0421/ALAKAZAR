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
## The thin inlaid line just inside the frame, and the metal of the corner plates.
const INLAY = [Color("e0a35a"), Color("6fe3a0"), Color("6fa8ff"), Color("ffe27a")]
const METAL = [Color("3b3329"), Color("33423a"), Color("2b3350"), Color("5a4a1e")]
## How thick the frame is.
const THICKNESS := 10.0

var tier := Rarity.COMMON
var hover := false
var time := 0.0
## Thinner on the small slots (weapon and fairy slots, the loadout).
var thickness := THICKNESS

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
	paint(self, Rect2(Vector2.ZERO, size), tier, time, thickness, hover)

## Draws the frame on any canvas (the battle screen draws its weapon slots itself).
static func paint(canvas: CanvasItem, rect: Rect2, tier: int, time: float = 0.0, t: float = THICKNESS, hover: bool = false) -> void:
	var o := rect.position
	var w := rect.size.x
	var h := rect.size.y
	var texture: Texture2D = TEXTURES[tier]
	# Top and bottom run along the texture; the sides use it turned a quarter.
	canvas.draw_texture_rect(texture, Rect2(o, Vector2(w, t)), true)
	canvas.draw_texture_rect(texture, Rect2(o + Vector2(0, h - t), Vector2(w, t)), true)
	for x in [0.0, w - t]:
		canvas.draw_set_transform(o + Vector2(x + t, t), PI / 2)
		canvas.draw_texture_rect(texture, Rect2(0, 0, h - t * 2, t), true)
	canvas.draw_set_transform(Vector2.ZERO)
	# Bevel: light along the outer top and left edges, shade along the bottom and
	# right, and a dark line where the frame meets the inside.
	var edge := 2.0 if t >= 8.0 else 1.0
	canvas.draw_rect(Rect2(o, Vector2(w, edge)), Color(1, 1, 1, 0.35))
	canvas.draw_rect(Rect2(o, Vector2(edge, h)), Color(1, 1, 1, 0.35))
	canvas.draw_rect(Rect2(o + Vector2(0, h - edge), Vector2(w, edge)), Color(0, 0, 0, 0.35))
	canvas.draw_rect(Rect2(o + Vector2(w - edge, 0), Vector2(edge, h)), Color(0, 0, 0, 0.35))
	canvas.draw_rect(Rect2(o + Vector2(t - edge, t - edge), Vector2(w - t * 2 + edge * 2, edge)), Color(0, 0, 0, 0.45))
	canvas.draw_rect(Rect2(o + Vector2(t - edge, t - edge), Vector2(edge, h - t * 2 + edge * 2)), Color(0, 0, 0, 0.45))
	canvas.draw_rect(Rect2(o + Vector2(t - edge, h - t), Vector2(w - t * 2 + edge * 2, edge)), Color(1, 1, 1, 0.15))
	canvas.draw_rect(Rect2(o + Vector2(w - t, t - edge), Vector2(edge, h - t * 2 + edge * 2)), Color(1, 1, 1, 0.15))
	canvas.draw_rect(Rect2(o, Vector2(w, h)), Color(0, 0, 0, 0.8), false, 1)
	# Depth: the inside is shaded where it meets the frame (an inset), with a thin inlaid
	# line in the material's colour just inside the edge.
	var inner := Rect2(o + Vector2(t, t), Vector2(w - t * 2, h - t * 2))
	for k in 3:
		var shade := Color(0, 0, 0, 0.30 - k * 0.09)
		canvas.draw_rect(Rect2(inner.position + Vector2(k, k), Vector2(inner.size.x - k * 2, 1)), shade)
		canvas.draw_rect(Rect2(inner.position + Vector2(k, k), Vector2(1, inner.size.y - k * 2)), shade)
	canvas.draw_rect(inner.grow(-1.0), Color(INLAY[tier], 0.55), false, 1)
	# Heavy corner plates: a metal square with a trimmed edge, a rivet and a gem.
	var plate := maxf(t * 1.7, 7.0)
	for corner in [Vector2(0, 0), Vector2(w - plate, 0), Vector2(0, h - plate), Vector2(w - plate, h - plate)]:
		var at: Vector2 = o + corner
		canvas.draw_rect(Rect2(at + Vector2(1, 1), Vector2.ONE * plate), Color(0, 0, 0, 0.45))
		canvas.draw_rect(Rect2(at, Vector2.ONE * plate), METAL[tier])
		canvas.draw_rect(Rect2(at, Vector2(plate, 1)), Color(1, 1, 1, 0.4))
		canvas.draw_rect(Rect2(at, Vector2(1, plate)), Color(1, 1, 1, 0.4))
		canvas.draw_rect(Rect2(at + Vector2(0, plate - 1), Vector2(plate, 1)), Color(0, 0, 0, 0.5))
		canvas.draw_rect(Rect2(at + Vector2(plate - 1, 0), Vector2(1, plate)), Color(0, 0, 0, 0.5))
		canvas.draw_rect(Rect2(at, Vector2.ONE * plate), Color(INLAY[tier], 0.8), false, 1)
		var c: Vector2 = at + Vector2.ONE * plate / 2.0
		var gem := maxf(2.0, plate * 0.2)
		canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -gem - 1), c + Vector2(gem + 1, 0), c + Vector2(0, gem + 1), c + Vector2(-gem - 1, 0)]), STUDS[tier])
		canvas.draw_rect(Rect2(c - Vector2(1, 1), Vector2(1.5, 1.5)), Color(1, 1, 1, 0.8))
	# A small diamond ornament on the middle of the long sides.
	if w > plate * 5.0:
		for y_edge in [t / 2.0, h - t / 2.0]:
			var m: Vector2 = o + Vector2(w / 2.0, y_edge)
			var r := maxf(2.5, t * 0.45)
			canvas.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -r), m + Vector2(r * 1.6, 0), m + Vector2(0, r), m + Vector2(-r * 1.6, 0)]), METAL[tier])
			canvas.draw_polyline(PackedVector2Array([m + Vector2(0, -r), m + Vector2(r * 1.6, 0), m + Vector2(0, r), m + Vector2(-r * 1.6, 0), m + Vector2(0, -r)]), INLAY[tier], 1)
			canvas.draw_circle(m, maxf(1.0, r * 0.35), STUDS[tier])
	# Gold: a band of light sweeping around the frame.
	if tier == Rarity.SUPER_RARE:
		var perimeter := (w + h) * 2
		var at := fmod(time * 180.0, perimeter + 200.0) - 100.0
		for k in 3:
			_shine(canvas, rect, t, at - k * 10.0, Color(1, 1, 0.9, 0.5 - k * 0.15))
	if hover:
		var glow := Color(1, 1, 1, 0.14)
		canvas.draw_rect(Rect2(o, Vector2(w, t)), glow)
		canvas.draw_rect(Rect2(o + Vector2(0, h - t), Vector2(w, t)), glow)
		canvas.draw_rect(Rect2(o + Vector2(0, t), Vector2(t, h - t * 2)), glow)
		canvas.draw_rect(Rect2(o + Vector2(w - t, t), Vector2(t, h - t * 2)), glow)

## A short slanted streak of light at distance `p` along the frame (clockwise from
## the top-left corner).
static func _shine(canvas: CanvasItem, rect: Rect2, t: float, p: float, color: Color) -> void:
	var o := rect.position
	var w := rect.size.x
	var h := rect.size.y
	if p < 0.0:
		return
	if p < w:
		canvas.draw_line(o + Vector2(p, 0), o + Vector2(p - 5, t), color, 3)
	elif p < w + h:
		var y := p - w
		canvas.draw_line(o + Vector2(w, y), o + Vector2(w - t, y - 5), color, 3)
	elif p < w * 2 + h:
		var x := w - (p - w - h)
		canvas.draw_line(o + Vector2(x, h), o + Vector2(x + 5, h - t), color, 3)
	elif p < (w + h) * 2:
		var y := h - (p - w * 2 - h)
		canvas.draw_line(o + Vector2(0, y), o + Vector2(t, y + 5), color, 3)
