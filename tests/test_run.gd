extends SceneTree
const Run = preload("res://scripts/run/run_model.gd")
const Rules = preload("res://scripts/battle_model.gd")
const Planner = preload("res://scripts/enemy_planner.gd")
var checks := 0
var failures := 0

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func fixture() -> RefCounted:
	var model := Rules.new()
	model.reset(2)
	model.phase = Rules.Phase.PLAYER
	model.player.cell = Vector2i(1,2)
	model.enemies.clear()
	model.enemies.append(model.make_enemy("heavy",Vector2i(5,5),0))
	return model

func _initialize() -> void:
	var run := Run.new()
	run.start(42)
	verify(run.state == Run.State.START_WEAPON and run.battle.owned_weapons == [0,1],"Run starts with forward/backward weapons and a separate draft")
	verify(run.offers.size() == 3 and run.offers.all(func(o): return Run.Weapons.is_single(o.value) and o.value > 1),"Three single-tile starting weapons")
	var picked: int = run.offers[1].value
	verify(not run.choose(8) and run.battle.owned_weapons.size()==2,"Invalid draft does not mutate loadout")
	run.choose(1)
	verify(run.state==Run.State.START_FAIRY and run.battle.owned_weapons==[0,1,picked],"Weapon is selected before fairy draft")
	var ids: Array = run.offers.map(func(o: Dictionary): return o.value)
	verify(ids.size()==3 and ids.has("magic_bolt") and ids.has("stealth_fairy") and ids.has("acorn_fairy"),"Initial fairy pool contains exactly the three requested fairies")
	run.choose(ids.find("acorn_fairy"))
	verify(run.state==Run.State.BATTLE and run.battle.fairy_loadout==["acorn_fairy"],"Fairy selection starts combat")
	verify(run.battle.board_size==4 and run.battle.player.cell.x==0 and run.battle.facing==1,"First encounter starts on left, facing right")
	verify(run.battle.enemies.size()==4 and run.battle.enemies.all(func(e): return e.type=="recruit" and e.hp==1 and e.ap==1 and e.cell.x>=2 and e.facing==3),"Four 1HP/1AP infantry start on the right facing left")
	var m := run.battle
	m.phase=Rules.Phase.PLAYER
	m.player.cell=Vector2i(1,1)
	verify(m.targets()==[Vector2i(2,1)],"Forward weapon reaches exactly one right tile")
	verify(m.equip(1) and m.player.ap==2 and m.targets()==[Vector2i(0,1)],"Backward weapon switches for zero AP")
	m.owned_weapons[2] = 3
	m.equip(3)
	verify(m.targets()==[Vector2i(2,0),Vector2i(2,2)],"Forward diagonals are right-up and right-down")
	m.owned_weapons[2] = picked
	verify(not m.turn_to(0) and m.facing==1,"Player cannot rotate")
	m.player.ap=0
	verify(m.equip(0) and m.player.ap==0,"Switching remains free with no AP")
	verify(not m.equip(11),"Unowned weapons cannot be equipped")
	m.player.ap=2
	m.inventory.acorn_fairy=0
	m.fairy_charges[0]=0
	m.enemies.clear()
	m.check_outcome()
	verify(run.finish_battle() and run.state==Run.State.REWARD,"Win opens reward state")
	verify(m.inventory.acorn_fairy==1,"Skills refill immediately after clear")
	verify(run.offers.size()==4 and run.offers.slice(0,2).all(func(o): return o.kind=="weapon") and run.offers.slice(2).all(func(o): return o.kind=="fairy"),"Rewards always contain two weapons and two fairies")
	verify(run.offers.slice(0,2).all(func(o): return Run.Weapons.is_single(o.value)),"Early reward weapons are single-tile")
	var old_weapons := m.owned_weapons.duplicate()
	var new_weapon: int = run.offers[0].value
	run.choose(0)
	verify(run.state==Run.State.REPLACE and m.owned_weapons==old_weapons,"Full weapon loadout waits for replacement without mutating")
	run.cancel_replace()
	verify(run.state==Run.State.REWARD and run.offers[0].value==new_weapon,"Cancel preserves the rolled offers")
	run.choose(0)
	verify(not run.replace(-1),"Invalid replacement is rejected")
	run.replace(2)
	verify(run.state==Run.State.BATTLE and m.owned_weapons.size()==3 and m.owned_weapons[2]==new_weapon,"Replacement keeps exactly three weapons and advances")
	verify(m.board_size==5 and m.enemies.size()==4,"Second encounter uses a 5x5 board")
	for e in m.enemies:
		verify(e.type==("recruit" if (e.cell.x+e.cell.y)%2==0 else "heavy"),"Second encounter has a checkerboard formation")
	m.enemies.clear()
	m.check_outcome()
	run.finish_battle()
	run.choose(2)
	verify(run.stage==2 and m.fairy_loadout.size()==2 and m.board_size==6,"Fairy reward persists into six-by-six encounter")
	verify(m.enemies.size()==7 and m.enemies.filter(func(e): return e.type=="miner").size()==1,"Third encounter preserves the previous second encounter roster")
	verify(m.enemies.all(func(e): return m.inside(e.cell) and e.cell!=m.player.cell),"Rotated third-stage placements stay valid")
	m.enemies.clear()
	m.check_outcome()
	run.finish_battle()
	run.skip_reward()
	verify(run.state==Run.State.FINISHED,"Final reward leads to completion, not a fourth encounter")

	m=fixture()
	m.fairy_loadout.assign(["acorn_fairy","magic_bolt","stealth_fairy"])
	m.refill_fairies()
	verify(not m.use_item("acorn_fairy",Vector2i(4,0)) and m.player.ap==2,"Acorn placement outside weapon range is rejected for free")
	verify(m.use_item("acorn_fairy",Vector2i(2,2)) and m.allies.size()==1 and m.player.ap==1,"Acorn summons a 1AP ally in weapon range")
	verify(m.allies[0].hp==1 and m.allies[0].ap==1 and m.blocked(Vector2i(2,2)),"Summoned fairy occupies its square")
	verify(not m.player_action(Vector2i(2,2)),"Player cannot overlap an ally")
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(2,1),0))
	m.enemies.append(m.make_enemy("recruit",Vector2i(3,2),1))
	m.act_allies()
	verify(m.enemy_at(Vector2i(3,2)).is_empty() and m.enemy_at(Vector2i(2,1)).hp==2,"Acorn prioritizes a kill over damaging a 2HP enemy")
	verify(m.allies[0].ap==0 and m.allies[0].cell==Vector2i(2,2),"Acorn attacks once without moving")
	m.phase=Rules.Phase.ENEMY
	m.enemy_step(m.enemies[0],Vector2i(2,2))
	verify(m.allies.is_empty(),"Enemies can attack and remove the summoned ally")
	m=fixture()
	m.summon_acorn(Vector2i(2,2))
	m.enemies[0].cell=Vector2i(4,2)
	m.act_allies()
	verify(m.allies[0].cell==Vector2i(3,2) and m.enemies[0].hp==2,"Acorn approaches but cannot move and attack with one AP")
	m=fixture()
	m.summon_acorn(Vector2i(2,2))
	m.enemies[0]=m.make_enemy("recruit",Vector2i(2,1),0)
	m.act_allies()
	verify(m.phase==Rules.Phase.WON and m.player.hp==5,"Ally can finish battle before the enemy acts")
	m=fixture()
	m.fairy_loadout.assign(["magic_bolt","magic_bolt","acorn_fairy"])
	m.refill_fairies()
	verify(m.inventory.magic_bolt==2 and m.fairy_charges==[1,1,1],"Duplicate fairies occupy separate slots with separate charges")
	verify(m.use_item("magic_bolt",Vector2i(2,2),Vector2i.UP,1),"Second identical fairy slot is usable")
	verify(m.fairy_charges==[1,0,1] and not m.use_item("magic_bolt",Vector2i(2,2),Vector2i.UP,1),"Spent slot cannot consume another slot's charge")
	verify(m.add_item("warp_fairy")==0,"Fourth fairy is rejected")
	m.reset(1,true)
	verify(m.fairy_charges==[1,1,1] and m.allies.is_empty(),"Next encounter refills skills and clears summons")
	run=Run.new()
	run.start(8)
	run.choose(0)
	run.choose(0)
	run.battle.add_item("acorn_fairy")
	run.battle.add_item("warp_fairy")
	run.battle.enemies.clear()
	run.battle.check_outcome()
	run.finish_battle()
	var incoming: String = run.offers[2].value
	run.choose(2)
	verify(run.state==Run.State.REPLACE,"Full fairy loadout requires replacement")
	run.replace(0)
	verify(run.battle.fairy_loadout.size()==3 and run.battle.fairy_loadout[0]==incoming,"Fairy replacement persists and preserves cap")
	# Seeded random battles exercise collisions and bounded turns across all board sizes.
	var rng := RandomNumberGenerator.new()
	rng.seed=726
	for trial in range(60):
		m=fixture()
		m.reset(trial%3)
		m.fairy_loadout.assign(["acorn_fairy","magic_bolt","stealth_fairy"])
		m.refill_fairies()
		var planner := Planner.new()
		for turn in range(20):
			if m.terminal(): break
			m.act_allies()
			if m.terminal(): break
			planner.begin(m)
			planner.beat(m,0)
			planner.beat(m,1)
			planner.finish(m)
			if m.terminal(): break
			for action in range(2):
				m.equip(m.owned_weapons[rng.randi_range(0,m.owned_weapons.size()-1)])
				var id: String = m.fairy_loadout[rng.randi_range(0,2)]
				var cells: Array = m.item_targets(id)
				if cells.is_empty() or not m.use_item(id,cells[rng.randi_range(0,cells.size()-1)],Vector2i.LEFT):
					cells=m.targets()
					if not cells.is_empty(): m.player_action(cells[rng.randi_range(0,cells.size()-1)])
				if m.terminal(): break
			var occupied: Array = [m.player.cell]
			for unit in m.enemies+m.allies:
				verify(m.inside(unit.cell) and not occupied.has(unit.cell),"Units stay inside board without overlap")
				occupied.append(unit.cell)
			verify(m.player.ap>=0 and m.facing==1,"AP and fixed facing remain valid")
			verify(m.fairy_charges.all(func(c): return c>=0),"Skill charges never go negative")
	_new_fairies()
	print("RUN: %d checks, %d failures; 60 seeded battles" % [checks,failures])
	quit(1 if failures else 0)


