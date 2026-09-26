extends SceneTree

# Run with a rendering driver and --fixed-fps 60. User argument is the output label.
const Rules = preload("res://scripts/battle_model.gd")
var scene
var samples: Array = []

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1728,1080)
	var args := OS.get_cmdline_user_args()
	var label := args[0] if not args.is_empty() else "after"
	var only_direction: int = int(args[1]) if args.size() > 1 else -1
	var output := ProjectSettings.globalize_path("res://../animation-review/" + label + "/")
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scripts/battle_view.gd").new()
	root.add_child(scene)
	await create_timer(0.7).timeout
	for direction in [1]:
		if only_direction >= 0 and direction != only_direction:
			continue
		var folder := output + str(direction) + "/"
		DirAccess.make_dir_recursive_absolute(folder)
		for actor in scene.actors.values():
			actor.queue_free()
		scene.actors.clear()
		scene.model.reset(2)
		scene.model.phase = Rules.Phase.PLAYER
		scene.model.weapon = 0
		scene.model.facing = direction
		scene.model.player.cell = Vector2i(2,3)
		scene.model.enemies.clear()
		var target: Vector2i = scene.model.player.cell + Rules.CARDINALS[direction]
		scene.model.enemies.append(scene.model.make_enemy("heavy",target,0))
		scene.model.enemies.append(scene.model.make_enemy("infantry",Vector2i(5,0),1))
		scene.flashes.clear()
		scene._sync_units(false)
		scene._update_controls()
		for tick in range(84):
			if tick == 8:
				scene._act(target)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image().get_region(Rect2i(624,408,384,384))
			image.save_png(folder + "%03d.png" % tick)
			var actor = scene.actors[-1]
			samples.append({"direction":direction,"tick":tick,"elapsed":actor.sword_attack_elapsed,"enemy_hp":scene.actors[0].hp if scene.actors.has(0) else -1,"flash":scene.actors[0].flash if scene.actors.has(0) else 0,"busy":scene.busy,"frame":actor.SwordMotion.frame_at(direction,actor.sword_attack_elapsed) if actor.sword_attack_elapsed >= 0.0 else -1})
	var file := FileAccess.open(output + "samples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"\t"))
	print("CAPTURE: " + output)
	quit()
