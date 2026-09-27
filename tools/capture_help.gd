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
	m.owned_weapons.assign([0, ids.find("vault"), index])
	m.weapon = index

func setup(foes: Array, you: Vector2i, weapon_id: String = "forward") -> void:
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

func shot(name: String, area: Rect2) -> void:
	bv.queue_redraw()
	await frames(4)
	var image: Image = root.get_texture().get_image()
	var rect := Rect2i(area.position * SCALE, area.size * SCALE)
	image.get_region(rect).save_png("res://assets/help/%s.png" % name)

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
	# Basics: lit tiles, moving, attacking without moving, winning.
	setup([["heavy", Vector2i(3, 0)]], Vector2i(0, 1), "front_diagonal")
	await shot("move_a", board())
	act(Vector2i(1, 2))
	await shot("move_b", board())
	setup([["heavy", Vector2i(1, 1)]], Vector2i(0, 1))
	await shot("attack_a", board())
	act(Vector2i(1, 1))
	await frames(2)
	await shot("attack_b", board())
	setup([["recruit", Vector2i(1, 1)]], Vector2i(0, 1))
	act(Vector2i(1, 1))
	await frames(2)
	await shot("win", Rect2(368, 226, 416, 282))
	# Your AP: the panel emptying one action at a time.
	var panel := Rect2(24, 94, 280, 90)
	setup([["heavy", Vector2i(3, 3)]], Vector2i(0, 1))
	await shot("ap_2", panel)
	act(Vector2i(1, 1))
	await shot("ap_1", panel)
	act(Vector2i(2, 1))
	await shot("ap_0", panel)
	# Turn over: the enemies move.
	setup([["heavy", Vector2i(3, 1)]], Vector2i(0, 1))
	m.player.ap = 0
	await shot("turn_a", board())
	enemy_turn()
	await shot("turn_b", board())
	# Enemy AP: an AP-1 heavy steps once; an AP-2 executioner steps and hits.
	setup([["heavy", Vector2i(3, 1)]], Vector2i(0, 1))
	await shot("eap1_a", board())
	enemy_turn()
	await shot("eap1_b", board())
	setup([["executioner", Vector2i(2, 1)]], Vector2i(0, 1))
	await shot("eap2_a", board())
	enemy_turn()
	await frames(2)
	await shot("eap2_b", board())
	# Hovering an enemy: its AP and range in the info panel.
	setup([["executioner", Vector2i(2, 1)]], Vector2i(0, 3))
	bv.selected_enemy_id = 0
	await shot("inspect_ap", Rect2(832, 94, 296, 300))
	# "!": the enemies that would hit you if you stayed.
	setup([["recruit", Vector2i(1, 1)], ["heavy", Vector2i(3, 3)]], Vector2i(0, 1), "vault")
	await shot("threat_a", board())
	act(Vector2i(0, 3))
	m.player.ap = 2
	bv._sync_units(false)
	await shot("threat_b", board())
	# Weapons: the bar, a jump, a slide.
	# Switching weapons changes the lit tiles (free).
	setup([["heavy", Vector2i(3, 3)]], Vector2i(1, 1), "front_diagonal")
	m.weapon = 0
	bv.queue_redraw()
	await shot("switch_a", board())
	m.weapon = ids.find("front_diagonal")
	await shot("switch_b", board())
	setup([["heavy", Vector2i(0, 1)]], Vector2i(0, 2), "vault")
	m.weapon = ids.find("vault")
	await shot("jump", board())
	setup([["heavy", Vector2i(3, 1)]], Vector2i(0, 1), "rook_spear")
	await shot("slide", board())
	# Knockback into a wall.
	setup([["heavy", Vector2i(1, 1)]], Vector2i(0, 1), "shield")
	m.obstacles.append(Vector2i(2, 1))
	bv.queue_redraw()
	await shot("push_a", board())
	act(Vector2i(1, 1))
	await frames(2)
	await shot("push_b", board())
	# Magic circle: the preview, then the spell mid-cast.
	setup([["heavy", Vector2i(1, 1)], ["heavy", Vector2i(3, 3)]], Vector2i(0, 1), "front_diagonal")
	m.enchants[m.weapon] = "circle"
	m.enemies[0].hp = 9
	m.circle_tiles.assign([Vector2i(1, 0), Vector2i(2, 1)])
	bv.hover_cell = Vector2i(1, 2)
	await shot("circle_a", board(40))
	bv.hover_cell = Vector2i(-9, -9)
	act(Vector2i(1, 2))
	bv.set_process(true)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1050:
		await process_frame
	await shot("circle_b", board(40))
	while Time.get_ticks_msec() - start < 1600:
		await process_frame
	await shot("circle_c", board(40))
	bv.set_process(false)
	await frames(90)
	# Fairies: placing, cannons, the three-turn countdown.
	setup([["heavy", Vector2i(3, 3)]], Vector2i(0, 1))
	m.fairy_loadout.assign(["wall_fairy", "cannon_fairy"])
	m.refill_fairies()
	bv._select_item("wall_fairy", 0)
	bv.hover_cell = Vector2i(1, 1)
	await shot("place_a", board())
	bv.hover_cell = Vector2i(-9, -9)
	bv._commit_item(Vector2i(1, 1), Vector2i.ZERO)
	await frames(8)
	await shot("place_b", board())
	setup([["heavy", Vector2i(3, 1)], ["heavy", Vector2i(2, 1)]], Vector2i(0, 1))
	m.place_cannon(Vector2i(1, 1), Vector2i.RIGHT, "lance")
	bv.queue_redraw()
	await shot("cannon_a", board())
	act(Vector2i(1, 1))
	await frames(3)
	await shot("cannon_b", board())
	setup([["heavy", Vector2i(3, 3)]], Vector2i(0, 1))
	for turns in [3, 2, 1]:
		m.walls[Vector2i(1, 1)] = turns
		await shot("fade_%d" % turns, board())
