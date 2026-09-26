extends Control

signal item_selected(id: String, slot: int)
signal open_changed
const Icon = preload("res://scripts/items/spirit_icon.gd")
var model: RefCounted
var opened := false
var enabled := true
var selected_slot := -1
var hand: Array[String] = []
var quick_buttons: Array[Button] = []
var quick_icons: Array[Control] = []
var names: Array[Label] = []
var costs: Array[Label] = []
var hand_count: Label

func setup(rules: RefCounted) -> void:
	model = rules
	size = Vector2(1152,720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_count = _label(self,Vector2(24,230),"妖精",23)
	for slot in range(3):
		var button := Button.new()
		button.position = Vector2(24,268+slot*96)
		button.size = Vector2(280,88)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): activate_slot(slot))
		button.add_theme_stylebox_override("normal",_style(Color("0c191a"),Color("355552")))
		button.add_theme_stylebox_override("hover",_style(Color("203432"),Color("2bdcc8")))
		button.add_theme_stylebox_override("disabled",_style(Color("101719"),Color("293a36")))
		add_child(button)
		quick_buttons.append(button)
		var icon := Icon.new()
		icon.position = Vector2(5,8)
		icon.size = Vector2(72,72)
		button.add_child(icon)
		quick_icons.append(icon)
		names.append(_label(button,Vector2(82,12),"",24))
		costs.append(_label(button,Vector2(82,50),"",18))
	refresh(true,"")

func _style(fill: Color,border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	return style

func _label(parent: Node, at: Vector2, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func toggle() -> void:
	activate_slot(0)

func set_open(_value: bool) -> void:
	opened = false

func activate_slot(slot: int) -> void:
	if not enabled or slot < 0 or slot >= hand.size():
		return
	var id := hand[slot]
	if model.fairy_charges[slot] <= 0 or model.player.ap < 1:
		return
	if selected_slot == slot:
		selected_slot = -1
		open_changed.emit()
	else:
		selected_slot = slot
		item_selected.emit(id,slot)

func refresh(can_use: bool, selected: String) -> void:
	enabled = can_use
	hand.assign(model.fairy_loadout)
	if selected.is_empty():
		selected_slot = -1
	hand_count.text = "妖精  %d / 3" % hand.size()
	for slot in 3:
		var button := quick_buttons[slot]
		var present := slot < hand.size()
		button.disabled = not present or not enabled
		if not present:
			quick_icons[slot].texture = null
			quick_icons[slot].queue_redraw()
			names[slot].text = "空き枠"
			costs[slot].text = "報酬で獲得"
			continue
		var item: Resource = model.item_definition(hand[slot])
		var count: int = model.fairy_charges[slot]
		button.disabled = not enabled or model.player.ap < 1 or count == 0
		button.tooltip_text = item.description
		button.add_theme_stylebox_override("normal",_style(Color("203432") if selected==item.id and slot==selected_slot else Color("0c191a"),item.color if selected==item.id and slot==selected_slot else Color("55716b")))
		quick_icons[slot].texture = item.icon
		quick_icons[slot].queue_redraw()
		names[slot].text = item.title
		names[slot].modulate = Color.WHITE if count > 0 else Color("768c87")
		costs[slot].text = "1 AP  /  残り %d回" % count if count > 0 else "使用済み・次戦で回復"
