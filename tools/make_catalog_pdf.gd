extends SceneTree
## Draws the catalog pages (the same reward cards as the game, the rarity tables, the timeline of
## what can drop when) and saves them as page_XX.png into the folder named by CATALOG_OUT.
## tools/make_catalog_pdf.py runs this and binds the pages into a PDF:
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/make_catalog_pdf.gd

const Card = preload("res://scripts/run/choice_card.gd")
const Rules = preload("res://scripts/battle_model.gd")
const Run = preload("res://scripts/run/run_model.gd")
const W = preload("res://scripts/run/weapon_catalog.gd")
const Rarity = preload("res://scripts/run/rarity.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")

const PAGE := Vector2(1152, 806)
const SCALE := 2.0
const INK := Color("f1e9d8")
const MUTED := Color("8b9a98")
const CARD_SIZE := Vector2(236, 300)

var holder: Control
var viewport: SubViewport
var model: RefCounted = Rules.new()
var out_dir := ""
var page_number := 0

func _initialize() -> void:
	out_dir = OS.get_environment("CATALOG_OUT")
	if out_dir == "":
		out_dir = "res://catalog_pages"
	DirAccess.make_dir_recursive_absolute(out_dir)
	# The pages are drawn in an off-screen viewport of the full page size (the window is smaller).
	viewport = SubViewport.new()
	viewport.size = Vector2i(int(PAGE.x * SCALE), int(PAGE.y * SCALE))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	holder = Control.new()
	holder.scale = Vector2.ONE * SCALE
	viewport.add_child(holder)
	await _build()
	print("pages: ", page_number)
	quit()

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _save() -> void:
	await _frames(8)
	page_number += 1
	viewport.get_texture().get_image().save_png("%s/page_%02d.png" % [out_dir, page_number])

func _page(title: String, sub: String = "") -> void:
	for child in holder.get_children():
		child.queue_free()
	var back := ColorRect.new()
	back.color = Color("070b0d")
	back.size = PAGE
	holder.add_child(back)
	_label(Vector2(18, 10), title, 22, INK)
	if sub != "":
		_label(Vector2(18, 40), sub, 10, MUTED)

func _label(at: Vector2, text: String, font_size: int, color: Color, width: float = 0.0) -> Label:
	var label := Label.new()
	label.text = _wrap(text, font_size, width) if width > 0.0 else text
	label.position = at
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	holder.add_child(label)
	return label

## Breaks `text` into lines no wider than `width` (the font's own measurements).
func _wrap(text: String, font_size: int, width: float) -> String:
	var lines: Array[String] = []
	var line := ""
	for character in text:
		if character == "\n":
			lines.append(line)
			line = ""
			continue
		if FONT.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and line != "":
			lines.append(line)
			line = character
		else:
			line += character
	lines.append(line)
	return "\n".join(lines)

func _lines(label: Label) -> int:
	return label.text.count("\n") + 1

func _pill(at: Vector2, tier: int, wide: float = 66.0) -> void:
	var box := ColorRect.new()
	box.color = Rarity.COLORS[tier]
	box.position = at
	box.size = Vector2(wide, 15)
	holder.add_child(box)
	var text := _label(at + Vector2(0, -1), Rarity.NAMES[tier], 11, Color("101a1c"))
	text.size = Vector2(wide, 15)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _card(offer: Dictionary, at: Vector2, factor: float, plus: bool = false) -> void:
	var card := Card.new()
	card.size = CARD_SIZE
	card.position = at
	card.scale = Vector2.ONE * factor
	card.offer = offer
	card.model = model
	card.preview_plus = plus
	card.action_text = ""
	card.show_pair = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(card)

func _placeholder(at: Vector2, factor: float, text: String) -> void:
	var box := ColorRect.new()
	box.color = Color("0c1417")
	box.position = at
	box.size = CARD_SIZE * factor
	holder.add_child(box)
	var line := _label(at, text, 12, Color("55645f"))
	line.size = CARD_SIZE * factor
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _percent(value: float) -> String:
	var shown: float = snappedf(value * 100.0, 0.1)
	if absf(shown - roundf(shown)) < 0.05:
		return "%d%%" % int(roundf(shown))
	return "%.1f%%" % shown

