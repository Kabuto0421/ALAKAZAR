extends SceneTree

const Rules = preload("res://scripts/battle_model.gd")
const Planner = preload("res://scripts/enemy_planner.gd")
var checks := 0
var failures := 0

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func fixture(entries: Array = [["heavy",0,0]]) -> RefCounted:
	var model := Rules.new()
	model.reset()
	model.phase = Rules.Phase.PLAYER
	model.player.cell = Vector2i(2,4)
	model.enemies.clear()
	for entry in entries:
		model.enemies.append(model.make_enemy(entry[0],Vector2i(entry[1],entry[2]),model.enemies.size()))
	return model

func _initialize() -> void:
	call_deferred("run")

func click(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)

func run() -> void:
	var model := fixture([["infantry",2,2],["heavy",2,0],["infantry",4,2]])
	verify(not model.use_item("magic_bolt",Vector2i(2,3),Vector2i(1,-1)),"Diagonal directions rejected")
	verify(not model.use_item("magic_bolt",Vector2i(2,3)),"Missing direction rejected")
	verify(not model.use_item("magic_bolt",Vector2i(5,0),Vector2i.UP),"Placement limited to weapon range")
	verify(model.player.ap==2 and model.inventory.magic_bolt==1,"Invalid uses do not spend AP or stock")
	verify(model.use_item("magic_bolt",Vector2i(2,3),Vector2i.UP),"Magic bolt can be placed and fired")
	verify(model.kills==1 and model.enemy_at(Vector2i(2,0)).hp==1 and model.enemy_at(Vector2i(4,2)).hp==1,"Bolt pierces all enemies on its line only")
	verify(model.player.ap==1 and model.inventory.magic_bolt==0,"Bolt costs exactly one AP and item")
	verify(not model.use_item("magic_bolt",Vector2i(2,3),Vector2i.UP),"Depleted item cannot fire again")
	for direction in Rules.CARDINALS:
		model = fixture()
		model.enemies[0].cell = Vector2i(2,3)+direction*2
		verify(model.use_item("magic_bolt",Vector2i(2,3),direction) and model.enemies[0].hp==1,"Each cardinal direction hits correctly")
	model = fixture([["heavy",2,0]])
	model.obstacles.append(Vector2i(2,1))
	model.use_item("magic_bolt",Vector2i(2,3),Vector2i.UP)
	verify(model.enemies[0].hp==2,"Solid obstacle stops bolt")
	model = fixture()
	model.weapon=2
	verify(not model.item_targets("stealth_fairy").has(Vector2i(2,3)) and model.item_targets("stealth_fairy").has(Vector2i(1,2)),"Placement follows current knight weapon")
	model = fixture()
	verify(model.use_item("stealth_fairy",Vector2i(2,3)) and model.fairies.has(Vector2i(2,3)),"Fairy remains hidden without adjacent enemies")
	verify(not model.player_action(Vector2i(2,3)) and not model.item_targets("warp_fairy").has(Vector2i(2,3)),"Hidden fairy blocks walking and warp")
	model.phase=Rules.Phase.ENEMY
	model.enemies[0].cell=Vector2i(2,2)
	verify(not model.enemy_step(model.enemies[0],Vector2i(2,3)),"Hidden fairy blocks enemies")
	model.enemies[0].cell=Vector2i(1,2)
	model.enemy_step(model.enemies[0],Vector2i(2,2))
	verify(model.enemies[0].hp==1 and model.fairies.is_empty(),"Fairy reacts on entry for one damage and vanishes")
	verify(not model.blocked(Vector2i(2,3)),"Spent fairy no longer obstructs")
	model = fixture([["infantry",2,2],["infantry",1,3]])
	model.use_item("stealth_fairy",Vector2i(2,3))
	verify(model.kills==1 and model.enemies.size()==1 and model.fairies.is_empty(),"Adjacent placement triggers once with multiple targets")
	model = fixture([["infantry",2,1],["heavy",5,0]])
	model.use_item("stealth_fairy",Vector2i(2,3))
	model.enemies[0].state="charge"
	model.enemies[0].charge_round=1
	var planner := Planner.new()
	planner.begin(model)
	planner.beat(model,0)
	planner.beat(model,1)
	planner.finish(model)
	verify(model.kills==1 and model.player.hp==5,"Ambushed enemy loses its remaining actions")
	model = fixture([["miner",1,2]])
	model.use_item("stealth_fairy",Vector2i(2,3))
	model.phase=Rules.Phase.ENEMY
	model.enemy_step(model.enemies[0],Vector2i(2,2))
	verify(model.phase==Rules.Phase.WON,"Fairy can defeat a drone and end combat")
	model = fixture()
	model.obstacles.append(Vector2i(3,0))
	verify(not model.use_item("warp_fairy",Vector2i(0,0)) and not model.use_item("warp_fairy",Vector2i(3,0)),"Warp rejects occupied and obstructed cells")
	verify(not model.use_item("warp_fairy",model.player.cell) and not model.use_item("warp_fairy",Vector2i(6,0)),"Warp rejects own tile and off-board targets")
	model.mines.append(Vector2i(5,0))
	verify(model.use_item("warp_fairy",Vector2i(5,0)) and model.player.cell==Vector2i(5,0),"Warp reaches distant free cell")
	verify(model.player.hp==4 and model.mines.is_empty() and model.player.ap==1,"Warp lands on mines and costs one AP")
	model = fixture([["infantry",2,1]])
	model.use_item("magic_bolt",Vector2i(2,3),Vector2i.UP)
	verify(model.phase==Rules.Phase.WON,"Bolt can finish combat")
	model.reset(1,true)
	verify(model.inventory.magic_bolt==0 and model.inventory.warp_fairy==1,"Next battle preserves remaining inventory")
	model.reset(1)
	verify(model.inventory.magic_bolt==1 and model.fairies.is_empty(),"Restart replenishes initial stock and clears summons")
	model.phase=Rules.Phase.PLAYER
	model.player.ap=0
	verify(not model.use_item("warp_fairy",Vector2i(5,5)) and model.inventory.warp_fairy==1,"AP shortage prevents item use")
	model.player.ap=2
	model.phase=Rules.Phase.ENEMY
	verify(not model.use_item("warp_fairy",Vector2i(5,5)),"Cannot use items during enemy turn")
	verify(model.assign_shortcut(0,"warp_fairy") and model.shortcuts==["warp_fairy","stealth_fairy","magic_bolt"] and model.player.ap==2,"Shortcut registration swaps slots for free")
	verify(not model.assign_shortcut(3,"warp_fairy") and not model.assign_shortcut(0,"unknown"),"Invalid registration is rejected")
	# Mix items into complete battles to check interactions with mines and AI.
	var rng := RandomNumberGenerator.new()
	rng.seed=29022
	for trial in range(100):
		model = Rules.new()
		model.reset(trial%3)
		for turn in range(30):
			if model.terminal(): break
			planner.begin(model)
			planner.beat(model,0)
			planner.beat(model,1)
			planner.finish(model)
			if model.terminal(): break
			for action in range(2):
				var id: String = model.ITEMS[rng.randi_range(0,2)].id
				var targets: Array = model.item_targets(id)
				if targets.is_empty() or not model.use_item(id,targets[rng.randi_range(0,targets.size()-1)],Rules.CARDINALS[rng.randi_range(0,3)]):
					var cells: Array = model.targets()
					if not cells.is_empty(): model.player_action(cells[rng.randi_range(0,cells.size()-1)])
			for enemy in model.enemies:
				verify(enemy.hp>0 and not model.blocked(enemy.cell) and enemy.cell!=model.player.cell,"AI never overlaps summons or player")
			verify(model.player.ap>=0 and not model.blocked(model.player.cell),"Player and AP remain valid")
			for count in model.inventory.values(): verify(count>=0,"Inventory never goes negative")
	root.size=Vector2i(1728,1080)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.6).timeout
	scene.model=fixture()
	scene._sync_units(false)
	scene._update_controls()
	click(scene.inventory_ui.quick_buttons[0].get_global_rect().get_center())
	verify(scene.selected_item=="magic_bolt" and scene.model.player.ap==2,"Quick slot mouse click starts free targeting")
	scene._act(Vector2i(2,3))
	verify(scene.item_origin==Vector2i(2,3) and scene.model.inventory.magic_bolt==1,"Choosing origin does not consume item")
	var cancel := InputEventKey.new()
	cancel.keycode=KEY_ESCAPE
	cancel.pressed=true
	root.push_input(cancel,true)
	verify(scene.selected_item.is_empty() and scene.model.player.ap==2,"Escape cancels targeting for free")
	verify(scene.model.add_item("magic_bolt",10)==4 and scene.model.hand_size()==7,"Hand accepts up to seven cards")
	verify(scene.model.add_item("warp_fairy")==0,"Full hand rejects an eighth card")
	scene.model.inventory.magic_bolt=1
	scene._update_controls()
	click(scene.inventory_ui.quick_buttons[0].get_global_rect().get_center())
	await process_frame
	verify(scene.selected_item=="magic_bolt" and scene.model.player.ap==2,"Hand selection is free")
	scene._act(Vector2i(2,3))
	await process_frame
	click(scene.direction_buttons[0].get_global_rect().get_center())
	await create_timer(0.2).timeout
	verify(scene.model.inventory.magic_bolt==0 and scene.model.player.ap==1 and scene.selected_item.is_empty(),"Direction button commits once and clears selection")
	scene._select_item("warp_fairy")
	scene._act(Vector2i(5,5))
	await create_timer(0.8).timeout
	verify(scene.model.player.cell==Vector2i(5,5) and scene.model.player.ap==2 and not scene.busy,"Last AP item automatically completes enemy turn")
	scene._select_item("stealth_fairy")
	scene._start(0)
	await create_timer(0.6).timeout
	verify(scene.selected_item.is_empty() and not scene.inventory_ui.opened,"Restart clears pending item UI")
	scene.model.inventory.magic_bolt=0
	scene.model.phase=Rules.Phase.WON
	scene._advance()
	await create_timer(0.6).timeout
	verify(scene.model.level==1 and scene.model.inventory.magic_bolt==0,"Scene advance preserves consumed items")
	scene.queue_free()
	await process_frame
	print("ITEMS: %d checks, %d failures; 100 mixed-item runs" % [checks,failures])
	quit(1 if failures else 0)
