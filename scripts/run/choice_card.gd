extends Button

const Weapons = preload("res://scripts/run/weapon_catalog.gd")
const Diagram = preload("res://scripts/run/range_diagram.gd")
const PlusBadge = preload("res://scripts/items/plus_badge.gd")
const Rarity = preload("res://scripts/run/rarity.gd")
const FairyDemo = preload("res://scripts/run/fairy_demo.gd")
const FairyMarks = preload("res://scripts/run/fairy_marks.gd")
const RarityFrame = preload("res://scripts/run/rarity_frame.gd")

## The label under a fairy's name: 召喚 (an ally with HP), 設置 (stays five turns)
## or 使い切り (works once, right away).
const KINDS := {
	"acorn_fairy": "召喚", "holy_spirit": "召喚", "lone_wolf": "召喚", "glutton_fairy": "召喚", "guardian_fairy": "召喚",
	"stealth_fairy": "設置", "wall_fairy": "設置", "cannon_fairy": "設置", "vane_cannon": "設置", "firework_fairy": "設置",
	"capacitor_fairy": "設置", "shadow_stitch": "設置", "blessing_fairy": "設置", "abyss_spirit": "設置",
}
const KIND_COLORS := {"召喚": Color("7dff9a"), "設置": Color("9fd8ff"), "使い切り": Color("ffd08a")}
## Summoned allies: [HP, AP, HP once classed up].
const SUMMONS := {
	"acorn_fairy": [1, 1, 2], "holy_spirit": [1, 1, 1], "lone_wolf": [2, 2, 2],
	"glutton_fairy": [1, 2, 3], "guardian_fairy": [3, 1, 4],
}
## The trickier fairies get a fuller line than their summary.
const CARD_TEXT := {
	"abyss_spirit": "武器の届かない空きマス（敵・障害物なし）が奈落に。動くと変わる",
	"lone_wolf": "届かないマスに召喚。単独で2、隣に仲間で1、届くとすねる",
	"shadow_stitch": "届かないマスに影を置き、0 APで入れ替わる",
	"glutton_fairy": "1×1なら敵も味方もあなたも喰う（99ダメージ）",
	"meteor_fairy": "自分の武器の範囲のマスの中からランダムに3×3の隕石を落とす（敵のみが3ダメージを受ける）",
	"guardian_fairy": "1試合の中で召喚した妖精を一斉に呼ぶ（HP+1）",
	"blessing_fairy": "3×3の中にいれば、攻撃が上下のマスにも当たる",
	"capacitor_fairy": "ターン終了時と攻撃されると1溜まり、3溜まると4方向に放電",
}
## Cannons: besides their own trigger, another cannon's shot or a magic bolt sets them off.
const CHAIN_FAIRIES := ["cannon_fairy", "vane_cannon", "firework_fairy", "capacitor_fairy"]
## Where each fairy is placed (shown under its name); 武器の範囲 unless listed.
const PLACES := {
	"shadow_stitch": "届かない所", "lone_wolf": "届かない所",
	"gravity_fairy": "どこでも", "warp_fairy": "どこでも",
	"abyss_spirit": "自分のマス", "meteor_fairy": "自分のマス",
}
## Examples drawn with the silver general's sword (they are about weapon reach).
const SILVER_EXAMPLES := ["shadow_stitch", "lone_wolf", "abyss_spirit", "gravity_fairy", "meteor_fairy"]
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
	var base_description := ""
	var circle := false
	var fairy_id := ""
	if offer.kind == "weapon":
		var weapon: Dictionary = Weapons.DATA[int(offer.value)]
		accent = Color(weapon.color)
		title = weapon.name
		# The diagram already shows where it reaches: the text only explains what it
		# cannot show (knockback, swaps, hammer echoes, the charge, pulls, the bow).
		description = weapon.get("effect", "")
		plus = preview_plus or (model != null and model.weapon_power.has(int(offer.value)))
		circle = offer.get("enchant", "") == "circle" or (model != null and model.is_circle(int(offer.value)))
	else:
		fairy_id = str(offer.value)
		var item: Resource = model.item_definition(fairy_id)
		accent = item.color
		title = item.title
		plus = model.is_plus(fairy_id) or (preview_plus and model.PLUS_TEXT.has(fairy_id))
		# One short line: what it does, or on a class-up card what the class-up adds.
		description = CARD_TEXT.get(fairy_id, item.summary)
		if plus:
			description = model.PLUS_TEXT[fairy_id][0]
		if fairy_id == "meteor_fairy" and plus:
			# Each class-up adds a meteor: preview the next count.
			description = "隕石が%d個落ちる" % (model.meteor_count() + (1 if preview_plus else 0))
		if preview_plus and plus:
			base_description = item.summary
	# The frame shows the rarity in its material (wood, jade, lapis lazuli, gold),
	# drawn over the card at the end; the card itself is just the dark ground.
	var tier := Rarity.tier(offer)
	var frame: Color = Rarity.COLORS[tier]
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("172b2b") if state in ["hover","pressed"] else Color(frame.darkened(0.88), 1.0) if tier >= Rarity.RARE else Color("0c181b")
		if tier == Rarity.SUPER_RARE:
			style.shadow_color = Color(frame, 0.55)
			style.shadow_size = 10
		add_theme_stylebox_override(state,style)
	# The corner only carries a special heading (クラスアップ後, 魔法陣の武器); the diagram
	# and the kind label already say whether it is a weapon or a fairy.
	var tag_label := _label(Vector2(14,12),tag,15,accent)
	tag_label.visible = tag != ""
	# The rarity sits on a badge in the top-right corner, in the frame colour.
	var badge := Label.new()
	badge.text = Rarity.NAMES[tier]
	badge.add_theme_font_size_override("font_size",LABEL_SIZE)
	badge.add_theme_color_override("font_color",Color("0c181b"))
	var pill := StyleBoxFlat.new()
	pill.bg_color = frame
	pill.set_corner_radius_all(6)
	pill.content_margin_left = 6
	pill.content_margin_right = 6
	badge.add_theme_stylebox_override("normal",pill)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	badge.position = Vector2(size.x-badge.get_minimum_size().x-12,11)
	# A long corner tag (クラスアップ後, 魔法陣の武器) must stop short of the badge; on a
	# card too narrow for it at a readable size it is left out (the stats line and
	# the frame still say it).
	_fit_width(tag_label,badge.position.x-6-tag_label.position.x)
	if tag_label.get_theme_font_size("font_size") < 13 or tag_label.get_minimum_size().x > badge.position.x-6-tag_label.position.x:
		tag_label.visible = false
	var title_label := _label(Vector2(14,34),title,23,Color("eee7d2"))
	_fit_width(title_label,size.x-40)
	if plus:
		var font: Font = title_label.get_theme_font("font")
		var title_size := title_label.get_theme_font_size("font_size")
		_label(Vector2(16+font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x,34),"+",title_size,Color("ffd35b"))
	# Stats and the comparison note sit at the bottom so long descriptions never overlap them.
	var y := size.y-(90 if note != "" else 66) if action_text != "" else size.y-(62 if note != "" else 38)
	if offer.kind == "weapon":
		var diagram := Diagram.new()
		# The effect text keeps its full size: the diagram shrinks to leave it room.
		var detail := _label(Vector2(14,0),description,15,Color("e5dfc5"))
		_wrap_label(detail,size.x-28)
		var text_height := _text_height(detail, 15)
		var side := clampf(y-4-74-text_height-2,56.0,minf(140,size.x-40))
		diagram.position = Vector2((size.x-side)/2,68)
		diagram.size = Vector2(side,side)
		diagram.offsets = Weapons.offsets(int(offer.value))
		diagram.slides = Weapons.slides(int(offer.value))
		diagram.echo = Weapons.hammer_echo(int(offer.value))
		diagram.hammer = Weapons.is_hammer(int(offer.value))
		diagram.context = context
		diagram.accent = accent
		add_child(diagram)
		if plus:
			_badge(Vector2(minf(diagram.position.x+side+32,size.x-12),diagram.position.y),26)
		var detail_top := 74+side
		detail.position.y = detail_top
		# The knockback example goes between the diagram and the text when the whole
		# text still fits under it at full size.
		if Weapons.knockback(int(offer.value)) > 0 and text_height+54 <= y-4-detail_top:
			var demo := FairyDemo.new()
			demo.model = model
			demo.id = "knockback"
			demo.position = Vector2(12,72+side)
			demo.size = Vector2(size.x-24,50)
			add_child(demo)
			detail_top += 52
			detail.position.y = detail_top
		_fit(detail,y-4-detail_top)
		var damage: int = model.weapon_damage(int(offer.value)) if model != null else 1
		var stats := "1 AP / 入れ替え" if Weapons.DATA[int(offer.value)].get("swap", false) else "1 AP / ノックバック" if Weapons.knockback(int(offer.value)) > 0 and damage <= 0 else "1 AP / 攻撃 %d" % damage
		if circle:
			# The enchantment replaces the attack: say so plainly (in the enchantment colour).
			stats = "魔法陣・攻撃不可"
		_label(Vector2(14,y),stats,15,GREEN if preview_plus else ENCHANT if circle else Color("ffd35b") if damage > 1 else Color("92b3ae"))
	else:
		# What kind of fairy it is: a label just left of the rarity badge (or, when the
		# corner tag leaves no room there, at the start of the row under the name).
		var kind: String = KINDS.get(fairy_id, "使い切り")
		var kind_label := _pill(Vector2(14,11),kind if kind != "設置" else "設置・5ターン",KIND_COLORS[kind])
		var row := 68.0
		var place_x := 14.0
		var kind_x := badge.position.x-kind_label.get_minimum_size().x-6
		if kind_x >= 14 and (not tag_label.visible or kind_x >= tag_label.position.x+tag_label.get_minimum_size().x+6):
			kind_label.position.x = kind_x
		else:
			kind_label.position = Vector2(14,row)
			place_x = 14+kind_label.get_minimum_size().x+8
		# Under the name: where it goes (on the next row if it does not fit beside the kind).
		var place := _label(Vector2(place_x,row),"置く場所：" + PLACES.get(fairy_id, "武器の範囲"),LABEL_SIZE,Color("d6e0d8"))
		if place_x > 14 and place_x+place.get_minimum_size().x > size.x-12:
			row += 26
			place.position = Vector2(14,row)
		_fit_width(place,size.x-12-place.position.x)
		var demo_top := row+26
		# An animated example of what it does, as large as the card allows, then the
		# summon's HP / AP, the guardian's calls and one short line of text.
		var stats: Array = SUMMONS.get(fairy_id, [])
		var marks_height := (26.0 if not stats.is_empty() else 0.0) + (36.0 if fairy_id == "guardian_fairy" else 0.0)
		# Room for the text: its lines at this card's width, plus the chain line of cannons.
		var chars_per_line := maxf(1.0, floorf((size.x-24)/15.5))
		var text_room := ceilf(description.length()/chars_per_line)*21.0+6.0
		var chain := fairy_id in CHAIN_FAIRIES
		if chain:
			text_room += 28.0
		var demo := FairyDemo.new()
		demo.model = model
		demo.id = fairy_id
		demo.plus = 1 if plus else 0
		# Edge to edge inside the frame: the example's width sets how large it is drawn.
		demo.position = Vector2(12,demo_top)
		demo.size = Vector2(size.x-24,clampf(y-demo_top-marks_height-text_room-6,44.0,220.0))
		add_child(demo)
		if plus:
			_badge(demo.position+Vector2(demo.size.x,-4),24)
		if fairy_id in SILVER_EXAMPLES:
			# These examples assume the silver general's sword, whose reach is outlined white.
			demo.legend = "例：銀将剣"
			demo.legend_color = Color("d8e2ee")
		var marks_top := demo.position.y+demo.size.y+6
		if marks_height > 0:
			var marks := FairyMarks.new()
			marks.position = Vector2(14,marks_top)
			marks.size = Vector2(size.x-28,marks_height)
			if not stats.is_empty():
				marks.hp = int(stats[2]) if plus else int(stats[0])
				marks.ap = int(stats[1])
			marks.calls = fairy_id == "guardian_fairy"
			add_child(marks)
		var text_top := marks_top+marks_height+(2 if marks_height > 0 else 0)
		var text := _label(Vector2(12,text_top),description,15,GREEN if base_description != "" else Color("e5dfc5"))
		_wrap_label(text,size.x-24)
		_fit(text,y-4-text_top-(28.0 if chain else 0.0))
		if chain:
			var chip := _pill(Vector2(14,y-28),"誘爆",Color("ff9a5b"))
			var chained := _label(Vector2(22+chip.get_minimum_size().x,y-28),"他の大砲・魔弾でも発動",LABEL_SIZE,Color("ffc59a"))
			if chained.get_minimum_size().x > size.x-12-chained.position.x:
				chained.text = "大砲・魔弾でも発動"
			_fit_width(chained,size.x-12-chained.position.x)
		var item_def: Resource = model.item_definition(fairy_id)
		var ap: int = maxi(0, item_def.ap_cost - (1 if plus else 0))
		var uses: int = item_def.initial_count + (1 if plus else 0)
		_label(Vector2(14,y),"%d AP / 毎戦闘 %d回" % [ap, uses],15,GREEN if base_description != "" else accent)
	if note != "":
		var note_label := _label(Vector2(14,y+22),note,16,note_color)
		_fit_width(note_label,size.x-24)
	if action_text != "":
		_label(Vector2(14,size.y-38),action_text + "  →",20,accent)
	# The material frame goes on top of everything, and brightens under the pointer.
	var material_frame := RarityFrame.new()
	material_frame.tier = tier
	material_frame.size = size
	add_child(material_frame)
	mouse_entered.connect(material_frame.set_hover.bind(true))
	mouse_exited.connect(material_frame.set_hover.bind(false))

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

