extends SceneTree

const Rules = preload("res://scripts/battle_model.gd")
var checks := 0
var failures := 0

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+message)

func fixture() -> RefCounted:
	var model := Rules.new()
	model.reset()
	model.phase = Rules.Phase.PLAYER
	model.player.cell = Vector2i(2,3)
	model.enemies.clear()
	model.enemies.append(model.make_enemy("heavy",Vector2i(0,0),0))
	return model

func same_cells(actual: Array, expected: Array) -> bool:
	return actual.size()==expected.size() and expected.all(func(cell): return actual.has(cell))

func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model := fixture()
	verify(model.facing==0,"New battle starts facing up")
	verify(not model.turn_to(0) and model.player.ap==2,"Same direction is free and unchanged")
	verify(not model.turn_to(-1) and not model.turn_to(4) and model.player.ap==2,"Invalid direction never spends AP")
	var previous_targets: Array = model.targets()
	model.targets_for_facing(1)
	verify(model.facing==0 and model.player.ap==2 and model.targets()==previous_targets,"Preview is read-only")
	verify(model.turn_to(1) and model.player.ap==1,"Turning right costs one AP")
	verify(same_cells(model.targets(),[Vector2i(3,2),Vector2i(3,3),Vector2i(3,4),Vector2i(2,2),Vector2i(2,4),Vector2i(1,3)]),"Gold range rotates right")
	model.weapon = 1
	verify(same_cells(model.targets(),[Vector2i(3,2),Vector2i(3,3),Vector2i(3,4),Vector2i(1,2),Vector2i(1,4)]),"Silver range rotates right")
	model.weapon = 2
	var knight_targets := [
		[Vector2i(1,1),Vector2i(3,1)],
		[Vector2i(4,2),Vector2i(4,4)],
		[Vector2i(1,5),Vector2i(3,5)],
		[Vector2i(0,2),Vector2i(0,4)],
	]
	for facing in range(4):
		verify(same_cells(model.targets_for_facing(facing),knight_targets[facing]),"Knight jumps two forward in each cardinal direction")
	verify(same_cells(model.item_targets("magic_bolt"),knight_targets[1]),"Magic bolt placement uses current facing")
	verify(same_cells(model.item_targets("stealth_fairy"),knight_targets[1]),"Stealth placement uses current facing")
	model.player.ap = 0
	verify(not model.turn_to(2) and model.facing==1,"Cannot turn without AP")
	model.player.ap = 2
	model.phase = Rules.Phase.ENEMY
	verify(not model.turn_to(2) and model.player.ap==2,"Cannot turn during enemy phase")
	model.phase = Rules.Phase.PLAYER
	model.weapon = 0
	verify(model.player_action(Vector2i(1,3)) and model.facing==1,"Moving backward preserves facing")
	model.enemies.append(model.make_enemy("heavy",Vector2i(2,3),1))
	verify(model.player_action(Vector2i(2,3)) and model.facing==1,"Attacking preserves facing")
	model.reset()
	verify(model.facing==0,"Reset restores up direction")
	root.size = Vector2i(1728,1080)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.7).timeout
	scene.model = fixture()
	scene._sync_units(false)
	scene._update_controls()
	click(scene.facing_button)
	verify(scene.facing_preview==0 and scene.facing_confirm_button.disabled,"Facing button opens current direction without a charge")
	click(scene.direction_buttons[1])
	click(scene.direction_buttons[2])
	click(scene.direction_buttons[1])
	verify(scene.facing_preview==1 and scene.model.facing==0 and scene.model.player.ap==2,"Direction buttons only preview")
	scene._act(Vector2i(3,3))
	verify(scene.model.player.ap==2 and scene.model.player.cell==Vector2i(2,3),"Board cannot act on unconfirmed preview")
	click(scene.cancel_button)
	verify(scene.facing_preview==-1 and scene.model.facing==0 and scene.model.player.ap==2,"Cancel is free")
	scene._act(scene.model.player.cell)
	verify(scene.facing_preview==0,"Clicking player opens facing selection")
	click(scene.direction_buttons[1])
	click(scene.facing_confirm_button)
	verify(scene.model.facing==1 and scene.model.player.ap==1 and scene.actors[-1].facing==1,"Confirmation alone spends AP and changes sprite")
	await create_timer(0.2).timeout
	scene._act(Vector2i(1,3))
	await create_timer(0.8).timeout
	verify(scene.model.facing==1 and scene.actors[-1].facing==1 and scene.model.player.ap==2,"Movement and automatic enemy turn preserve paid facing")
	scene.model = fixture()
	scene.model.player.ap = 1
	scene._sync_units(false)
	scene._update_controls()
	click(scene.facing_button)
	click(scene.direction_buttons[3])
	click(scene.facing_confirm_button)
	await create_timer(0.8).timeout
	verify(scene.model.facing==3 and scene.model.phase==Rules.Phase.PLAYER and scene.model.player.ap==2 and not scene.busy,"Last AP rotation completes the enemy turn")
	click(scene.facing_button)
	click(scene.direction_buttons[2])
	scene._select_item("magic_bolt")
	verify(scene.facing_preview==-1 and scene.selected_item=="magic_bolt","Item selection exits facing mode")
	scene._cancel_item()
	click(scene.facing_button)
	scene._equip(2)
	verify(scene.facing_preview==-1 and scene.selected_weapon==2,"Weapon preview exits facing mode")
	scene._toggle_facing()
	scene._start(0)
	await create_timer(0.7).timeout
	verify(scene.facing_preview==-1 and scene.model.facing==0,"Restart clears facing preview and direction")
	scene.queue_free()
	await process_frame
	print("FACING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
