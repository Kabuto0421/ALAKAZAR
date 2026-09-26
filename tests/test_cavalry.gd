extends SceneTree
const Rules = preload("res://scripts/battle_model.gd")
const Planner = preload("res://scripts/enemy_planner.gd")
func _initialize() -> void:
	var model = Rules.new()
	model.reset(2)
	model.enemies.clear()
	var enemy = model.make_enemy("cavalry",Vector2i(5,2),0)
	model.enemies.append(enemy)
	model.player.cell = Vector2i(0,3)
	var planner = Planner.new()
	planner._cavalry_action(model,enemy)
	assert(enemy.cell == Vector2i(3,3) and enemy.ap == 1 and enemy.facing == 3)
	enemy.cell = Vector2i(0,5)
	enemy.ap = 2
	model.player.cell = Vector2i(3,2)
	planner._cavalry_action(model,enemy)
	assert(enemy.facing == 3 and enemy.ap == 1 and enemy.cell != Vector2i(0,5))
	enemy.cell = Vector2i(5,2)
	enemy.ap = 2
	model.player.cell = Vector2i(3,3)
	var hp: int = model.player.hp
	planner._cavalry_action(model,enemy)
	assert(model.player.hp == hp-1 and enemy.ap == 1 and enemy.facing == 3)
	assert(not model.enemy_step(enemy,Vector2i(3,7)))
	assert(not model.turn_enemy(enemy,0))
	print("Cavalry: jump priority, fixed facing, cardinal fallback, jump attack passed")
	quit()
