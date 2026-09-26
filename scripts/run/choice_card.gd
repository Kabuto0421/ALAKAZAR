extends Button

const Weapons = preload("res://scripts/run/weapon_catalog.gd")
const Diagram = preload("res://scripts/run/range_diagram.gd")
var offer: Dictionary
var model: RefCounted
var action_text := "選ぶ"

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var accent := Color("2bdcc8")
	var title := ""
	var description := ""
	if offer.kind == "weapon":
		var weapon: Dictionary = Weapons.DATA[int(offer.value)]
		accent = Color(weapon.color)
		title = weapon.name
		description = weapon.detail
	else:
		var item: Resource = model.item_definition(str(offer.value))
		accent = item.color
		title = item.title
		description = item.description
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("172b2b") if state in ["hover","pressed"] else Color("0c181b")
		style.border_color = accent if state != "disabled" else Color("40514f")
		style.set_border_width_all(3 if state in ["hover","pressed"] else 1)
		style.set_corner_radius_all(8)
		add_theme_stylebox_override(state,style)
	_label(Vector2(16,15),"武器" if offer.kind == "weapon" else "妖精",17,accent)
	_label(Vector2(16,44),title,25,Color("eee7d2"))
	if offer.kind == "weapon":
		var diagram := Diagram.new()
		diagram.position = Vector2((size.x-156)/2,92)
		diagram.size = Vector2(156,156)
		diagram.offsets = Weapons.offsets(int(offer.value))
		diagram.accent = accent
		add_child(diagram)
		_label(Vector2(16,263),description,19,Color("e5dfc5"))
		_label(Vector2(16,298),"移動・攻撃 1 AP",18,Color("92b3ae"))
	else:
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = model.item_definition(str(offer.value)).icon
		icon.position = Vector2((size.x-140)/2,88)
		icon.size = Vector2(140,140)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		var desc := _label(Vector2(14,239),description,17,Color("e5dfc5"))
		desc.size = Vector2(size.x-28,115)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label(Vector2(16,365),"1 AP  /  毎戦闘 1回",18,accent)
	_label(Vector2(16,size.y-43),action_text + "  →",23,accent)

func _label(at: Vector2, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
