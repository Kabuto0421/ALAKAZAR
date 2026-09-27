extends Button

const Weapons = preload("res://scripts/run/weapon_catalog.gd")
const Diagram = preload("res://scripts/run/range_diagram.gd")
const PlusBadge = preload("res://scripts/items/plus_badge.gd")
var offer: Dictionary
var model: RefCounted
var action_text := "選ぶ"
## Overrides the "武器" / "妖精" tag in the corner.
var tag := ""
## Comparison against the current loadout, drawn on the range diagram.
var context: Array[Vector2i] = []
## One line under the stats: what this choice changes.
var note := ""
var note_color := Color("92b3ae")
## Camp: show the item as it will be after forging / the class-up.
var preview_plus := false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var accent := Color("2bdcc8")
	var title := ""
	var description := ""
	var plus := false
	var circle := false
	var fairy_id := ""
	if offer.kind == "weapon":
		var weapon: Dictionary = Weapons.DATA[int(offer.value)]
		accent = Color(weapon.color)
		title = weapon.name
		description = weapon.detail
		plus = preview_plus or (model != null and model.weapon_power.has(int(offer.value)))
		circle = offer.get("enchant", "") == "circle" or (model != null and model.is_circle(int(offer.value)))
	else:
		fairy_id = str(offer.value)
		# The slash spirit's class-up is an evolution: preview the new fairy itself.
		if preview_plus and model.EVOLUTIONS.has(fairy_id):
			fairy_id = model.EVOLUTIONS[fairy_id]
		var item: Resource = model.item_definition(fairy_id)
		accent = item.color
		title = item.title
		plus = model.is_plus(fairy_id) or (preview_plus and model.PLUS_TEXT.has(fairy_id) and fairy_id == str(offer.value))
		description = model.PLUS_TEXT[fairy_id][1] if plus else item.description
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("172b2b") if state in ["hover","pressed"] else Color("0c181b")
		style.border_color = accent
		style.set_border_width_all(3 if state in ["hover","pressed","disabled"] else 1)
		style.set_corner_radius_all(8)
		add_theme_stylebox_override(state,style)
	_label(Vector2(14,10),tag if tag != "" else "武器" if offer.kind == "weapon" else "妖精",15,accent)
	var title_label := _label(Vector2(14,30),title,23,Color("eee7d2"))
	if plus:
		var font: Font = title_label.get_theme_font("font")
		_label(Vector2(16+font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,23).x,30),"+",23,Color("ffd35b"))
	# Stats and the comparison note sit at the bottom so long descriptions never overlap them.
	var y := size.y-(86 if note != "" else 62) if action_text != "" else size.y-(58 if note != "" else 34)
	if offer.kind == "weapon":
		var diagram := Diagram.new()
		var side := minf(140, size.x-40)
		diagram.position = Vector2((size.x-side)/2,66)
		diagram.size = Vector2(side,side)
		diagram.offsets = Weapons.offsets(int(offer.value))
		diagram.slides = Weapons.slides(int(offer.value))
		diagram.context = context
		diagram.accent = accent
		add_child(diagram)
		if plus:
			_badge(diagram.position+Vector2(side+32,0),26)
		_wrap_label(_label(Vector2(14,72+side),description,15,Color("e5dfc5")),size.x-28)
		var damage: int = model.weapon_damage(int(offer.value)) if model != null else 1
		var stats := "1 AP / 攻撃 %d" % damage
		if circle:
			# The enchantment replaces the attack: say so plainly.
			stats = "魔法陣・攻撃不可"
			var ring := Panel.new()
			ring.position = Vector2(4,4)
			ring.size = size-Vector2(8,8)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := StyleBoxFlat.new()
			style.draw_center = false
			style.border_color = Color("9b6bff")
			style.set_border_width_all(2)
			style.set_corner_radius_all(6)
			ring.add_theme_stylebox_override("panel",style)
			add_child(ring)
		if Weapons.knockback(int(offer.value)) > 0:
			stats += " / 押し出し"
		_label(Vector2(14,y),stats,15,Color("c9b3ff") if circle else Color("ffd35b") if damage > 1 else Color("92b3ae"))
	else:
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = model.item_definition(fairy_id).icon
		icon.position = Vector2((size.x-96)/2,64)
		icon.size = Vector2(96,96)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		if plus:
			_badge(icon.position+Vector2(96,-4),26)
		_wrap_label(_label(Vector2(12,166),description.replace("\n",""),14,Color("e5dfc5")),size.x-24)
		_label(Vector2(14,y),"%d AP / 毎戦闘 1回" % (0 if plus and fairy_id == "warp_fairy" else 1),15,accent)
	if note != "":
		_label(Vector2(14,y+22),note,16,note_color)
	if action_text != "":
		_label(Vector2(14,size.y-34),action_text + "  →",20,accent)

func _badge(corner: Vector2, side: float) -> void:
	var badge := PlusBadge.new()
	badge.position = corner - Vector2(side, 0)
	badge.size = Vector2.ONE * side
	add_child(badge)

## Wrap a label to a fixed width (its minimum width pins it once it is laid out).
func _wrap_label(label: Label, width: float) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.custom_minimum_size = Vector2(width, 0)
	label.size = Vector2(width, 0)

func _label(at: Vector2, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