# --- the rarity lookups ---------------------------------------------------------

func _weapon_tier(index: int) -> int:
	return Rarity.tier({"kind": "weapon", "value": index})

func _fairy_tier(id: String) -> int:
	return Rarity.tier({"kind": "fairy", "value": id})

func _forge_note(index: int) -> String:
	if not Rarity.can_forge(index):
		return "強化なし"
	match W.forge_kind(index):
		"tile":
			return "強化：動けるマスが1つ増える（抽選・何回でも）"
		"area":
			return "強化：叩く範囲が広がる"
		"charge":
			return "強化：最大4ダメージまで溜められる"
		"bow":
			return "強化：射程が斜めの端までのびる"
		"swap":
			return "強化：最初の入れ替えが0 AP"
	return "強化なし"

func _forge_short(index: int) -> String:
	if not Rarity.can_forge(index):
		return "強化なし"
	match W.forge_kind(index):
		"tile":
			return "強化できる（マス追加・何回でも）"
		"area":
			return "強化できる（範囲が広がる）"
		"charge":
			return "強化できる（最大4）"
		"bow":
			return "強化できる（射程がのびる）"
		"swap":
			return "強化できる（入替が0 AP）"
	return "強化なし"

func _name_of(index: int) -> String:
	return str(W.DATA[index].name)

## The chance that one reward card is each item: the rarity is drawn first, then one of that rarity
## (the nearest rarity with any left when it has none), as in Run._draw_by_rarity.
func _distribution(pool: Array, tier_of: Callable, odds: Array) -> Dictionary:
	var result := {}
	for tier in 4:
		var chosen: Array = []
		for step in range(0, 4):
			for t in [tier - step, tier + step]:
				var members: Array = pool.filter(func(item: Variant) -> bool: return int(tier_of.call(item)) == t)
				if chosen.is_empty() and not members.is_empty():
					chosen = members
		for item in chosen:
			result[item] = float(result.get(item, 0.0)) + float(odds[tier]) / float(chosen.size())
	return result

func _weapon_pool() -> Array:
	return range(W.DATA.size()).filter(func(index: int) -> bool: return index > 1 and not W.horizontal_only(index) and not W.is_pair_member(index))

func _fairy_pool() -> Array:
	return Run.new().reward_fairy_pool.duplicate()

func _names(distribution: Dictionary, as_weapon: bool) -> String:
	var keys: Array = distribution.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		if distribution[a] != distribution[b]:
			return distribution[a] > distribution[b]
		return str(a) < str(b))
	var parts: Array[String] = []
	for key in keys:
		if float(distribution[key]) < 0.0005:
			continue
		var title: String = _name_of(int(key)) if as_weapon else str(model.item_definition(str(key)).title)
		parts.append("%s %s" % [title, _percent(float(distribution[key]))])
	return "　".join(parts)

# --- the pages --------------------------------------------------------------------

func _build() -> void:
	await _page_odds()
	await _page_timeline()
	await _pages_effect_weapons()
	await _pages_simple_weapons()
	await _pages_fairies()
	await _page_weapon_list()
	await _page_fairy_list()

func _odds_rows() -> Array:
	return [
		["戦闘1・2の後", 0, "コモン中心（アンコモンは5%）／魔法陣（シンプルな武器だけ）が稀にレア"],
		["戦闘3の後（ボス前の特別報酬）", 2, "アンコモン中心（3マス武器・中盤武器など）"],
		["1体目のボスの後", 3, "ボス撃破ボーナス：妖精のレア+5%・激レア+2%"],
		["中盤1の後", 4, ""],
		["中盤2の後", 5, ""],
		["中盤3の後（ロトリック前の特別報酬）", 6, ""],
		["ロトリックの後", 7, "ボス撃破ボーナス：妖精のレア+5%・激レア+2%"],
		["終盤1〜3の後", 8, "コモン・アンコモンが増え、レア・激レアが減る"],
	]

