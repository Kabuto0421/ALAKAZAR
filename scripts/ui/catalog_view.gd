extends Control
## The catalog: every weapon and every fairy, drawn with the same cards as the rewards
## (rarity frame, range diagram or fairy demo). Opened from the title screen; Esc closes it.

signal closed

const Card = preload("res://scripts/run/choice_card.gd")
const Weapons = preload("res://scripts/run/weapon_catalog.gd")
const Rarity = preload("res://scripts/run/rarity.gd")
const Rules = preload("res://scripts/battle_model.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")

const VIEW := Vector2(1728, 1080)
const UI_SCALE := 1.5
## Cards are laid out in the game's 1152x720 space, scaled up like the reward screen.
const CARD_SIZE := Vector2(236, 350)
const GAP := 16.0
const COLUMNS := 4
const GOLD := Color("ffd35b")
const CREAM := Color("f1e9d8")

var tab := "weapon"
var model: RefCounted = Rules.new()
var holder: Control
var scroll: ScrollContainer
var grid: GridContainer
var tab_buttons := {}
var heading: Label

func _ready() -> void:
	size = VIEW
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.93)
	dim.size = VIEW
	add_child(dim)
	holder = Control.new()
	holder.scale = Vector2.ONE * UI_SCALE
	holder.size = VIEW / UI_SCALE
	add_child(holder)
	heading = _label(Vector2(40, 20), "", 34, GOLD)
	for entry in [["weapon", "武器", Vector2(560, 18)], ["fairy", "妖精", Vector2(680, 18)]]:
		var button := _button(entry[1], entry[2], Vector2(104, 44))
		button.pressed.connect(func() -> void: _show(entry[0]))
		tab_buttons[entry[0]] = button
	var back := _button("戻る [Esc]", Vector2(960, 18), Vector2(150, 44))
	back.pressed.connect(close)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(64, 76)
	scroll.size = Vector2(1024, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)
	_show("weapon")

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
			close()
		elif event.keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D, KEY_TAB]:
			_show("fairy" if tab == "weapon" else "weapon")
		get_viewport().set_input_as_handled()

## Every entry of a tab as an offer, rarest last (the order inside a rarity follows the game's lists).
func entries(kind: String) -> Array:
	var list: Array = []
	if kind == "weapon":
		for index in Weapons.DATA.size():
			# The クロス短剣 shows as one card (both halves); the second half has none of its own.
			if Weapons.is_pair_member(index):
				continue
			list.append({"kind": "weapon", "value": index})
	else:
		for item in Rules.ITEMS:
			list.append({"kind": "fairy", "value": item.id})
	var ordered: Array = []
	for t in 4:
		for offer in list:
			if Rarity.tier(offer) == t:
				ordered.append(offer)
	return ordered

func _show(kind: String) -> void:
	tab = kind
	var list := entries(kind)
	heading.text = "カタログ　%s %d" % ["武器" if kind == "weapon" else "妖精", list.size()]
	for key in tab_buttons:
		tab_buttons[key].modulate = Color.WHITE if key == kind else Color(1, 1, 1, 0.55)
	if grid != null:
		grid.queue_free()
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	scroll.add_child(grid)
	scroll.scroll_vertical = 0
	for offer in list:
		var slot := Control.new()
		slot.custom_minimum_size = CARD_SIZE
		grid.add_child(slot)
		var card := Card.new()
		card.size = CARD_SIZE
		card.offer = offer
		card.model = model
		card.show_pair = true
		card.action_text = ""
		slot.add_child(card)

func _label(at: Vector2, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	holder.add_child(label)
	return label

func _button(text: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("172b2b") if state != "normal" else Color("0c181b")
		style.border_color = GOLD if state != "normal" else CREAM
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", GOLD)
	holder.add_child(button)
	return button
