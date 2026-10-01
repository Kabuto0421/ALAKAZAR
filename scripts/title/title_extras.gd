extends Node2D
## Fairies added to the game after the title art was painted. The art (assets/title/units)
## has a picture for the fairies TitleRoster lists; every other fairy in the game is set out here
## automatically, in the free sky above the row of fairies, so a new fairy shows up on the
## title screen without anyone touching the art or this file. (Paint it into the art and
## add it to TitleRoster.ITEM_OF, and it leaves this layer.) Like the pictures, they stand
## as silhouettes until the fairy has been used.
##
## This node is a child of the heroes layer, so it moves, fades and glows with them; all
## its coordinates are the art's own (1920x1080).

const Rules = preload("res://scripts/battle_model.gd")
const ItemPreview = preload("res://scripts/items/item_preview.gd")
const Roster = preload("res://scripts/title/title_roster.gd")
const FairyBook = preload("res://scripts/fairy_book.gd")
## An unused fairy stands as a dark silhouette.
const LOCKED := Color(0.06, 0.09, 0.12, 0.62)

## The fairies that have a picture of their own (see TitleRoster).
static func in_art() -> Array[String]:
	return Roster.shown_items()

## The free space: above the fairies and left of the logo's shadow (checked against the
## art's pixels by the tests).
const AREA := Rect2(90, 292, 800, 142)
const SLOT := Vector2(84, 71)
const SIZE := 68.0

var items: Array[Resource] = []
var time := 0.0

## The fairies the art does not show, in the game's own order.
static func missing() -> Array[Resource]:
	var result: Array[Resource] = []
	for item in Rules.ITEMS:
		if not in_art().has(item.id) and item.icon != null:
			result.append(item)
	return result

## Where the n-th extra fairy stands (its centre): left to right along the row just above
## the painted fairies (the same left edge and spacing as theirs), then the row above that.
static func slot_center(index: int) -> Vector2:
	var columns := int(AREA.size.x / SLOT.x)
	return Vector2(AREA.position.x + (index % columns + 0.5) * SLOT.x, AREA.end.y - (index / columns + 0.5) * SLOT.y)

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
		var texture: Texture2D = item.icon
		draw_texture_rect_region(texture, Rect2(at - Vector2.ONE * SIZE / 2, Vector2.ONE * SIZE), ItemPreview._crop(texture), Color.WHITE if FairyBook.has_used(item.id) else LOCKED)