func _page_odds() -> void:
	_page("レアリティが出る確率（報酬カード1枚あたり）", "報酬は毎回 武器3枚＋妖精2枚。各カードを抽選した結果なので、実際の出方はこの確率で変わる（run_model.gd の WEAPON_TIER_ODDS / FAIRY_TIER_ODDS）。")
	var columns := [340.0, 420.0, 500.0, 580.0, 690.0, 770.0, 850.0, 930.0, 1040.0]
	_label(Vector2(420, 58), "武器カード", 13, INK)
	_label(Vector2(770, 58), "妖精カード", 13, INK)
	_label(Vector2(1030, 54), "1回の報酬で", 9, MUTED)
	_label(Vector2(1030, 66), "レア以上が出る", 9, MUTED)
	for k in 8:
		_pill(Vector2(columns[k] - 2, 84), k % 4, 72.0)
	var run := Run.new()
	run.start(1)
	var y := 120.0
	for row in _odds_rows():
		var stage: int = row[1]
		var weapon_odds: Array = Run.WEAPON_TIER_ODDS[stage]
		run.stage = stage
		var fairy_odds: Array = run.fairy_tier_odds()
		_label(Vector2(18, y), str(row[0]), 14, INK, 310.0)
		if str(row[2]) != "":
			_label(Vector2(18, y + 36), str(row[2]), 9, MUTED, 310.0)
		for k in 8:
			var value: float = float(weapon_odds[k]) if k < 4 else float(fairy_odds[k - 4])
			_label(Vector2(columns[k], y + 2), _percent(value), 18, Rarity.COLORS[k % 4])
		var weapon_rare: float = float(weapon_odds[2]) + float(weapon_odds[3])
		var fairy_rare: float = float(fairy_odds[2]) + float(fairy_odds[3])
		var any_rare: float = 1.0 - pow(1.0 - weapon_rare, 3.0) * pow(1.0 - fairy_rare, 2.0)
		_label(Vector2(roundf(columns[8]), y + 2), _percent(any_rare), 18, INK)
		y += 66.0
	_label(Vector2(18, y + 10), "武器も妖精も、まず各カードごとにレアリティを上の確率で決め、そのレアリティの中から等確率で1つ選ぶ（出る時期はレアリティで決まる）。", 10, MUTED)
	_label(Vector2(18, y + 28), "レア：魔法陣付きの武器（報酬ごとに3%）・交差剣・扇剣・丁字剣・突進剣・天秤剣・雷短剣・炎短剣・ハンマー・ワープ妖精・風斧精霊 ほか。激レア：飛車槍・角剣（必ず魔法陣付き）・八方桂剣・十字槌 ほか。", 10, MUTED, 1110.0)
	await _save()

func _timeline_groups() -> Array:
	return [
		["戦闘1・2の後", 0],
		["戦闘3の後（ボス前の特別報酬）", 2],
		["1体目のボスの後", 3],
		["中盤1の後", 4],
		["中盤2の後", 5],
		["中盤3の後（ロトリック前の特別報酬）", 6],
		["ロトリックの後", 7],
		["終盤1〜3の後", 8],
	]

