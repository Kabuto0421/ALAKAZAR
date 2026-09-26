extends SceneTree
const Run = preload("res://scripts/run/run_model.gd")
const Rules = preload("res://scripts/battle_model.gd")
const Card = preload("res://scripts/run/choice_card.gd")
const Motion = preload("res://scripts/animation/sword_motion.gd")
var checks := 0
var failures := 0
var app

func verify(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func click(button: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)

func cards() -> Array:
	return app.screen.get_children().filter(func(node): return node is Card)

func run() -> void:
	root.size=Vector2i(1728,1080)
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	verify(app.run.state==Run.State.START_WEAPON and not is_instance_valid(app.battle_view),"Initial draft is a separate screen with no battlefield")
	click(cards()[0])
	await process_frame
	verify(app.run.state==Run.State.START_FAIRY and cards().size()==3,"Weapon click opens fairy selection")
	for card in cards():
		if card.offer.value=="acorn_fairy":
			click(card)
			break
	await create_timer(0.8).timeout
	var view = app.battle_view
	verify(view != null and view.model.board_size==4 and view.model.phase==Rules.Phase.PLAYER,"Fairy click starts the first battle and enemy-first turn")
	verify(view.grid_buttons.filter(func(b): return b.visible).size()==16,"Only 4x4 board cells are clickable")
	verify(view.actors[-1].facing==1 and view.model.enemies.all(func(e): return view.actors[e.id].facing==3),"Player faces right and enemy sprites face left")
	verify(not view.model.turn_to(0),"Rotation and paid equip buttons were removed")
	verify(view.inventory_ui.quick_buttons[0].position.x==24 and view.weapon_buttons[0].position.y>=620,"Fairies are on the left; weapons moved below board")
	click(view.weapon_buttons[1])
	verify(view.model.weapon==1 and view.model.player.ap==2,"One click equips backward weapon without AP")
	click(view.weapon_buttons[0])
	verify(view.model.weapon==0 and view.model.player.ap==2,"Repeated switching remains free")
	view._act(view.model.player.cell)
	verify(view.model.facing==1 and view.model.player.ap==2,"Clicking the player does not open rotation")
	view.model.enemies.clear()
	view.model.enemies.append(view.model.make_enemy("recruit",Vector2i(2,2),0))
	view.model.enemies.append(view.model.make_enemy("heavy",Vector2i(3,0),1))
	view._sync_units(false)
	view._update_controls()
	click(view.inventory_ui.quick_buttons[0])
	verify(view.selected_item=="acorn_fairy" and view.model.player.ap==2,"Fairy selection does not consume AP")
	view._act(Vector2i(1,2))
	await create_timer(0.25).timeout
	verify(view.model.allies.size()==1 and view.model.fairy_charges==[0] and view.model.player.ap==1,"Acorn placement commits once for 1AP")
	verify(view.inventory_ui.quick_buttons[0].disabled,"Used skill stays visible but cannot be used twice")
	click(view.end_button)
	await create_timer(0.9).timeout
	verify(view.model.enemy_at(Vector2i(2,2)).is_empty() and view.model.kills==1,"Ally kills its adjacent target before enemies move")
	verify(view.model.phase==Rules.Phase.PLAYER and view.model.player.ap==2,"Turn returns to player after allies and enemies")
	# Every movement pattern shares the existing sword animation, including backward attacks.
	for weapon in range(Rules.WEAPONS.size()):
		view.model.phase=Rules.Phase.PLAYER
		view.model.player.ap=2
		# Two-tile jumps need room on the small board, so stand where the first offset lands inside.
		var first: Vector2i = view.model.weapon_offsets(weapon)[0]
		view.model.player.cell=Vector2i(clampi(1,-first.x,view.model.board_size-1-first.x),clampi(1,-first.y,view.model.board_size-1-first.y))
		view.model.allies.clear()
		view.model.enemies.clear()
		view.model.owned_weapons.assign([weapon])
		view.model.equip(weapon)
		var target: Vector2i = view.model.player.cell+first
		view.model.enemies.append(view.model.make_enemy("heavy",target,0))
		view.model.enemies.append(view.model.make_enemy("heavy",Vector2i(3,3),1))
		view._sync_units(false)
		view._update_controls()
		view._act(target)
		verify(view.actors[-1].weapon_row==2 and view.actors[-1].sword_attack_elapsed>=0.0,"Weapon %d uses sword art and attack motion" % weapon)
		verify(view.model.player.ap==1 and view.model.enemies[0].hp==1,"Sword action deals one damage for one AP")
		view._act(target)
		verify(view.model.player.ap==1,"Animation rejects duplicate taps")
		await create_timer(Motion.duration(1)+0.08).timeout
	view.model.owned_weapons.assign([0,1,2])
	view.model.weapon=0
	view.model.enemies.clear()
	view.model.check_outcome()
	view._update_controls()
	await process_frame
	click(view.result_button)
	await process_frame
	verify(app.run.state==Run.State.REWARD and cards().size()==4,"Clear button opens four rewards")
	verify(app.run.battle.fairy_charges==[1],"Clear restores the used fairy")
	click(cards()[0])
	await process_frame
	verify(app.run.state==Run.State.REPLACE and cards().size()==3,"Weapon reward opens replacement choices at cap")
	click(cards()[2])
	await create_timer(0.8).timeout
	verify(app.run.state==Run.State.BATTLE and app.battle_view.model.board_size==5,"Replacement click starts 5x5 stage")
	verify(app.battle_view.grid_buttons.filter(func(b): return b.visible).size()==25,"5x5 has 25 active hit targets")
	app.queue_free()
	await create_timer(0.2).timeout
	print("RUN UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
