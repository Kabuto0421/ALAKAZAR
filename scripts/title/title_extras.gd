extends Node2D
## Fairies added to the game after the title art was painted. The art (layer_10_heroes.png)
## shows the fairies listed in IN_ART; every other fairy in the game is set out here
## automatically, in the free sky above the row of fairies, so a new fairy shows up on the
## title screen without anyone touching the art or this file. (Paint it into the art and
## add its id to IN_ART, and it leaves this layer.)
##
## This node is a child of the heroes layer, so it moves, fades and glows with them; all
## its coordinates are the art's own (1920x1080).

const Rules = preload("res://scripts/battle_model.gd")
const ItemPreview = preload("res://scripts/items/item_preview.gd")

## The fairies the art already shows.
const IN_ART: Array[String] = [
	"abyss_spirit",
	"acorn_fairy",
	"axe_spirit",
	"blessing_fairy",
	"cannon_fairy",
	"capacitor_fairy",
	"firework_fairy",
	"freeze_fairy",
	"glutton_fairy",
	"gravity_fairy",
	"guardian_fairy",
	"holy_spirit",
	"lone_wolf",
	"magic_bolt",
	"meteor_fairy",
	"shadow_stitch",
	"slash_fairy",
	"stealth_fairy",
	"vane_cannon",
	"wall_fairy",
	"warp_fairy"
]
## The free space: above the fairies and left of the logo's shadow (checked against the
## art's pixels by the tests).
const AREA := Rect2(90, 300, 800, 130)
const SLOT := Vector2(76, 64)
const SIZE := 54.0

var items: Array[Resource] = []
var time := 0.0

## The fairies the art does not show, in the game's own order.
static func missing() -> Array[Resource]:
	var result: Array[Resource] = []
	for item in Rules.ITEMS:
		if not IN_ART.has(item.id) and item.icon != null:
			result.append(item)
	return result

## Where the n-th extra fairy stands (its centre): left to right, then the next row.
static func slot_center(index: int) -> Vector2:
	var columns := int(AREA.size.x / SLOT.x)
	return AREA.position + Vector2((index % columns + 0.5) * SLOT.x, (index / columns + 0.5) * SLOT.y)

## How many fit in the free space.
static func capacity() -> int:
	return int(AREA.size.x / SLOT.x) * int(AREA.size.y / SLOT.y)

func _ready() -> void:
	items = missing()
	if items.size() > capacity():
		push_warning("title screen: %d new fairies but room for %d" % [items.size(), capacity()])

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	for index in mini(items.size(), capacity()):
		var item: Resource = items[index]
		var bob := sin(time * 1.6 + index * 1.3) * 4.0
		var at := slot_center(index) + Vector2(0, bob)
		draw_circle(at, SIZE * 0.62, Color(item.color, 0.10 + 0.05 * sin(time * 2.0 + index)))
		var texture: Texture2D = item.icon
		draw_texture_rect_region(texture, Rect2(at - Vector2.ONE * SIZE / 2, Vector2.ONE * SIZE), ItemPreview._crop(texture))
