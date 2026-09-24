extends SceneTree

const Rules = preload("res://scripts/battle_model.gd")
var failures := 0
var checks := 0
var scene

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func fixture(weapon: int, attack: bool) -> Vector2i:
	scene.model.reset()
	scene.model.phase = Rules.Phase.PLAYER
	scene.model.weapon = weapon
	scene.model.player.cell = Vector2i(2,4)
	scene.model.enemies.clear()
	var target := Vector2i(3,2) if weapon == 2 else Vector2i(2,3)
	scene.model.enemies.append(scene.model.make_enemy("heavy",target if attack else Vector2i(5,0),0))
	scene._sync_units(false)
	scene._update_controls()
	return target

func run() -> void:
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.7).timeout
	for weapon in range(3):
		for attack in [false,true]:
			var target := fixture(weapon,attack)
			scene._act(target)
			var uses_sword_animation: bool = weapon == 1 and attack
			verify(scene.weapon_effects.get_child_count()==(0 if uses_sword_animation else 1),"Action uses its matching weapon presentation")
			if not uses_sword_animation:
				var effect = scene.weapon_effects.get_child(0)
				verify(effect.weapon==weapon and effect.attacking==attack,"Effect matches equipped weapon and action")
			else:
				verify(scene.actors[-1].sword_attack_elapsed>=0.0,"Sword attack starts the directional player animation")
			verify(scene.model.player.ap==1,"Effect does not add an AP cost")
			scene._act(target)
			verify(scene.weapon_effects.get_child_count()==(0 if uses_sword_animation else 1) and scene.model.player.ap==1,"Repeated input during animation cannot duplicate action")
			if attack:
				verify(scene.model.enemies[0].hp==1 and scene.model.player.cell==Vector2i(2,4),"Attack still deals one damage without moving")
			else:
				verify(scene.model.player.cell==target,"Movement resolves its destination")
			var wait_time: float = scene.actors[-1].sword_attack_duration() + 0.1 if uses_sword_animation else 0.65
			await create_timer(wait_time).timeout
			verify(not scene.busy and scene.weapon_effects.get_child_count()==0,"Effect finishes and frees its node")
			verify(absf(scene.actors[-1].hop_height)<0.01,"Player has landed after movement")
			if uses_sword_animation:
				verify(scene.actors[-1].sword_attack_elapsed<0.0,"Sword attack animation returns to the standing sprite")
	for direction in range(4):
		scene.model.reset()
		scene.model.phase = Rules.Phase.PLAYER
		scene.model.weapon = 1
		scene.model.facing = direction
		scene._sync_units(false)
		scene._finish_player_action(true,{"origin":scene.model.player.cell,"destination":scene.model.player.cell+Vector2i.UP,"attacking":true,"weapon":1})
		verify(scene.actors[-1].sword_attack_facing==direction,"Sword attack uses the player's current facing")
		await create_timer(scene.actors[-1].sword_attack_duration() + 0.1).timeout
	fixture(0,false)
	scene._act(Vector2i(5,5))
	verify(scene.weapon_effects.get_child_count()==0 and scene.model.player.ap==2,"Invalid move is free and has no effect")
	scene._select_item("warp_fairy")
	scene._act(Vector2i(4,4))
	verify(scene.weapon_effects.get_child_count()==0,"Item use keeps its own effects")
	await create_timer(0.3).timeout
	var target := fixture(2,false)
	scene._act(target)
	scene._start(0)
	verify(scene.weapon_effects.get_child_count()==0,"Restart immediately clears effects")
	await create_timer(0.7).timeout
	verify(not scene.busy and scene.model.round_number==1,"Cancelled animation cannot alter the new turn")
	scene.queue_free()
	await process_frame
	print("WEAPON FX: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
