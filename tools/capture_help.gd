extends SceneTree
## Takes the field manual's screenshots from the real game and saves them to
## assets/help/. Run it again whenever the battle screen changes:
##   xvfb-run godot --rendering-driver opengl3 --path . --script res://tools/capture_help.gd

const RunView = preload("res://scripts/run/run_view.gd")
const Planner = preload("res://scripts/enemy_planner.gd")
const SCALE := 1.5
var view
var bv
var m
var ids: Array

func _init() -> void:
	# The screenshots use fairies; they must not unlock them in the player's fairy book.
	load("res://scripts/fairy_book.gd").recording = false
	load("res://scripts/battle_view.gd").help_seen = true
	root.size = Vector2i(1728, 1080)
	view = RunView.new()
	root.add_child(view)
	await process_frame
	var run = view.run
	ids = run.Weapons.DATA.map(func(w): return w.id)
	run.start(3)
	run.choose(0)
	run.choose(0)
	view._render()
	await frames(10)
	bv = view.battle_view
	m = run.battle
	bv.set_process(false)
	await capture_all()
	print("help screenshots saved")
	quit()

func frames(count: int) -> void:
	for i in count:
		await process_frame

func weapon(id: String) -> void:
	var index: int = ids.find(id)
	m.owned_weapons.assign([0, ids.find("vertical"), index])
	m.weapon = index

## The examples use the silver general's sword (the widest plain reach) unless the picture is
## about a particular weapon (directions, combos, hammer, push, circle, fairy range).
func setup(foes: Array, you: Vector2i, weapon_id: String = "silver") -> void:
	m.phase = m.Phase.PLAYER
	m.enemies.clear()
	for k in foes.size():
		m.enemies.append(m.make_enemy(foes[k][0], foes[k][1], k))
	for list in [m.allies, m.cannons, m.obstacles, m.circle_tiles, m.mines, m.fairies]:
		list.clear()
	m.walls.clear()
	m.enchants.clear()
	m.player.cell = you
	m.player.ap = 2
	m.player.hp = 5
	weapon(weapon_id)
	bv.selected_enemy_id = -2
	bv._cancel_item()
	bv.flashes.clear()
	bv.hover_cell = Vector2i(-9, -9)
	bv._sync_units(false)
	bv._update_controls()
	bv.queue_redraw()

func board(margin: float = 12.0) -> Rect2:
	var side: float = m.board_size * 64.0
	return Rect2(bv.BOARD - Vector2.ONE * margin, Vector2.ONE * (side + margin * 2))

const PANEL := Rect2(24, 94, 280, 84)
const HAND := Rect2(24, 262, 280, 100)
## "あなたのターン" / "敵のターン" above the board.
const TURN := Rect2(340, 96, 420, 44)

## The equipped weapon's card in the bar under the board.
func card() -> Rect2:
	var slot: int = m.owned_weapons.find(m.weapon)
	return Rect2(352 + slot * 260, 620, 248, 94)

## Saves several screen areas stacked top to bottom as one picture.
func shot(name: String, areas, left: Image = null) -> void:
	bv.queue_redraw()
	await frames(4)
	var screen: Image = root.get_texture().get_image()
	var parts: Array = areas if areas is Array else [areas]
	var pieces: Array[Image] = []
	var width := 0
	var height := 0
	for area in parts:
		var piece := screen.get_region(Rect2i(area.position * SCALE, area.size * SCALE))
		pieces.append(piece)
		width = maxi(width, piece.get_width())
		height += piece.get_height() + 6
	var out := Image.create(width, height - 6, false, screen.get_format())
	out.fill(Color("0c181b"))
	var y := 0
	for piece in pieces:
		out.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i((width - piece.get_width()) / 2, y))
		y += piece.get_height() + 6
	if left != null:
		# A picture standing at the left of the screenshot (the three weapons).
		var wide := Image.create(left.get_width() + 10 + out.get_width(), maxi(left.get_height(), out.get_height()), false, screen.get_format())
		wide.fill(Color("0c181b"))
		wide.blit_rect(left, Rect2i(Vector2i.ZERO, left.get_size()), Vector2i(0, (wide.get_height() - left.get_height()) / 2))
		wide.blit_rect(out, Rect2i(Vector2i.ZERO, out.get_size()), Vector2i(left.get_width() + 10, (wide.get_height() - out.get_height()) / 2))
		out = wide
	out.save_png("res://assets/help/%s.png" % name)

