extends SceneTree

const Rules = preload("res://scripts/battle_model.gd")
const Planner = preload("res://scripts/enemy_planner.gd")
const Infantry = preload("res://scripts/infantry_behavior.gd")
var checks := 0
var failures := 0

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+message)

func fixture(entries: Array) -> RefCounted:
	var model := Rules.new()
	model.reset()
	model.phase = Rules.Phase.PLAYER
	model.player.cell = Vector2i(2,4)
	model.enemies.clear()
	for entry in entries:
		model.enemies.append(model.make_enemy(entry[0],Vector2i(entry[1],entry[2]),model.enemies.size()))
	return model

func enemy_turn(model: RefCounted) -> void:
	var planner := Planner.new()
	planner.begin(model)
	planner.beat(model,0)
	planner.beat(model,1)
	planner.finish(model)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model := Rules.new()
	model.reset()
	verify(model.phase==Rules.Phase.ENEMY,"Enemy first")
	enemy_turn(model)
	verify(model.phase==Rules.Phase.PLAYER and model.player.ap==2,"Player AP reset")
	model = fixture([["heavy",0,0]])
	verify(model.targets().size()==6,"Gold six directions")
	model.equip(1)
	verify(model.targets().size()==5 and model.player.ap==1,"Silver switch costs one AP")
	model.equip(2)
	verify(model.targets()==[Vector2i(1,2),Vector2i(3,2)] and model.player.ap==0,"Knight switch costs one AP")
	verify(model.equip(0) == false,"Cannot switch without AP")
	model.player.cell.y=0
	verify(model.targets().is_empty(),"Knight board bounds")
	model = fixture([["heavy",2,2]])
	verify(not model.player_action(Vector2i(5,5)) and model.player.ap==2,"Invalid actions free")
	verify(model.player_action(Vector2i(2,3)) and model.player.ap==1,"Move costs one")
	verify(model.player_action(Vector2i(2,2)) and model.enemies[0].hp==1,"Attack one damage")
	verify(model.player.cell==Vector2i(2,3) and model.player.ap==0,"Attack does not move")
	verify(not model.player_action(Vector2i(2,2)),"No action without AP")
	model = fixture([["heavy",2,3],["infantry",0,0]])
	model.equip(2)
	model.mines.assign([Vector2i(2,3),Vector2i(1,2)])
	model.player_action(Vector2i(1,2))
	verify(model.player.hp==4 and model.mines==[Vector2i(2,3)],"Knight skips intermediate hazards and triggers landing mine")
	model = fixture([["infantry",1,2],["miner",3,2]])
	model.mines.assign([Vector2i(1,2),Vector2i(3,2)])
	model.trigger_mine(model.enemies[0])
	verify(model.enemies.size()==1 and model.kills==1,"Friendly mine casualty")
	model.trigger_mine(model.enemies[0])
	verify(model.enemies[0].hp==1 and model.mines.has(Vector2i(3,2)),"Flying drone does not consume mine")
	model = fixture([["miner",4,0]])
	enemy_turn(model)
	verify(model.distance(model.enemies[0].cell,Vector2i(4,0))==1,"Drone moves once")
	verify(model.mines.has(model.enemies[0].cell) and model.enemies[0].ap==0,"Drone plants at destination")
	model = fixture([["infantry",0,0],["miner",5,0]])
	model.mines.assign([Vector2i(1,0),Vector2i(0,1)])
	enemy_turn(model)
	verify(model.kills==0 and model.enemies[0].cell==Vector2i(0,0),"Infantry waits when all forward routes are mined")
	model = fixture([["heavy",2,2]])
	enemy_turn(model)
	verify(model.enemies[0].cell==Vector2i(2,3) and model.player.hp==5,"Heavy only one action")
	enemy_turn(model)
	verify(model.player.hp==4,"Adjacent heavy attacks once")
	model = fixture([["infantry",2,2],["infantry",0,0]])
	enemy_turn(model)
	verify(model.enemies[0].cell==Vector2i(2,3) and model.player.hp==4,"Unannounced infantry moves and attacks when two AP are enough")
	model = fixture([["infantry",2,1],["infantry",5,4]])
	enemy_turn(model)
	verify(model.player.hp==5 and model.enemies.all(func(e: Dictionary) -> bool: return e.state==Infantry.CHARGE and e.charge_round==2),"Coordinated charge is announced without same-turn damage")
	enemy_turn(model)
	verify(model.player.hp==3,"Announced infantry approach and attack next turn")
	model = fixture([["infantry",2,2],["infantry",0,0]])
	# Keep support distant and the direct path blocked to isolate the waiting rule.
	model.obstacles.append(Vector2i(2,3))
	enemy_turn(model)
	model.enemies[1].cell=Vector2i(0,0)
	enemy_turn(model)
	verify(model.enemies[0].state==Infantry.CHARGE,"Two encirclement turns trigger a charge without support")
	model = fixture([["infantry",2,1],["infantry",5,4]])
	model.weapon=2
	enemy_turn(model)
	model.enemies[1].hp=0
	model.check_outcome()
	model.equip(0)
	enemy_turn(model)
	verify(model.player.hp==3,"Safely adjacent infantry keeps its announced charge after weapon change and loss of support")
	model = fixture([["infantry",2,1]])
	enemy_turn(model)
	model.player.cell=Vector2i(5,5)
	enemy_turn(model)
	verify(model.player.hp==5 and model.enemies[0].state==Infantry.APPROACH,"Escaping the announced charge avoids damage and resumes approach")
	model = fixture([["infantry",2,5]])
	model.weapon=2
	enemy_turn(model)
	verify(model.player.hp==3 and model.enemies[0].ap==0,"Initially adjacent infantry attacks twice without a warning")
	model.enemies[0].cell=Vector2i(2,5)
	enemy_turn(model)
	verify(model.player.hp==1 and model.enemies[0].ap==0,"Adjacent infantry continues to spend one AP per hit")
	model = fixture([["infantry",2,2],["infantry",0,0]])
	model.weapon=2
	var planner := Planner.new()
	planner.begin(model)
	verify(planner.staging[0]==Vector2i(2,2) and planner.staging[0]!=planner.staging[1],"Infantry reserve separate staging cells")
	# The direct step is in knight range; the same-length side route is safe.
	model.enemies[0].cell=Vector2i(1,1)
	var behavior := Infantry.new()
	var choice: Dictionary = behavior.decide(model, model.enemies[0], {0: Vector2i(2,2)})
	verify(choice.kind=="step" and choice.cell==Vector2i(2,1),"Approach avoids current weapon range when a safe route exists")
	for weapon in range(3):
		model = fixture([["infantry",2,2]])
		model.weapon = weapon
		planner.begin(model)
		planner.beat(model,0)
		verify(model.enemies[0].cell==Vector2i(2,3) and model.enemies[0].ap==1 and model.player.hp==5,"Unannounced approach spends exactly one AP before attacking")
		planner.beat(model,1)
		verify(model.enemies[0].ap==0 and model.player.hp==4,"Second AP attacks regardless of equipped weapon")
	model = fixture([["infantry",2,2]])
	model.enemies[0].ap = 1
	choice = behavior.decide(model,model.enemies[0],{0:Vector2i(2,2)})
	verify(choice.kind=="wait","One AP does not trigger an unaffordable move-and-attack into weapon range")
	model.enemies[0].cell = Vector2i(2,3)
	model.enemies[0].ap = 0
	verify(behavior.decide(model,model.enemies[0],{}).kind=="wait","Zero AP never requests an attack")
	for obstruction in ["wall","mine","fairy","ally"]:
		model = fixture([["infantry",2,2]])
		if obstruction == "wall": model.obstacles.append(Vector2i(2,3))
		elif obstruction == "mine": model.mines.append(Vector2i(2,3))
		elif obstruction == "fairy": model.fairies.append(Vector2i(2,3))
		else: model.enemies.append(model.make_enemy("heavy",Vector2i(2,3),1))
		choice = behavior.decide(model,model.enemies[0],{0:Vector2i(2,2)})
		verify(choice.kind=="wait","Unannounced infantry does not attack through a %s" % obstruction)
	model = fixture([["infantry",1,3]])
	model.obstacles.append(Vector2i(2,3))
	planner.begin(model)
	planner.beat(model,0)
	verify(model.enemies[0].cell==Vector2i(1,4),"Diagonal approach uses the unblocked attack route")
	planner.beat(model,1)
	verify(model.player.hp==4,"Diagonal approach attacks without an announcement")
	# A staging assignment behind the unit must not override safe progress.
	model = fixture([["infantry",2,1]])
	choice = behavior.decide(model,model.enemies[0],{0:Vector2i(2,0)})
	verify(choice.kind=="step" and choice.cell==Vector2i(2,2),"Safe approach wins over a staging target behind the infantry")
	for kind in ["infantry","heavy"]:
		model = fixture([[kind,2,1]])
		model.obstacles.assign([Vector2i(2,2),Vector2i(1,1),Vector2i(3,1)])
		enemy_turn(model)
		verify(model.enemies[0].cell==Vector2i(2,1),"Blocked %s waits instead of retreating at long range" % kind)
		model = fixture([[kind,2,1]])
		model.mines.append(Vector2i(2,2))
		enemy_turn(model)
		verify(model.enemies[0].cell==Vector2i(2,1),"%s does not retreat when forward movement is mined" % kind)
	# Check every distance, board edge and weapon, including safe adjacent cells.
	for weapon in range(3):
		for py in range(6):
			for px in range(6):
				for ey in range(6):
					for ex in range(6):
						var player_cell := Vector2i(px,py)
						var origin := Vector2i(ex,ey)
						if player_cell == origin:
							continue
						for kind in ["infantry","heavy"]:
							model = fixture([[kind,ex,ey]])
							model.player.cell = player_cell
							model.weapon = weapon
							var distance: int = model.distance(origin,player_cell)
							var safe: Array[Vector2i] = []
							for direction in Rules.CARDINALS:
								var cell: Vector2i = origin+direction
								if model.inside(cell) and cell!=player_cell and model.distance(cell,player_cell)<distance and not model.targets().has(cell):
									safe.append(cell)
							if safe.is_empty():
								continue
							if kind == "infantry":
								choice = behavior.decide(model,model.enemies[0],{0:origin})
								verify(choice.kind=="step" and safe.has(choice.cell),"Infantry always chooses safe progress when available")
							else:
								planner.begin(model)
								planner.beat(model,0)
								verify(safe.has(model.enemies[0].cell),"Heavy always chooses safe progress when available")
	model = fixture([["infantry",2,2],["heavy",0,0]])
	model.phase=Rules.Phase.ENEMY
	verify(not model.enemy_step(model.enemies[0],Vector2i(4,2)) and model.enemies[0].ap==2,"Enemy action rejects non-adjacent steps without spending AP")
	model = fixture([["infantry",2,3]])
	model.player_action(Vector2i(2,3))
	verify(model.phase==Rules.Phase.WON,"Victory")
	verify(not model.player_action(Vector2i(1,3)),"Won is terminal")
	model = fixture([["heavy",2,3]])
	model.player.hp=1
	enemy_turn(model)
	verify(model.phase==Rules.Phase.LOST and model.player.hp==0,"Defeat stops further attacks")
	var rng := RandomNumberGenerator.new()
	rng.seed=719
	for trial in range(500):
		model = Rules.new()
		model.reset(trial%3)
		for turn in range(50):
			if model.terminal(): break
			enemy_turn(model)
			if model.terminal(): break
			for action in range(2):
				model.equip(rng.randi_range(0,2))
				var targets: Array = model.targets()
				if not targets.is_empty(): model.player_action(targets[rng.randi_range(0,targets.size()-1)])
			var cells: Array = []
			for enemy in model.enemies:
				verify(not cells.has(enemy.cell) and enemy.cell!=model.player.cell,"No overlapping units")
				verify(model.inside(enemy.cell) and enemy.hp>0,"Enemy state valid")
				cells.append(enemy.cell)
			verify(model.player.ap>=0 and model.player.ap<=2,"AP bounds")
	print("Rules: %d checks, %d failures; 500 random runs" % [checks,failures])
	root.size = Vector2i(1728,1080)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.6).timeout
	verify(scene.model.phase==Rules.Phase.PLAYER and not scene.busy,"Scene finishes enemy animation")
	var inspect_enemy: Dictionary = scene.model.enemies[0]
	scene._act(inspect_enemy.cell)
	verify(scene.selected_enemy_id == int(inspect_enemy.id),"Enemy click selects its inspector")
	scene._equip(1)
	scene._equip(2)
	verify(scene.model.player.ap == 2 and scene.model.weapon == 0,"Repeated weapon previews never spend AP or change equipment")
	verify(not scene.equip_button.disabled,"Preview exposes explicit equip button")
	var equip_click := InputEventMouseButton.new()
	equip_click.position = scene.equip_button.get_global_rect().get_center()
	equip_click.global_position = equip_click.position
	equip_click.button_index = MOUSE_BUTTON_LEFT
	equip_click.pressed = true
	root.push_input(equip_click,true)
	equip_click = equip_click.duplicate()
	equip_click.pressed = false
	root.push_input(equip_click,true)
	verify(scene.model.player.ap == 1 and scene.model.weapon == 2,"Equip button alone confirms switch for one AP")
	scene._equip(2)
	verify(scene.equip_button.disabled,"Already equipped weapon cannot spend AP")
	scene._equip(1)
	verify(scene.model.player.ap == 1 and scene.model.weapon == 2,"Previewing another weapon does not change board actions")
	var click := InputEventMouseButton.new()
	click.position = Vector2(720,600)
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click,true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click,true)
	await create_timer(0.7).timeout
	verify(scene.model.player.cell==Vector2i(1,3) and scene.model.player.ap==2 and scene.model.phase==Rules.Phase.PLAYER,"Board mouse input uses equipped weapon, ignores preview and ends the full AP turn")
	verify(scene.model.weapon==2 and scene.selected_weapon==-1,"Board action never auto-equips the preview")
	scene._enemy_turn()
	scene._start(1)
	await create_timer(0.6).timeout
	verify(scene.model.level==1 and scene.model.round_number==1 and not scene.busy,"Reset cancels old asynchronous phase")
	scene.model = fixture([["infantry",2,2],["infantry",4,4]])
	scene._sync_units(false)
	scene._enemy_turn()
	await create_timer(0.6).timeout
	verify(scene.actors[0].charge_warning and scene.actors[1].charge_warning,"Charge warnings are visible when the player turn begins")
	scene._start(0)
	await create_timer(0.6).timeout
	verify(not scene.actors[0].charge_warning,"Reset clears previous charge warning")
	scene.show_rules=true
	scene._update_controls()
	verify(scene.end_button.disabled and not scene.actors[-1].visible,"Help pauses input and covers actors")
	scene.queue_free()
	await process_frame
	print("TOTAL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
