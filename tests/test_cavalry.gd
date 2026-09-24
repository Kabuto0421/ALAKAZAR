extends SceneTree
const Rules = preload("res://scripts/battle_model.gd")
const Planner = preload("res://scripts/enemy_planner.gd")
func _initialize() -> void:
	var model = Rules.new()
	model.reset(2)
	model.enemies.clear()
	var enemy = model.make_enemy("cavalry",Vector2i(2,0),0)
	model.enemies.append(enemy)
	model.player.cell = Vector2i(3,4)
	var planner = Planner.new()
	planner._cavalry_action(model,enemy)
	assert(enemy.cell == Vector2i(3,2) and enemy.ap == 1)
	enemy.cell = Vector2i(2,5)
	enemy.facing = 2
	enemy.ap = 2
	model.player.cell = Vector2i(3,2)
	planner._cavalry_action(model,enemy)
	assert(enemy.cell == Vector2i(2,5) and enemy.facing == 0 and enemy.ap == 1)
	planner._cavalry_action(model,enemy)
	assert(enemy.cell == Vector2i(3,3) and enemy.ap == 0)
	enemy.cell = Vector2i(2,5)
	enemy.ap = 2
	model.player.cell = Vector2i(3,3)
	var hp: int = model.player.hp
	planner._cavalry_action(model,enemy)
	assert(model.player.hp == hp-1 and enemy.ap == 1)
	assert(not model.enemy_step(enemy,Vector2i(3,7)))
	print("Cavalry: jump priority, 1 AP turn, turn then jump, jump attack passed")
	quit()