## The three owned weapons as small range diagrams (no names), the equipped one framed in
## gold: stands at the left of a screenshot so a weapon switch can be seen.
func weapon_strip() -> Image:
	var Diagram = load("res://scripts/run/range_diagram.gd")
	var holder := Control.new()
	holder.z_index = 200
	holder.position = Vector2.ZERO
	holder.size = Vector2(104, 312)
	holder.scale = Vector2.ONE * SCALE
	var back := ColorRect.new()
	back.color = Color("0c181b")
	back.size = holder.size
	holder.add_child(back)
	for slot in m.owned_weapons.size():
		var index: int = m.owned_weapons[slot]
		var frame := ColorRect.new()
		frame.color = Color("ffd35b") if index == m.weapon else Color("2c4a44")
		frame.position = Vector2(2, 2 + slot * 104)
		frame.size = Vector2(100, 100)
		holder.add_child(frame)
		var inner := ColorRect.new()
		inner.color = Color("0a1416")
		inner.position = frame.position + Vector2(3, 3)
		inner.size = Vector2(94, 94)
		holder.add_child(inner)
		var diagram = Diagram.new()
		diagram.position = inner.position + Vector2(2, 2)
		diagram.size = Vector2(90, 90)
		diagram.offsets = view.run.Weapons.offsets(index)
		diagram.slides = view.run.Weapons.slides(index)
		diagram.echo = view.run.Weapons.hammer_echo(index)
		diagram.hammer = view.run.Weapons.is_hammer(index)
		diagram.accent = Color(m.WEAPONS[index].color)
		holder.add_child(diagram)
	# On a canvas layer above the battle screen's own, so nothing draws over it.
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(holder)
	root.add_child(layer)
	await frames(4)
	var image: Image = root.get_texture().get_image().get_region(Rect2i(Vector2i.ZERO, Vector2i(holder.size * SCALE)))
	layer.queue_free()
	await frames(2)
	return image

## Runs the battle view for `ms` milliseconds so an animation plays out.
func play(ms: int) -> void:
	bv.set_process(true)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < ms:
		await process_frame
	bv.set_process(false)

func act(cell: Vector2i) -> void:
	m.player_action(cell)
	bv._sync_units(false)
	bv._feedback(true)
	bv._update_controls()

func enemy_turn() -> void:
	var planner = Planner.new()
	planner.begin(m)
	planner.beat(m, 0)
	planner.beat(m, 1)
	planner.finish(m)
	bv._sync_units(false)
	bv._feedback()
	bv._update_controls()

