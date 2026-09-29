extends Control
## A fairy's animated example (the same one the battle panel shows while it is
## selected), scaled into a reward card. The example is drawn in the battle
## panel's coordinates, so this maps that region onto the control.

const ItemPreview = preload("res://scripts/items/item_preview.gd")
const UnitView = preload("res://scripts/unit_view.gd")
const Rules = preload("res://scripts/battle_model.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
## The examples use these from the battle view.
const ABYSS_PIT = preload("res://assets/sprites/spirits/abyss_pit.png")
## The battle panel region the examples are drawn in.
const REGION := Rect2(846, 196, 272, 170)
## The part of that region each example really uses (measured by rendering them over
## time, plus a margin), so each one is cropped to its content and drawn as large as fits.
const REGIONS := {
	"magic_bolt": Rect2(841, 221, 269, 78),
	"stealth_fairy": Rect2(891, 219, 210, 96),
	"acorn_fairy": Rect2(847, 203, 241, 112),
	"warp_fairy": Rect2(848, 217, 254, 97),
	"wall_fairy": Rect2(841, 206, 269, 93),
	"cannon_fairy": Rect2(841, 207, 269, 92),
	"vane_cannon": Rect2(918, 218, 177, 113),
	"firework_fairy": Rect2(919, 204, 112, 115),
	"capacitor_fairy": Rect2(892, 214, 166, 134),
	"slash_fairy": Rect2(951, 193, 49, 150),
	"flying_slash": Rect2(851, 213, 252, 111),
	"axe_spirit": Rect2(853, 209, 246, 109),
	"holy_spirit": Rect2(870, 189, 205, 138),
	"shadow_stitch": Rect2(847, 213, 255, 82),
	"lone_wolf": Rect2(847, 212, 241, 104),
	"abyss_spirit": Rect2(847, 213, 255, 82),
	"gravity_fairy": Rect2(847, 214, 262, 81),
	"glutton_fairy": Rect2(848, 212, 240, 104),
	"freeze_fairy": Rect2(871, 193, 181, 168),
	"blessing_fairy": Rect2(860, 196, 227, 165),
	"meteor_fairy": Rect2(846, 140, 266, 221),
	"guardian_fairy": Rect2(852, 164, 224, 197),
}

var model: RefCounted
var id := ""
var time := 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1416"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("26403d"), false, 1)
	if model == null or id == "":
		return
	var region: Rect2 = REGIONS.get(id, REGION)
	var zoom := minf(minf(size.x / region.size.x, size.y / region.size.y), 1.6)
	var offset := (size - region.size * zoom) / 2.0 - region.position * zoom
	draw_set_transform(offset, 0.0, Vector2.ONE * zoom)
	ItemPreview.paint(self, model, id, time)
	draw_set_transform(Vector2.ZERO)

func _text(at: Vector2, text: String, font_size: int = 20, color: Color = Color("e5dfc5"), _font: Font = null) -> void:
	for line_index in text.split("\n").size():
		draw_string(FONT, at + Vector2(0, line_index * (font_size + 4)), text.split("\n")[line_index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_player_portrait(weapon_index: int, center: Vector2, side: float, facing_index: int = 2) -> void:
	var cell := UnitView.PLAYER_ATLAS_CELL
	var row: int = Rules.WEAPONS[weapon_index].row
	draw_texture_rect_region(UnitView.PLAYER_ATLAS, Rect2(center - Vector2.ONE * side / 2, Vector2.ONE * side), Rect2(facing_index * cell, row * cell, cell, cell))
