extends SceneTree

const Rules = preload("res://scripts/battle_model.gd")
const Motion = preload("res://scripts/animation/sword_motion.gd")
const Unit = preload("res://scripts/unit_view.gd")
var scene
var checks := 0
var failures := 0

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func fixture(direction: int, lethal: bool = false, last_enemy: bool = false) -> Vector2i:
	for actor in scene.actors.values():
		actor.queue_free()
	scene.actors.clear()
	scene.flashes.clear()
	scene.model.reset(2)
	scene.model.phase = Rules.Phase.PLAYER
	scene.model.weapon = 0
	scene.model.facing = 1
	scene.model.player.cell = Vector2i(2,3)
	scene.model.enemies.clear()
	var target: Vector2i = scene.model.player.cell + Rules.CARDINALS[direction]
	scene.model.enemies.append(scene.model.make_enemy("infantry" if lethal else "heavy",target,0))
	if not last_enemy:
		scene.model.enemies.append(scene.model.make_enemy("infantry",Vector2i(5,0),1))
	scene._sync_units(false)
	scene._update_controls()
	return target

func run() -> void:
	scene = load("res://scripts/battle_view.gd").new()
	root.add_child(scene)
	await create_timer(0.7).timeout
	var geometry: Array = []
	for direction in [1]:
		verify(Motion.frame_at(direction,0.0)==-1,"Animation starts with the exact standing sprite")
		verify(Motion.frame_at(direction,Motion.duration(direction)-0.001)==-1,"Animation ends with the exact standing sprite")
		for frame in range(Motion.COUNTS[direction]):
			var rect := Motion.frame_rect(direction,frame)
			geometry.append({"direction":direction,"frame":frame,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
		var target := fixture(direction)
		scene._act(target)
		verify(scene.model.enemies[0].hp==1 and scene.actors[0].hp==2,"Committed damage is not displayed before contact")
		verify(scene.actors[-1].sword_attack_facing==direction,"Motion follows fixed right-facing orientation")
		scene._act(target)
		verify(scene.model.player.ap==1,"Animation blocks repeated attack input")
		await create_timer(Motion.impact_time(direction)-0.05).timeout
		verify(scene.actors[0].hp==2 and scene.actors[0].flash==0.0 and scene.flashes.is_empty(),"Windup has no early damage feedback")
		await create_timer(0.07).timeout
		verify(scene.actors[0].hp==1 and scene.actors[0].flash>0.0,"HP and hit reaction appear together at contact")
		verify(Motion.frame_at(direction,scene.actors[-1].sword_attack_elapsed)==Motion.IMPACT_FRAMES[direction],"Enemy reacts while the contact pose is on screen")
		verify(scene.busy,"Recovery remains input-locked")
		await create_timer(Motion.duration(direction)-Motion.impact_time(direction)+0.06).timeout
		verify(not scene.busy and scene.actors[-1].sword_attack_elapsed<0.0,"Recovery returns control and standing pose")
		verify(scene.actors[0].hit_elapsed<0.0,"Enemy recoil settles")

	var target := fixture(1,true,true)
	scene._act(target)
	verify(scene.model.terminal() and scene.actors.has(0),"Lethal target stays visible until contact")
	verify(not scene.result_button.visible,"Victory UI does not interrupt the swing")
	await create_timer(Motion.impact_time(1)+0.03).timeout
	verify(not scene.actors.has(0),"Lethal target disappears at contact")
	await create_timer(Motion.duration(1)).timeout
	verify(scene.result_button.visible,"Victory UI appears after recovery")

	target = fixture(1)
	scene._act(target)
	scene._start(0)
	await create_timer(0.8).timeout
	verify(not scene.busy and scene.model.player.ap==2,"Restart cancels pending contact and recovery")
	verify(scene.flashes.all(func(event): return event.kind != "weapon_hit"),"Restart cannot receive an old hit effect")

	target = fixture(1)
	scene.model.player.ap = 1
	scene._act(target)
	await create_timer(Motion.impact_time(1)+0.04).timeout
	verify(scene.model.phase==Rules.Phase.PLAYER,"Last-AP attack does not start enemies before recovery")
	await create_timer(0.95).timeout
	verify(scene.model.phase==Rules.Phase.PLAYER and scene.model.player.ap==2 and not scene.busy,"Enemy turn completes normally after final-AP animation")

	var output := ProjectSettings.globalize_path("res://../animation-review/")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output+"render-geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(geometry,"\t"))
	scene.queue_free()
	await create_timer(0.2).timeout
	print("SWORD PRESENTATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