func _page_timeline() -> void:
	var run := Run.new()
	run.start(1)
	var weapon_pool := _weapon_pool()
	var fairy_pool := _fairy_pool()
	var groups := _timeline_groups()
	for half in 2:
		_page("いつ・何が出るか（時系列%s）" % ("" if half == 0 else "・続き"), "色＝レアリティ。名前の後ろの数字は、その報酬で候補に出る確率（1枚あたり・初期ビルドから）。")
		var y := 58.0
		if half == 0:
			_label(Vector2(18, y), "流れ：開始（武器1本・妖精1体）→ 戦闘1 → 戦闘2 → 戦闘3 → 報酬 → キャンプ → ボス → 報酬 → 中盤1 → 2 → 3 → 報酬 → キャンプ → ロトリックか嵐鮫 → 報酬 → 終盤1 → 2 → キャンプ → 終盤3 → キャンプ → 監獄の王", 10, MUTED, 1110.0)
			y += 36.0
			_label(Vector2(18, y), "開始（初期ビルド）", 13, INK)
			_label(Vector2(18, y + 18), "武器：" + "　".join(W.opening_pool().map(func(i: int) -> String: return _name_of(i))), 9, Color("c9d6e0"), 1110.0)
			_label(Vector2(18, y + 34), "妖精：魔弾精霊　隠密妖精　どんぐり妖精（3つから1体）", 9, Color("7dff9a"), 1110.0)
			y += 60.0
		var from_group := 0 if half == 0 else 4
		var to_group := 4 if half == 0 else groups.size()
		for g in range(from_group, to_group):
			var stage: int = groups[g][1]
			run.stage = stage
			var weapon_distribution := _distribution(weapon_pool, func(i: Variant) -> int: return _weapon_tier(int(i)), Run.WEAPON_TIER_ODDS[stage])
			var fairy_distribution := _distribution(fairy_pool, func(id: Variant) -> int: return _fairy_tier(str(id)), run.fairy_tier_odds())
			_label(Vector2(18, y), str(groups[g][0]), 13, INK)
			var weapon_line := _label(Vector2(18, y + 18), "武器　" + _names(weapon_distribution, true), 8, Color("c9d6e0"), 1116.0)
			var fairy_at := y + 18 + 12.0 * _lines(weapon_line)
			var fairy_line := _label(Vector2(18, fairy_at), "妖精　" + _names(fairy_distribution, false), 8, Color("7dff9a"), 1116.0)
			y = fairy_at + 12.0 * _lines(fairy_line) + 12.0
		await _save()

func _effect_weapons() -> Array:
	return range(W.DATA.size()).filter(func(index: int) -> bool: return not W.is_pair_member(index) and (W.DATA[index].has("effect") or W.is_hammer(index)))

func _simple_weapons() -> Array:
	return range(W.DATA.size()).filter(func(index: int) -> bool: return not W.is_pair_member(index) and not (W.DATA[index].has("effect") or W.is_hammer(index)))

func _pairs_page(title: String, sub: String, items: Array, make_pair: Callable) -> void:
	_page(title, sub)
	var per_row := 3
	var cell := Vector2(384, 250)
	for k in items.size():
		var at := Vector2(18 + (k % per_row) * cell.x, 58 + (k / per_row) * cell.y)
		make_pair.call(items[k], at)

func _pages_effect_weapons() -> void:
	var list := _effect_weapons()
	var per_page := 9
	var pages_needed := ceili(float(list.size()) / per_page)
	for p in pages_needed:
		var chunk: Array = list.slice(p * per_page, (p + 1) * per_page)
		_page("効果のある武器：通常と強化後（%d / %d）" % [p + 1, pages_needed], "強化はキャンプで鍛える。マスが増える武器は、増えるマスを抽選で決める（カードには緑で示す）。")
		for k in chunk.size():
			var index: int = chunk[k]
			var at := Vector2(18 + (k % 3) * 384, 58 + (k / 3) * 250)
			_label(at, _name_of(index), 13, INK)
			_pill(at + Vector2(100, 3), _weapon_tier(index), 54.0)
			var factor := 0.64
			_card({"kind": "weapon", "value": index}, at + Vector2(0, 20), factor)
			if Rarity.can_forge(index):
				_card({"kind": "weapon", "value": index}, at + Vector2(160, 20), factor, true)
			else:
				_placeholder(at + Vector2(160, 20), factor, "強化なし")
			_label(at + Vector2(0, 20 + CARD_SIZE.y * factor + 2), "通常", 9, Color("4fb4ff"))
			_label(at + Vector2(160, 20 + CARD_SIZE.y * factor + 2), "強化後（キャンプで鍛える）", 9, Color("4fb4ff"))
		await _save()