const GREEN := Color("7dff9a")
## Text about a weapon's enchantment (the magic circle), in a colour nothing else uses.
const ENCHANT := Color("ff7ae6")
## Shoving weapons: what a collision does.

## Small labels (the kind, where it goes, the chain note, the rarity) use the game's
## pixel font at the size it is drawn for, where it is crisp.
const LABEL_SIZE := 16

## A small label on a coloured tag with dark text.
func _pill(at: Vector2, text: String, fill: Color) -> Label:
	var label := _label(at,text,LABEL_SIZE,Color("0c181b"))
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	label.add_theme_stylebox_override("normal",style)
	return label

## Shrink a one-line label until it fits `width` (a last resort for narrow cards).
func _fit_width(label: Label, width: float) -> void:
	var font_size := label.get_theme_font_size("font_size")
	while font_size > 11 and label.get_minimum_size().x > width:
		font_size -= 1
		label.add_theme_font_size_override("font_size",font_size)

## Swap a plain label for rich text with the characters that differ from `base`
## (a longest-common-subsequence diff) in green. Same place, size and wrapping.
func _highlight(label: Label, base: String) -> void:
	var text := label.text
	var n := text.length()
	var m := base.length()
	var table: Array = []
	for i in n + 1:
		var row := PackedInt32Array()
		row.resize(m + 1)
		table.append(row)
	for i in range(n - 1, -1, -1):
		for j in range(m - 1, -1, -1):
			table[i][j] = table[i + 1][j + 1] + 1 if text[i] == base[j] else maxi(table[i + 1][j], table[i][j + 1])
	var kept := []
	kept.resize(n)
	kept.fill(false)
	var i := 0
	var j := 0
	while i < n and j < m:
		if text[i] == base[j]:
			kept[i] = true
			i += 1
			j += 1
		elif table[i + 1][j] >= table[i][j + 1]:
			i += 1
		else:
			j += 1
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.scroll_active = false
	rich.autowrap_mode = label.autowrap_mode
	rich.position = label.position
	rich.size = Vector2(label.size.x, size.y)
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.add_theme_font_size_override("normal_font_size", label.get_theme_font_size("font_size"))
	rich.add_theme_color_override("default_color", label.get_theme_color("font_color"))
	var out := ""
	var green := false
	for k in n:
		if not kept[k] and not green:
			out += "[color=#%s]" % GREEN.to_html(false)
			green = true
		elif kept[k] and green:
			out += "[/color]"
			green = false
		out += text[k].replace("[", "[lb]")
	if green:
		out += "[/color]"
	rich.text = out
	add_child(rich)
	label.visible = false

## Narrow cards (five in a row): shrink a long description until it ends above the stats line.
func _fit(label: Label, height: float) -> void:
	# Japanese line breaking: "。" and "、" never start a line.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font_size := label.get_theme_font_size("font_size")
	while font_size > 11 and _text_height(label, font_size) > height:
		font_size -= 1
		label.add_theme_font_size_override("font_size",font_size)

## The height a wrapped label's text takes at `font_size`, measured from the font
## (a label's own line count lags a frame behind a size change).
func _text_height(label: Label, font_size: int) -> float:
	if label.text == "":
		return 0.0
	# Wrapped the way the label wraps (AUTOWRAP_WORD_SMART).
	var paragraph := TextParagraph.new()
	paragraph.add_string(label.text, label.get_theme_font("font"), font_size)
	paragraph.width = label.size.x
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var line_height := label.get_theme_font("font").get_height(font_size) + label.get_theme_constant("line_spacing")
	return paragraph.get_line_count() * line_height

func _label(at: Vector2, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