func capture_all() -> void:
	# --- 基本: with the AP panel, each action costs 1 ---
	setup([["heavy", Vector2i(3, 3)]], Vector2i(0, 1), "silver")
	await shot("basic_move_a", [PANEL, board()])
	act(Vector2i(1, 2))
	await shot("basic_move_b", [PANEL, board()])
	setup([["heavy", Vector2i(1, 1)], ["heavy", Vector2i(3, 3)]], Vector2i(0, 1))
	await shot("basic_attack_a", [PANEL, board()])
	act(Vector2i(1, 1))
	await frames(2)
	await shot("basic_attack_b", [PANEL, board()])
	setup([["heavy", Vector2i(3, 3)]], Vector2i(0, 1))
	m.fairy_loadout.assign(["wall_fairy", "cannon_fairy"])
	m.refill_fairies()
	bv._select_item("wall_fairy", 0)
	await shot("basic_fairy_a", [PANEL, board()])
	bv._commit_item(Vector2i(1, 1), Vector2i.ZERO)
	await frames(8)
	await shot("basic_fairy_b", [PANEL, board()])
	# --- AP: two actions, then the enemy turn; switching is free ---
	# The turn loop: your AP runs out, the enemies act, your turn comes back.
	var turn_area := [PANEL, TURN, board()]
	setup([["heavy", Vector2i(2, 1)], ["heavy", Vector2i(3, 3)]], Vector2i(0, 1))
	m.enemies[0].hp = 5
	await shot("loop_0", turn_area)
	act(Vector2i(1, 1))
	await shot("loop_1", turn_area)
	act(Vector2i(2, 1))
	await frames(2)
	await shot("loop_2", turn_area)
	var planner = Planner.new()
	planner.begin(m)
	planner.beat(m, 0)
	planner.beat(m, 1)
	bv.busy = true
	bv._sync_units(false)
	bv._feedback()
	await frames(2)
	await shot("loop_3", turn_area)
	planner.finish(m)
	bv.busy = false
	bv._sync_units(false)
	bv._update_controls()
	await shot("loop_4", turn_area)
	# [seg:end] Ending the turn without spending any AP.
	setup([["heavy", Vector2i(2, 1)], ["heavy", Vector2i(3, 3)]], Vector2i(0, 1))
	m.enemies[0].hp = 5
	await shot("end_a", turn_area)
	planner = Planner.new()
	planner.begin(m)
	planner.beat(m, 0)
	planner.beat(m, 1)
	bv.busy = true
	bv._sync_units(false)
	bv._feedback()
	await frames(2)
	await shot("end_b", turn_area)
	planner.finish(m)
	bv.busy = false
	bv._sync_units(false)
	bv._update_controls()
	# --- 武器: directions, power, combining ---
	# [seg:dir] Weapons reach different tiles.
	for pick in [["dir_a", "forward"], ["dir_b", "vertical"], ["dir_c", "knight"]]:
		setup([["heavy", Vector2i(3, 3)]], Vector2i(0, 1), pick[1])
		m.player.cell = Vector2i(1, 1)
		bv._sync_units(false)
		await shot(pick[0], [board(), card()])
	# [seg:power] Weapons hit for different amounts: the hammer's blow as it plays now.
	setup([["heavy", Vector2i(1, 1)], ["heavy", Vector2i(3, 3)]], Vector2i(0, 1), "hammer")
	m.enemies[0].hp = 5
	await shot("power_a", [board(), card()])
	act(Vector2i(1, 1))
	await play(330)
	await shot("power_b", [board(), card()])
	await frames(60)
	# [seg:combo] Move with one weapon, switch (free), strike with another: the three weapons at the left.
	setup([["heavy", Vector2i(1, 2)], ["heavy", Vector2i(3, 3)]], Vector2i(0, 3), "vertical")
	m.owned_weapons.assign([ids.find("forward"), ids.find("vertical"), ids.find("front_diagonal")])
	m.weapon = ids.find("vertical")
	await shot("combo_0", [PANEL, board()], await weapon_strip())
	act(Vector2i(0, 2))
	await shot("combo_1", [PANEL, board()], await weapon_strip())
	m.weapon = ids.find("forward")
	await shot("combo_2", [PANEL, board()], await weapon_strip())
	act(Vector2i(1, 2))
	await frames(2)
	await shot("combo_3", [PANEL, board()], await weapon_strip())
	# --- 特殊効果 ---
	# [seg:hammer] The hammer's area blow, as it plays in the battle.
	setup([["heavy", Vector2i(1, 1)], ["heavy", Vector2i(1, 0)], ["heavy", Vector2i(1, 2)], ["heavy", Vector2i(2, 1)]], Vector2i(0, 1), "hammer")
	for enemy in m.enemies:
		enemy.hp = 5
	bv.hover_cell = Vector2i(1, 1)
	await shot("hammer_a", board())
	bv.hover_cell = Vector2i(-9, -9)
	act(Vector2i(1, 1))
	await play(330)
	await shot("hammer_b", board())
	await play(900)
	await shot("hammer_c", board())
	await frames(60)
	# [seg:push] A shoved enemy that hits another enemy: both take 1.
	setup([["heavy", Vector2i(1, 1)], ["heavy", Vector2i(3, 1)]], Vector2i(0, 1), "shield")
	for enemy in m.enemies:
		enemy.hp = 5
	bv.queue_redraw()
	await shot("push_a", board())
	act(Vector2i(1, 1))
	await play(170)
	await shot("push_b", board())
	await play(330)
	await shot("push_c", board())
	await frames(60)
	# [seg:circle] Walked tiles turn white; closing the ring... 99.
	setup([["heavy", Vector2i(1, 1)], ["heavy", Vector2i(3, 3)]], Vector2i(0, 1), "front_diagonal")
	m.enchants[m.weapon] = "circle"
	m.enemies[0].hp = 9
	m.circle_tiles.assign([Vector2i(1, 0), Vector2i(2, 1)])
	bv.queue_redraw()
	await shot("circle_a", board(40))
	act(Vector2i(1, 2))
	await play(1050)
	await shot("circle_b", board(40))
	await play(550)
	await shot("circle_c", board(40))
	await frames(90)
	# --- 妖精: 1 AP, placed in weapon range, once per fight ---
	# [seg:range] Where a fairy can go depends on the weapon.
	for pick in [["fairy_range_a", "forward"], ["fairy_range_b", "front_diagonal"]]:
		setup([["heavy", Vector2i(3, 3)]], Vector2i(1, 1), pick[1])
		m.fairy_loadout.assign(["wall_fairy"])
		m.refill_fairies()
		bv._select_item("wall_fairy", 0)
		await shot(pick[0], [board(), card()])
	# [seg:once] Calling a fairy costs 1 AP.
	setup([["heavy", Vector2i(3, 3)]], Vector2i(0, 1))
	m.fairy_loadout.assign(["wall_fairy", "cannon_fairy"])
	m.refill_fairies()
	bv._update_controls()
	await shot("fairy_once_a", [PANEL, HAND])
	bv._select_item("wall_fairy", 0)
	bv._commit_item(Vector2i(1, 1), Vector2i.ZERO)
	await frames(8)
	await shot("fairy_once_b", [PANEL, HAND])
	setup([["heavy", Vector2i(3, 1)], ["heavy", Vector2i(2, 1)]], Vector2i(0, 1))
	m.place_cannon(Vector2i(1, 1), Vector2i.RIGHT, "lance")
	bv.queue_redraw()
	await shot("cannon_a", board())
	act(Vector2i(1, 1))
	await frames(3)
	await shot("cannon_b", board())
	# --- 敵にもAP ---
	setup([["heavy", Vector2i(2, 1)]], Vector2i(0, 1))
	await shot("eap1_a", board())
	enemy_turn()
	await shot("eap1_b", board())
	setup([["executioner", Vector2i(2, 1)]], Vector2i(0, 1))
	await shot("eap2_a", board())
	enemy_turn()
	await frames(2)
	await shot("eap2_b", board())
	setup([["executioner", Vector2i(2, 1)]], Vector2i(0, 3))
	bv.selected_enemy_id = 0
	await shot("inspect_ap", Rect2(832, 94, 296, 420))
	# --- 危険: the rule, then a real dodge ---
	setup([["recruit", Vector2i(1, 1)], ["heavy", Vector2i(3, 3)]], Vector2i(0, 1))
	await shot("threat_rule", board())
	setup([["heavy", Vector2i(2, 2)], ["heavy", Vector2i(1, 0)]], Vector2i(1, 2), "backward")
	m.weapon = 1
	await shot("dodge_0", board())
	bv.hover_cell = Vector2i(0, 2)
	await shot("dodge_1", board())
	bv.hover_cell = Vector2i(-9, -9)
	act(Vector2i(0, 2))
	await shot("dodge_2", board())
	m.player.ap = 0
	enemy_turn()
	await frames(2)
	await shot("dodge_3", [PANEL, board()])
