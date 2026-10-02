extends SceneTree
const Rules = preload("res://scripts/battle_model.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	load("res://scripts/battle_view.gd").help_seen = true
	root.size = Vector2i(1728, 1080)
	var m = Rules.new()
	m.boss2_variant = 1
	m.reset(Rules.BOSS2_LEVEL)
	m.phase = Rules.Phase.PLAYER
	var v = load("res://scripts/battle_view.gd").new()
	v.managed_run = true
	v.model = m
	root.add_child(v)
	for i in 8:
		await process_frame
	m.round_number = 3
	m.player.cell = Vector2i(4, 3)
	m.storm.wind = Vector2i.RIGHT
	m._storm_thunder()
	v._sync_units(false)
	v.selected_enemy_id = int(m.storm_shark().id)
	for i in 14:
		await process_frame
	root.get_texture().get_image().save_png("res://tools/_s1.png")
	# dive
	var s = m.storm_shark()
	m.shark_dive(s)
	m.storm.marks = []
	v._sync_units(false)
	for i in 50:
		await process_frame
	root.get_texture().get_image().save_png("res://tools/_s2.png")
	quit()
