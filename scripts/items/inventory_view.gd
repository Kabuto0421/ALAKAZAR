extends Control

signal item_selected(id: String)
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
	hand_count = _label(self,Vector2(352,592),"",19)
	for slot in range(model.HAND_LIMIT):
		var button := _button(self,Rect2(352+slot*112,622,104,90),"",func(): activate_slot(slot))
		quick_buttons.append(button)
		quick_icons.append(_icon(button,Vector2(27,1),50))
		names.append(_label(button,Vector2(4,47),"",19))
		costs.append(_label(button,Vector2(31,69),"1 AP",16))
	refresh(true,"")

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	return style

func _button(parent: Node, rect: Rect2, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",22)
	button.add_theme_stylebox_override("normal",_style(Color("0c191a"),Color("355552")))
	button.add_theme_stylebox_override("hover",_style(Color("203432"),Color("2bdcc8")))
	button.add_theme_stylebox_override("pressed",_style(Color("28423b"),Color("ffbd59")))
	button.add_theme_stylebox_override("disabled",_style(Color("0c1315"),Color("23332f")))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _label(parent: Node, at: Vector2, title: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.text = title
	label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _icon(parent: Node, at: Vector2, side: int) -> Control:
	var icon := Icon.new()
	icon.position = at
	icon.size = Vector2(side,side)
	parent.add_child(icon)
	return icon

func toggle() -> void:
	# The hand is always visible; B focuses its first card.
	activate_slot(0)

func set_open(_value: bool) -> void:
	opened = false

func activate_slot(slot: int) -> void:
	if not enabled or slot < 0 or slot >= hand.size():
		return
	var id: String = hand[slot]
	if model.player.ap < model.item_definition(id).ap_cost:
		return
	if selected_slot == slot:
		selected_slot = -1
		open_changed.emit()
	else:
		selected_slot = slot
		item_selected.emit(id)

func refresh(can_use: bool, selected: String) -> void:
	enabled = can_use
	hand.clear()
	for item in model.ITEMS:
		for i in range(model.inventory.get(item.id,0)):
			if hand.size() < model.HAND_LIMIT:
				hand.append(item.id)
	if selected.is_empty():
		selected_slot = -1
	hand_count.text = "手札  %d / %d" % [hand.size(),model.HAND_LIMIT]
	for slot in range(model.HAND_LIMIT):
		var button := quick_buttons[slot]
		var present := slot < hand.size()
		button.visible = present
		if not present:
			continue
		var item: Resource = model.item_definition(hand[slot])
		var active: bool = slot == selected_slot and item.id == selected
		button.position = Vector2(352+slot*112,614 if active else 622)
		button.disabled = not enabled or model.player.ap < item.ap_cost
		button.tooltip_text = item.title + " · 1 AP\n" + item.description
		button.add_theme_stylebox_override("normal",_style(Color("203432") if active else Color("0c191a"),item.color if active else Color("55716b")))
		quick_icons[slot].kind = item.id
		quick_icons[slot].texture = item.icon
		quick_icons[slot].tint = item.color
		quick_icons[slot].queue_redraw()
		names[slot].text = item.title
		names[slot].modulate = Color.WHITE if not button.disabled else Color("768c87")