func _pages_simple_weapons() -> void:
	var list := _simple_weapons()
	var per_page := 24
	var pages_needed := ceili(float(list.size()) / per_page)
	for p in pages_needed:
		var chunk: Array = list.slice(p * per_page, (p + 1) * per_page)
		_page("シンプルな武器（%d / %d）" % [p + 1, pages_needed], "動けるマスだけの武器。強化はマスが1つ増える（キャンプで抽選・何回でも）。激レアは強化なし。")
		for k in chunk.size():
			var index: int = chunk[k]
			var at := Vector2(18 + (k % 6) * 186, 58 + (k / 6) * 184)
			_label(at, _name_of(index), 10, INK)
			_pill(at + Vector2(66, 2), _weapon_tier(index), 50.0)
			_card({"kind": "weapon", "value": index}, at + Vector2(0, 18), 0.5)
			_label(at + Vector2(0, 18 + CARD_SIZE.y * 0.5 + 2), _forge_note(index), 8, MUTED, 180.0)
		await _save()

func _pages_fairies() -> void:
	var list: Array = Run.new().reward_fairy_pool.duplicate()
	var per_page := 9
	var pages_needed := ceili(float(list.size()) / per_page)
	for p in pages_needed:
		var chunk: Array = list.slice(p * per_page, (p + 1) * per_page)
		_page("妖精カード：通常とクラスアップ後（%d / %d）" % [p + 1, pages_needed], "クラスアップはキャンプで選ぶ。使用回数・AP・効果が変わる（カードは強化後の説明を表示）。")
		for k in chunk.size():
			var id: String = chunk[k]
			var at := Vector2(18 + (k % 3) * 384, 58 + (k / 3) * 250)
			_label(at, str(model.item_definition(id).title), 13, INK)
			_pill(at + Vector2(130, 3), _fairy_tier(id), 54.0)
			var factor := 0.64
			_card({"kind": "fairy", "value": id}, at + Vector2(0, 20), factor)
			if model.PLUS_TEXT.has(id) or model.EVOLUTIONS.has(id):
				_card({"kind": "fairy", "value": id}, at + Vector2(160, 20), factor, true)
			else:
				_placeholder(at + Vector2(160, 20), factor, "クラスアップなし")
			_label(at + Vector2(0, 20 + CARD_SIZE.y * factor + 2), "通常", 9, Color("4fb4ff"))
			_label(at + Vector2(160, 20 + CARD_SIZE.y * factor + 2), "クラスアップ後", 9, Color("4fb4ff"))
		await _save()

func _page_weapon_list() -> void:
	var list: Array = range(W.DATA.size()).filter(func(index: int) -> bool: return not W.is_pair_member(index))
	_page("武器のレアリティ一覧（全%d種）" % list.size())
	var per_column := ceili(float(list.size()) / 2.0)
	for k in list.size():
		var index: int = list[k]
		var at := Vector2(30 + (k / per_column) * 570, 60 + (k % per_column) * 29)
		_label(at, _name_of(index), 14, INK)
		_pill(at + Vector2(150, 2), _weapon_tier(index), 64.0)
		_label(at + Vector2(228, 1), _forge_short(index), 11, Color("4fb4ff") if _forge_short(index) != "強化なし" else MUTED)
	await _save()

func _page_fairy_list() -> void:
	var list: Array = Run.new().reward_fairy_pool.duplicate()
	_page("妖精のレアリティ一覧（全%d種）" % list.size())
	var per_column := ceili(float(list.size()) / 2.0)
	for k in list.size():
		var id: String = list[k]
		var at := Vector2(30 + (k / per_column) * 570, 60 + (k % per_column) * 34)
		_label(at, str(model.item_definition(id).title), 15, INK)
		_pill(at + Vector2(190, 2), _fairy_tier(id), 64.0)
		var has_up: bool = model.PLUS_TEXT.has(id) or model.EVOLUTIONS.has(id)
		_label(at + Vector2(270, 1), "クラスアップあり" if has_up else "クラスアップなし", 12, Color("4fb4ff") if has_up else MUTED)
	await _save()
