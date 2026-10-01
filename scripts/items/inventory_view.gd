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
var keys: Array[Label] = []
var pluses: Array[Label] = []
var badges: Array[Control] = []
var free_tags: Array[Label] = []
const PlusBadge = preload("res://scripts/items/plus_badge.gd")
const RarityFrame = preload("res://scripts/run/rarity_frame.gd")
const Rarity = preload("res://scripts/run/rarity.gd")
const LineBreak = preload("res://scripts/ui/line_break.gd")
## The slot frame, in the fairy's rarity material (the same as its reward card).
const FRAME := 7.0
## Room for the summary between the icon and the frame.
const SUMMARY_WIDTH := 186.0
var frames: Array[Control] = []
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
		button.add_theme_stylebox_override("hover",_style(Color("203432"),Color("2bdcc8"),FRAME+2))
		button.add_theme_stylebox_override("disabled",_style(Color("101719"),Color("293a36")))
		add_child(button)
		quick_buttons.append(button)
		var icon := Icon.new()
		icon.position = Vector2(10,11)
		icon.size = Vector2(66,66)
		button.add_child(icon)
		quick_icons.append(icon)
		var badge := PlusBadge.new()
		badge.position = Vector2(56,9)
		badge.size = Vector2(22,22)
		button.add_child(badge)
		badges.append(badge)
		names.append(_label(button,Vector2(82,8),"",22))
		var plus := _label(button,Vector2(82,8),"+",22)
		plus.add_theme_color_override("font_color",Color("ffd35b"))
		pluses.append(plus)
		var summary := _label(button,Vector2(82,40),"",16)
		# Two lines at most fit inside the frame.
		summary.add_theme_constant_override("line_spacing",-3)
		summary.custom_minimum_size = Vector2(SUMMARY_WIDTH,0)
		costs.append(summary)
		# A fairy that costs nothing says so, on a tag over the foot of its icon.
		var free := _label(button,Vector2(12,60),"0 AP",16)
		free.add_theme_color_override("font_color",Color("0c181b"))
		var tag := StyleBoxFlat.new()
		tag.bg_color = Color("7dff9a")
		tag.set_corner_radius_all(4)
		tag.content_margin_left = 5
		tag.content_margin_right = 5
		free.add_theme_stylebox_override("normal",tag)
		free.visible = false
		free_tags.append(free)
		var key := _label(button,Vector2(250,8),str(slot+1),15)
		key.modulate = Rarity.INFO
		keys.append(key)
		var frame := RarityFrame.new()
		frame.thickness = FRAME
		frame.size = button.size
		button.add_child(frame)
		frames.append(frame)
	refresh(true,"")

## A border wider than the frame shows only its inner 2px, as a line inside the frame.
func _style(fill: Color,border: Color,width: float = 2.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(int(width))
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
	if model.fairy_charges[slot] <= 0 or model.player.ap < model.fairy_ap_cost(id):
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
		free_tags[slot].visible = present and model.fairy_ap_cost(hand[slot]) == 0
		badges[slot].visible = present and model.is_plus(hand[slot])
		pluses[slot].visible = badges[slot].visible
		frames[slot].visible = present
		if not present:
			button.add_theme_stylebox_override("disabled",_style(Color("101719"),Color("293a36")))
			quick_icons[slot].texture = null
			quick_icons[slot].queue_redraw()
			names[slot].text = "空き枠"
			costs[slot].text = "報酬で獲得"
			continue
		var item: Resource = model.item_definition(hand[slot])
		var count: int = model.fairy_charges[slot]
		button.disabled = not enabled or model.player.ap < model.fairy_ap_cost(hand[slot]) or count == 0
		button.tooltip_text = model.fairy_description(hand[slot])
		var chosen: bool = selected==item.id and slot==selected_slot
		button.add_theme_stylebox_override("normal",_style(Color("203432") if chosen else Color("0c191a"),item.color if chosen else Color("0c191a"),FRAME+2))
		button.add_theme_stylebox_override("disabled",_style(Color("101719"),Color("101719"),FRAME+2))
		var frame: Control = frames[slot]
		var tier := Rarity.tier({"kind":"fairy","value":hand[slot]})
		if frame.tier != tier:
			frame.tier = tier
			frame.set_process(tier == Rarity.SUPER_RARE)
		frame.set_hover(chosen)
		quick_icons[slot].texture = item.icon
		quick_icons[slot].queue_redraw()
		names[slot].text = item.title
		names[slot].modulate = Color.WHITE if count > 0 else Color("768c87")
		# What it does, in one line; the AP cost and single use are the same for every fairy.
		costs[slot].text = model.fairy_summary(hand[slot]) if count > 0 else "使用済み・次戦で回復"
		# One line at 16px, or a little smaller (not under 14px); a longer one breaks onto
		# two lines after a separator or particle.
		var font: Font = costs[slot].get_theme_font("font")
		var font_size := 16
		while font_size > 14 and font.get_string_size(costs[slot].text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > SUMMARY_WIDTH:
			font_size -= 1
		costs[slot].add_theme_font_size_override("font_size",font_size)
		costs[slot].text = LineBreak.split(costs[slot].text,font,font_size,SUMMARY_WIDTH)
		pluses[slot].position.x = 84 + font.get_string_size(item.title,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x
		costs[slot].modulate = Rarity.INFO if count > 0 else Color("768c87")
