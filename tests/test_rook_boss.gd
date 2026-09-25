extends SceneTree

const Boss = preload("res://scripts/boss/rook_boss_model.gd")
var checks := 0
var failures := 0

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+message)

func fresh(player_cell: Vector2i, origin: Vector2i) -> RefCounted:
	var model := Boss.new()
	model.reset()
	model.player.cell = player_cell
	model.boss.origin = origin
	return model

func _initialize() -> void:
	# Opening turn: dash to put the player in the lane, then brace toward them.
	var m := fresh(Vector2i(0,5), Vector2i(2,0))
	m.boss_turn()
	verify(m.boss.origin == Vector2i(0,0), "Boss dashes sideways to align its lane")
	verify(m.boss.state == Boss.State.BRACE and m.boss.charge_dir == Vector2i.DOWN, "Boss braces toward the player")
	verify(m.charge_lane().has(Vector2i(0,5)) and m.charge_lane().has(Vector2i(1,5)), "Telegraph covers the 2-wide lane to the wall")
	verify(m.phase == Boss.Phase.PLAYER and m.player.ap == 2, "Player gets 2 AP after the boss turn")

	# Staying in the lane: the charge stops at the player and deals 2.
	m.end_player_turn()
	m.boss_turn()
	verify(m.player.hp == 3, "Charge hit deals 2 damage")
	verify(m.boss.origin == Vector2i(0,3) and m.boss.state == Boss.State.IDLE, "Charge stops in front of the player, not stunned")

	# Dodging out of the lane: the charge hits the wall and stuns.
	m = fresh(Vector2i(0,5), Vector2i(2,0))
	m.boss_turn()
	m.player.cell = Vector2i(3,5)
	m.end_player_turn()
	m.boss_turn()
	verify(m.player.hp == 5, "Dodged charge deals no damage")
	verify(m.boss.origin == Vector2i(0,4) and m.boss.state == Boss.State.STUN, "Charge runs to the wall and stuns")
	# Hitting the stunned boss deals double damage.
	m.player.cell = Vector2i(2,5)
	m.facing = 0
	m.weapon = 0
	var hp_before: int = m.boss.hp
	verify(m.player_action(Vector2i(1,4)), "Gold can hit the boss from the side-front")
	verify(m.boss.hp == hp_before - Boss.STUNNED_HIT_DAMAGE, "Stunned boss takes 2 per hit")
	m.end_player_turn()
	m.boss_turn()
	verify(m.boss.state == Boss.State.IDLE and m.player.hp == 5, "Boss recovers instead of acting")

	# 4-direction melee reaches orthogonal neighbours only; diagonal corners are safe.
	m = fresh(Vector2i(4,2), Vector2i(2,2))
	m.boss_turn()
	verify(m.player.hp == 4 and m.last_boss_action.kind == "melee", "Adjacent player takes a melee hit")
	m = fresh(Vector2i(4,1), Vector2i(2,2))
	verify(not m.melee_cells().has(Vector2i(4,1)), "Diagonal corner is outside melee reach")
	m.boss_turn()
	verify(m.player.hp == 5 and m.boss.state == Boss.State.BRACE, "From a corner the boss re-aligns instead of hitting")

	# Normal hits deal 1; the boss dies at 0.
	m = fresh(Vector2i(2,5), Vector2i(2,2))
	m.phase = Boss.Phase.PLAYER
	m.player.ap = 2
	m.facing = 0
	m.weapon = 1
	m.player.cell = Vector2i(2,4)
	m.boss.hp = 2
	verify(m.player_action(Vector2i(2,3)), "Silver attacks the boss straight ahead")
	verify(m.boss.hp == 1, "Normal hit deals 1")
	verify(m.player_action(Vector2i(3,3)), "Silver attacks diagonally forward")
	verify(m.phase == Boss.Phase.WON, "Boss defeated at 0 HP")

	# Losing.
	m = fresh(Vector2i(0,5), Vector2i(0,0))
	m.player.hp = 2
	m.boss.state = Boss.State.BRACE
	m.boss.charge_dir = Vector2i.DOWN
	m.boss_turn()
	verify(m.phase == Boss.Phase.LOST, "Charge at 2 HP defeats the player")

	print("ROOK BOSS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