func _new_fairies() -> void:
	var planner := Planner.new()
	# Wall spirit: a full obstacle for the placement turn and the next two.
	var m := fixture()
	m.fairy_loadout.assign(["wall_fairy","cannon_fairy","slash_fairy"])
	m.refill_fairies()
	m.weapon = 0
	verify(m.use_item("wall_fairy",Vector2i(2,2)) and m.blocked(Vector2i(2,2)),"Wall spirit blocks its tile")
	verify(not m.player_action(Vector2i(2,2)),"Player cannot walk into a wall")
	for turn in range(3):
		verify(m.walls.has(Vector2i(2,2)),"Wall stands on player turn %d" % (turn+1))
		planner.begin(m)
		planner.finish(m)
	verify(not m.walls.has(Vector2i(2,2)),"Wall crumbles before the fourth player turn")

	# Lance cannon fires along its set direction when its tile is attacked.
	m = fixture()
	m.fairy_loadout.assign(["cannon_fairy"])
	m.refill_fairies()
	m.weapon = 0
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(2,0),0))
	m.enemies.append(m.make_enemy("recruit",Vector2i(2,4),1))
	verify(m.use_item("cannon_fairy",Vector2i(2,2),Vector2i.UP) and m.blocked(Vector2i(2,2)),"Lance cannon occupies its tile")
	verify(m.player_action(Vector2i(2,2)) and m.player.ap == 0,"Attacking the cannon costs 1 AP")
	verify(m.enemy_at(Vector2i(2,0)).hp == 1 and not m.enemy_at(Vector2i(2,4)).is_empty(),"Shot hits only its line")
	verify(not m.cannon_at(Vector2i(2,2)).is_empty(),"Lance cannon stays after firing")

	# Vane cannon rotates clockwise after each shot.
	m = fixture()
	m.place_cannon(Vector2i(2,2),Vector2i.UP,"vane")
	m.fire_cannon(m.cannon_at(Vector2i(2,2)))
	verify(m.cannon_at(Vector2i(2,2)).dir == Vector2i.RIGHT,"Vane cannon turns right after firing")

	# Firework bursts on all eight neighbours, vanishes, and sets off cannons it reaches.
	m = fixture()
	m.enemies.clear()
	m.enemies.append(m.make_enemy("recruit",Vector2i(1,1),0))
	m.enemies.append(m.make_enemy("heavy",Vector2i(3,3),1))
	m.enemies.append(m.make_enemy("heavy",Vector2i(5,2),2))
	m.place_cannon(Vector2i(2,2),Vector2i.ZERO,"firework")
	m.place_cannon(Vector2i(3,2),Vector2i.RIGHT,"lance")
	m.fire_cannon(m.cannon_at(Vector2i(2,2)))
	verify(m.enemy_at(Vector2i(1,1)).is_empty() and m.enemy_at(Vector2i(3,3)).hp == 1,"Firework hits every neighbour")
	verify(m.cannon_at(Vector2i(2,2)).is_empty(),"Firework is spent")
	verify(m.enemy_at(Vector2i(5,2)).hp == 1,"Burst sets off the neighbouring lance cannon")

	# Slash spirit: a three-wide wave, each lane stops at blockers.
	m = fixture()
	m.enemies.clear()
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,1),0))
	m.enemies.append(m.make_enemy("recruit",Vector2i(5,2),1))
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,3),2))
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,4),3))
	m.walls[Vector2i(3,3)] = 2
	m.slash(Vector2i(2,2),Vector2i.RIGHT)
	verify(m.enemy_at(Vector2i(4,1)).is_empty() and m.enemy_at(Vector2i(5,2)).is_empty(),"Slash hits the centre and side lanes")
	verify(not m.enemy_at(Vector2i(4,3)).is_empty(),"A wall stops its lane")
	verify(not m.enemy_at(Vector2i(4,4)).is_empty(),"Slash is only three lanes wide")
	verify(m.directional_preview("slash_fairy",Vector2i(2,2),Vector2i.RIGHT).size() == 6,"Preview shows the three lanes, cut by the wall")
