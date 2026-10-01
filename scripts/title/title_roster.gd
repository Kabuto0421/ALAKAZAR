extends RefCounted
## The hero side of the title art, one picture per character (assets/title/units/, laid out
## by assets/title/units.json: where each stands on the 1920x1080 canvas and in what order).
## Every fairy in it belongs to a fairy of the game; the title screen draws it in colour
## once that fairy has been used (see FairyBook) and as a dark silhouette until then.

const UNITS_JSON := "res://assets/title/units.json"
const FOLDER := "res://assets/title/"
## Which fairy of the game each picture is ("" = always shown: the hero).
const ITEM_OF := {
	"hero": "",
	"blessing_fairy": "blessing_fairy",
	"freeze_fairy": "freeze_fairy",
	"gravity_fairy": "gravity_fairy",
	"magic_bolt_fairy": "magic_bolt",
	"meteor_fairy": "meteor_fairy",
	"slash_fairy": "slash_fairy",
	"warp_fairy": "warp_fairy",
	"guardian_fairy": "guardian_fairy",
	"holy_spirit": "holy_spirit",
	"knight": "holy_spirit",  # the holy knights the holy spirit leaves
	"acorn_fairy": "acorn_fairy",
	"firework_fairy": "firework_fairy",
	"axe_spirit": "axe_spirit",
	"wall_fairy": "wall_fairy",
	"stealth_fairy": "stealth_fairy",
	"shadow_stitch": "shadow_stitch",
	"abyss_spirit": "abyss_spirit",
	"capacitor_fairy": "capacitor_fairy",
	"wolf": "lone_wolf",
	"cannon": "cannon_fairy",
	"vane": "vane_cannon",
	"glutton_fairy": "glutton_fairy",
}

## The hero-side pictures, back to front: {id, item, texture, rect}.
static func heroes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file := FileAccess.open(UNITS_JSON, FileAccess.READ)
	if file == null:
		return result
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Array:
		return result
	var units: Array = data.filter(func(u: Dictionary) -> bool: return u.side == "heroes")
	units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.z) < int(b.z))
	for unit in units:
		result.append({
			"id": str(unit.id),
			"item": ITEM_OF.get(str(unit.id), ""),
			"texture": load(FOLDER + str(unit.file)),
			"rect": Rect2(float(unit.x), float(unit.y), float(unit.w), float(unit.h)),
		})
	return result

## The game's fairies the pictures stand for.
static func shown_items() -> Array[String]:
	var result: Array[String] = []
	for id in ITEM_OF:
		var item: String = ITEM_OF[id]
		if item != "" and not result.has(item):
			result.append(item)
	return result
