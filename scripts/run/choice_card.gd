extends Button

const Weapons = preload("res://scripts/run/weapon_catalog.gd")
const Diagram = preload("res://scripts/run/range_diagram.gd")
const PlusBadge = preload("res://scripts/items/plus_badge.gd")
const Rarity = preload("res://scripts/run/rarity.gd")
const FairyDemo = preload("res://scripts/run/fairy_demo.gd")
const FairyMarks = preload("res://scripts/run/fairy_marks.gd")

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
		description = weapon.detail
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
	# The frame shows the rarity: white, green, blue or gold, and thick enough to read.
	var tier := Rarity.tier(offer)
	var frame: Color = Rarity.COLORS[tier]
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("172b2b") if state in ["hover","pressed"] else Color(frame.darkened(0.88), 1.0) if tier >= Rarity.RARE else Color("0c181b")
		style.border_color = frame if state in ["hover","pressed"] or tier > Rarity.COMMON else Color(frame, 0.75)
		style.set_border_width_all((5 if state in ["hover","pressed"] else 3) + (1 if tier == Rarity.SUPER_RARE else 0))
		if tier == Rarity.SUPER_RARE:
			style.shadow_color = Color(frame, 0.55)
			style.shadow_size = 10
		style.set_corner_radius_all(8)
		add_theme_stylebox_override(state,style)
	_label(Vector2(14,10),tag if tag != "" else "武器" if offer.kind == "weapon" else "妖精",15,accent)
	# The rarity sits on a badge in the top-right corner, in the frame colour.
	var badge := Label.new()
	badge.text = " %s " % Rarity.NAMES[tier]
	badge.add_theme_font_size_override("font_size",12)
	badge.add_theme_color_override("font_color",Color("0c181b"))
	var pill := StyleBoxFlat.new()
	pill.bg_color = frame
	pill.set_corner_radius_all(6)
	pill.content_margin_left = 6
	pill.content_margin_right = 6
	badge.add_theme_stylebox_override("normal",pill)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	badge.position = Vector2(size.x-badge.get_minimum_size().x-10,9)
	var title_label := _label(Vector2(14,30),title,23,Color("eee7d2"))
	if plus:
		var font: Font = title_label.get_theme_font("font")
		_label(Vector2(16+font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,23).x,30),"+",23,Color("ffd35b"))
	# Stats and the comparison note sit at the bottom so long descriptions never overlap them.
	var y := size.y-(86 if note != "" else 62) if action_text != "" else size.y-(58 if note != "" else 34)
	if offer.kind == "weapon":
		var diagram := Diagram.new()
		var shove := Weapons.knockback(int(offer.value)) > 0
		# A shoving weapon makes room under its reach for the collision example.
		var side := minf(96 if shove else 140, size.x-40)
		diagram.position = Vector2((size.x-side)/2,66)
		diagram.size = Vector2(side,side)
		diagram.offsets = Weapons.offsets(int(offer.value))
		diagram.slides = Weapons.slides(int(offer.value))
		diagram.context = context
		diagram.accent = accent
		add_child(diagram)
		if plus:
			_badge(diagram.position+Vector2(side+32,0),26)
		var detail_top := 72+side
		if shove:
			var demo := FairyDemo.new()
			demo.model = model
			demo.id = "knockback"
			demo.position = Vector2(10,70+side)
			demo.size = Vector2(size.x-20,50)
			add_child(demo)
			detail_top += 52
			description = SHOVE_TEXT
		var detail := _label(Vector2(14,detail_top),description,15,Color("e5dfc5"))
		_wrap_label(detail,size.x-28)
		_fit(detail,y-4-detail_top)
		var damage: int = model.weapon_damage(int(offer.value)) if model != null else 1
		var stats := "1 AP / 無傷で入替" if Weapons.DATA[int(offer.value)].get("swap", false) else "1 AP / 攻撃 %d" % damage
		if circle:
			# The enchantment replaces the attack: say so plainly.
			stats = "魔法陣・攻撃不可"
			var ring := Panel.new()
			ring.position = Vector2(4,4)
			ring.size = size-Vector2(8,8)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := StyleBoxFlat.new()
			style.draw_center = false
			style.border_color = Color("f4f2ea")
			style.set_border_width_all(2)
			style.set_corner_radius_all(6)
			ring.add_theme_stylebox_override("panel",style)
			add_child(ring)
		_label(Vector2(14,y),stats,15,GREEN if preview_plus else ENCHANT if circle else Color("ffd35b") if damage > 1 else Color("92b3ae"))
	else:
		# Under the name: what kind of fairy it is.
		var kind: String = KINDS.get(fairy_id, "使い切り")
		var kind_label := _label(Vector2(14,60),kind if kind != "設置" else "設置・5ターンで消える",13,Color("0c181b"))
		kind_label.add_theme_font_override("font",label_font())
		var pill_style := StyleBoxFlat.new()
		pill_style.bg_color = KIND_COLORS[kind]
		pill_style.set_corner_radius_all(4)
		pill_style.content_margin_left = 6
		pill_style.content_margin_right = 6
		kind_label.add_theme_stylebox_override("normal",pill_style)
		# Where it goes: on the same row, right-aligned, when there is room (the example
		# gets that height), else on a row of its own.
		var place := _label(Vector2(14,84),"置く場所：" + PLACES.get(fairy_id, "武器の範囲"),12,Color("c9d4cc"))
		place.add_theme_font_override("font",label_font())
		var demo_top := 104.0
		var place_width := place.get_minimum_size().x
		if kind == "設置" and kind_label.get_minimum_size().x + place_width + 8 > size.x-24:
			# Too long for one row with the placement: the short form keeps both on it.
			kind_label.text = "設置・5ターン"
		if kind_label.get_minimum_size().x + place_width + 8 <= size.x-24:
			place.position = Vector2(size.x-12-place_width,62)
			demo_top = 84.0
		# An animated example of what it does, as large as the card allows, then the
		# summon's HP / AP, the guardian's calls and one short line of text.
		var stats: Array = SUMMONS.get(fairy_id, [])
		var marks_height := (26.0 if not stats.is_empty() else 0.0) + (36.0 if fairy_id == "guardian_fairy" else 0.0)
		# Room for the text: its lines at this card's width, plus the chain line of cannons.
		var chars_per_line := maxf(1.0, floorf((size.x-24)/15.5))
		var text_room := ceilf(description.length()/chars_per_line)*21.0+6.0
		var chain := fairy_id in CHAIN_FAIRIES
		if chain:
			text_room += 24.0
		var demo := FairyDemo.new()
		demo.model = model
		demo.id = fairy_id
		demo.plus = 1 if plus else 0
		# Edge to edge inside the frame: the example's width sets how large it is drawn.
		demo.position = Vector2(6,demo_top)
		demo.size = Vector2(size.x-12,clampf(y-demo_top-marks_height-text_room-6,64.0,220.0))
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
		_fit(text,y-4-text_top-(24.0 if chain else 0.0))
		if chain:
			var chip := _label(Vector2(14,y-26),"誘爆",13,Color("0c181b"))
			chip.add_theme_font_override("font",label_font())
			var chip_style := StyleBoxFlat.new()
			chip_style.bg_color = Color("ff9a5b")
			chip_style.set_corner_radius_all(4)
			chip_style.content_margin_left = 6
			chip_style.content_margin_right = 6
			chip.add_theme_stylebox_override("normal",chip_style)
			var chained := _label(Vector2(22+chip.get_minimum_size().x,y-26),"他の大砲・魔弾でも発動",13,Color("ffc59a"))
			chained.add_theme_font_override("font",label_font())
		var item_def: Resource = model.item_definition(fairy_id)
		var ap: int = maxi(0, item_def.ap_cost - (1 if plus else 0))
		var uses: int = item_def.initial_count + (1 if plus else 0)
		_label(Vector2(14,y),"%d AP / 毎戦闘 %d回" % [ap, uses],15,GREEN if base_description != "" else accent)
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

const GREEN := Color("7dff9a")
## Text about a weapon's enchantment (the magic circle), in a colour nothing else uses.
const ENCHANT := Color("ff7ae6")
## Shoving weapons: what a collision does.
const SHOVE_TEXT := "押出：ぶつけた敵・ぶつかった敵に1ずつ"

static var _label_font: Font
## Small labels (the fairy's kind, the chain note) in a plain bold gothic from the
## system, which reads better than the pixel font at this size.
static func label_font() -> Font:
	if _label_font == null:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Hiragino Sans", "Hiragino Kaku Gothic ProN", "Yu Gothic UI", "Meiryo", "Noto Sans CJK JP", "Noto Sans JP", "IPAGothic"])
		font.font_weight = 700
		font.fallbacks = [preload("res://assets/fonts/DotGothic16-Regular.ttf")]
		_label_font = font
	return _label_font

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
	while font_size > 11 and label.get_line_count() * label.get_line_height() > height:
		font_size -= 1
		label.add_theme_font_size_override("font_size",font_size)

func _label(at: Vector2, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
