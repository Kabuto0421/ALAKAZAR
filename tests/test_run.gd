extends SceneTree
const Run = preload("res://scripts/run/run_model.gd")
const Rules = preload("res://scripts/battle_model.gd")
const Planner = preload("res://scripts/enemy_planner.gd")
const DirectionSheet = preload("res://scripts/items/direction_sheet.gd")
const ThreatPreview = preload("res://scripts/threat_preview.gd")
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
	run.boss_choice = 0
	verify(run.state == Run.State.START_WEAPON and run.battle.owned_weapons == [0,1],"Run starts with forward/backward weapons and a separate draft")
	verify(run.offers.size() == 3 and run.offers.all(func(o): return Run.Weapons.is_early(o.value) and Run.Weapons.goes_up_and_down(o.value)),"Three early starting weapons that all go both up and down")
	var rolled: Array = run.offers.map(func(o): return o.value)
	run.choose(0)
	run.back_to_weapon()
	verify(run.state==Run.State.START_WEAPON and run.battle.owned_weapons==[0,1] and run.offers.map(func(o): return o.value)==rolled,"Going back to the weapon pick keeps the same offers")
	var picked: int = run.offers[1].value
	verify(not run.choose(8) and run.battle.owned_weapons.size()==2,"Invalid draft does not mutate loadout")
	run.choose(1)
	verify(run.state==Run.State.START_FAIRY and run.battle.owned_weapons==[0,1,picked],"Weapon is selected before fairy draft")
	var ids: Array = run.offers.map(func(o: Dictionary): return o.value)
	run.back_to_weapon()
	run.choose(1)
	verify(run.offers.map(func(o: Dictionary): return o.value)==ids and run.battle.owned_weapons==[0,1,picked],"Fairy offers also stay the same after going back")
	verify(ids.size()==3 and ids.has("magic_bolt") and ids.has("stealth_fairy") and ids.has("acorn_fairy"),"Initial fairy pool contains exactly the three requested fairies")
	run.choose(ids.find("acorn_fairy"))
	verify(run.state==Run.State.BATTLE and run.battle.fairy_loadout==["acorn_fairy"],"Fairy selection starts combat")
	verify(run.battle.board_size==4 and run.battle.player.cell.x==0 and run.battle.facing==1,"First encounter starts on left, facing right")
	verify(run.battle.phase==Rules.Phase.PLAYER and run.battle.player.ap==2 and run.battle.round_number==1,"The player moves first")
	var first_types: Array = run.battle.enemies.map(func(e): return e.type)
	verify(first_types.has("infantry") and first_types.has("heavy") and not first_types.has("cavalry"),"First fight mixes AP2 infantry and a heavy, no cavalry yet")
	verify(run.battle.enemies.all(func(e): return e.cell.x>=2 and e.facing==3 and Rules.TYPES[e.type].ap==e.ap),"Enemies start on the right facing left with their full AP")
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
	verify(run.offers.slice(0,2).all(func(o): return Run.Weapons.is_quirky(o.value) and Run.Weapons.offsets(o.value).size() < 4),"Early reward weapons are odd two-tile weapons, weaker than a cross")
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
	verify(m.board_size==5 and m.enemies.size()==5,"Second encounter uses a 5x5 board")
	verify(m.enemies.filter(func(e): return e.type=="miner").size()==1 and m.enemies.filter(func(e): return e.type=="cavalry").is_empty(),"Second encounter adds a miner but still no cavalry")
	verify(m.enemies.all(func(e): return not e.type in Rules.RANGED),"Early fights have no javelins or archers")
	m.enemies.clear()
	m.check_outcome()
	run.finish_battle()
	run.choose(2)
	verify(run.stage==2 and m.fairy_loadout.size()==2 and m.board_size==6,"Fairy reward persists into six-by-six encounter")
	verify(m.enemies.size()==6 and m.enemies.filter(func(e): return e.type=="heavy").size()==2 and m.enemies.filter(func(e): return e.type=="infantry").size()==2,"Third encounter pairs two heavies with AP2 infantry")
	verify(m.enemies.filter(func(e): return e.type=="cavalry").size()==1,"Cavalry first appears in the third fight")
	verify(m.enemies.all(func(e): return not e.type in Rules.RANGED),"The third fight has no ranged soldiers either")
	verify(m.enemies.all(func(e): return m.inside(e.cell) and e.cell!=m.player.cell),"Rotated third-stage placements stay valid")
	m.player.hp = 2
	m.enemies.clear()
	m.check_outcome()
	run.finish_battle()
	verify(m.start_hp == 2,"HP carries over after a win")
	run.skip_reward()
	verify(run.state==Run.State.CAMP,"The third fight's reward leads to the camp")
	verify(run.camp_forge() and run.state==Run.State.CAMP_FORGE and run.offers.size()==3,"Forging lists the owned weapons")
	run.camp_back()
	verify(run.state==Run.State.CAMP,"Forging can be cancelled")
	verify(run.camp_rest() and m.start_hp == 4,"Resting heals 2")
	verify(run.state==Run.State.BATTLE and m.level==Rules.BOSS_LEVEL and m.board_size==7,"The boss fight follows the camp on a 7x7 board")
	verify(m.player.hp == 4,"The boss fight starts with the carried HP")
	verify(m.enemies.size()==3 and m.enemies.all(func(e): return e.type=="horse" and e.hp==2 and e.ap==2),"Three 2HP horses")
	verify(m.enemy_offsets(m.enemies[0]).size()==6,"Horses jump like cavalry")
	m.enemies.clear()
	m.check_outcome()
	verify(run.finish_battle() and run.state==Run.State.REWARD,"Beating the boss opens a reward")
	verify(run.offers.slice(0,2).any(func(o): return Run.Weapons.is_mid(o.value)),"After the boss a hammer or bow is offered")
	run.skip_reward()
	verify(run.state==Run.State.BATTLE and m.level==4 and m.board_size==6,"Mid-game fight 1 follows the boss")
	var mid_types: Array = m.enemies.map(func(e): return e.type)
	verify(mid_types.has("javelin"),"Javelin throwers appear in the mid game")
	m.enemies.clear()
	m.check_outcome()
	run.finish_battle()
	run.skip_reward()
	verify(m.level==5 and m.enemies.any(func(e): return e.type=="archer"),"Archers appear in mid-game fight 2")
	m.enemies.clear()
	m.check_outcome()
	run.finish_battle()
	run.skip_reward()
	verify(m.level==6 and m.board_size==7 and m.enemies.filter(func(e): return e.type=="archer").size()==2,"Mid-game fight 3 is 7x7 with two archers")
	verify(m.enemies.all(func(e): return m.inside(e.cell) and e.cell!=m.player.cell),"Mid-game placements are valid")
	m.enemies.clear()
	m.check_outcome()
	verify(run.finish_battle() and run.state==Run.State.REWARD,"The last mid-game fight gives a reward")
	run.skip_reward()
	verify(run.state==Run.State.CAMP,"A mid-game camp follows")
	run.camp_rest()
	verify(run.state==Run.State.BATTLE and m.level==Rules.BOSS2_LEVEL and m.board_size==6 and m.enemies.size()==1 and m.enemies[0].type=="slot","Rotorick waits after the mid-game camp")
	m.enemies.clear()
	m.check_outcome()
	verify(run.finish_battle() and run.state==Run.State.FINISHED,"Beating Rotorick completes the expedition")

	# Forging adds 1 damage to the chosen weapon.
	run = Run.new()
	run.start(3)
	run.choose(0)
	run.choose(0)
	run.stage = Run.LAST_NORMAL_STAGE
	run.state = Run.State.CAMP
	run.camp_forge()
	var forged: int = run.battle.owned_weapons[0]
	verify(run.camp_forge_weapon(0) and run.battle.weapon_power[forged]==1,"Forging raises the chosen weapon's power")
	m = run.battle
	m.equip(forged)
	m.enemies.clear()
	var target: Vector2i = m.player.cell + m.weapon_offsets(forged)[0]
	var tough: Dictionary = m.make_enemy("heavy",target,0)
	m.enemies.append(tough)
	m.enemies.append(m.make_enemy("heavy",Vector2i(6,6),1))
	verify(m.player_action(target) and tough.hp<=0,"A forged weapon deals 2 damage")

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
	_threats_and_weapons()
	_ranged_soldiers()
	_mid_weapons()
	_place_on_enemies()
	_rook_and_prison()
	_rotorick()
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

	# Direction sheets: 2x2 square, top-left up, top-right right, bottom-left down, bottom-right left.
	var sheet := ImageTexture.create_from_image(Image.create(64,64,false,Image.FORMAT_RGBA8))
	verify(DirectionSheet.region(sheet,Vector2i.UP) == Rect2(0,0,32,32) and DirectionSheet.region(sheet,Vector2i.RIGHT) == Rect2(32,0,32,32),"Top row holds up and right frames")
	verify(DirectionSheet.region(sheet,Vector2i.DOWN) == Rect2(0,32,32,32) and DirectionSheet.region(sheet,Vector2i.LEFT) == Rect2(32,32,32,32),"Bottom row holds down and left frames")
	verify(DirectionSheet.path_for("cannon_fairy") == "res://assets/sprites/spirits/cannon_fairy_directions.png","Sheet path follows the fairy id")

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
	# The burst also hits the player and allies standing next to it.
	m = fixture()
	m.fairy_loadout.assign(["firework_fairy"])
	m.refill_fairies()
	m.weapon = 0
	m.summon_acorn(Vector2i(2,3))
	verify(m.use_item("firework_fairy",Vector2i(2,2)),"Firework battery is placed in weapon range")
	verify(m.player_action(Vector2i(2,2)) and m.player.hp == 4,"Setting it off from the next tile hurts the player")
	verify(m.allies.is_empty(),"The burst also hits allies")

	# Slash spirit: only the three tiles directly in front.
	m = fixture()
	m.fairy_loadout.assign(["slash_fairy"])
	m.refill_fairies()
	m.weapon = 0
	m.enemies.clear()
	m.enemies.append(m.make_enemy("recruit",Vector2i(3,1),0))
	m.enemies.append(m.make_enemy("heavy",Vector2i(3,3),1))
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,2),2))
	verify(m.use_item("slash_fairy",Vector2i(2,2),Vector2i.RIGHT),"Slash spirit is placed in weapon range")
	verify(m.enemy_at(Vector2i(3,1)).is_empty() and m.enemy_at(Vector2i(3,3)).hp == 1,"Slash hits the three tiles in front")
	verify(not m.enemy_at(Vector2i(4,2)).is_empty(),"Slash does not reach beyond the front row")
	verify(m.directional_preview("slash_fairy",Vector2i(2,2),Vector2i.RIGHT) == [Vector2i(3,1),Vector2i(3,2),Vector2i(3,3)],"Slash preview is the front row")

	# Flying slash (class-up): a three-wide wave, each lane stops at blockers.
	m = fixture()
	m.enemies.clear()
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,1),0))
	m.enemies.append(m.make_enemy("recruit",Vector2i(5,2),1))
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,3),2))
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,4),3))
	m.walls[Vector2i(3,3)] = 2
	m.slash(Vector2i(2,2),Vector2i.RIGHT)
	verify(m.enemy_at(Vector2i(4,1)).is_empty() and m.enemy_at(Vector2i(5,2)).is_empty(),"Flying slash hits the centre and side lanes")
	verify(not m.enemy_at(Vector2i(4,3)).is_empty(),"A wall stops a flying slash lane")
	verify(not m.enemy_at(Vector2i(4,4)).is_empty(),"Flying slash is only three lanes wide")
	verify(m.directional_preview("flying_slash",Vector2i(2,2),Vector2i.RIGHT).size() == 6,"Flying slash preview shows the three lanes, cut by the wall")
	verify(not Run.new().reward_fairy_pool.has("flying_slash") and m.item_definition("flying_slash") != null,"Flying slash is listed but not yet offered as a reward")

func _threats_and_weapons() -> void:
	# "!" marks: only enemies that would really hit a player who stays put.
	var m := fixture()
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(2,2),0))
	m.enemies.append(m.make_enemy("cavalry",Vector2i(3,3),1))
	m.enemies.append(m.make_enemy("heavy",Vector2i(5,5),2))
	var before_hp: int = m.player.hp
	var threats := ThreatPreview.attackers(m)
	verify(threats.has(0) and not threats.has(2),"An adjacent heavy is marked, a far one is not")
	verify(m.player.hp == before_hp and m.phase == Rules.Phase.PLAYER and m.enemies[0].cell == Vector2i(2,2),"Looking ahead never changes the real board")
	m.walls[Vector2i(2,2)] = 1
	m.enemies[0].cell = Vector2i(5,0)
	verify(not ThreatPreview.attackers(m).has(0),"Enemies that cannot reach are not marked")

	# Early weapons: one tile, or two tiles when both are jumps.
	var W := Run.Weapons
	verify(W.is_early(W.DATA.map(func(d): return d.id).find("vault")) and W.offsets(W.DATA.map(func(d): return d.id).find("vault")) == [Vector2i(0,-2),Vector2i(0,2)],"Vertical jump pair is an early weapon")
	verify(not W.is_early(2) and not W.is_early(3),"Two-tile non-jump weapons are not early")
	var jump_pairs := 0
	for index in W.single_pool():
		if W.DATA[index].offsets.size() == 2:
			jump_pairs += 1
			verify(W.is_quirky(index),"Only weapons with a jump get two early tiles")
	verify(jump_pairs == 23,"Twenty-three odd two-tile weapons are in the early pool")
	verify(W.single_pool().all(func(i): return not W.horizontal_only(i)),"Left/right-only weapons are never offered")
	verify(W.opening_pool().size() == 21,"Twenty-one up-and-down weapons make the opening pick varied")
	verify(W.early_reward_pool().size() == 23 and W.early_reward_pool().all(func(i): return W.offsets(i).size() == 2),"Early rewards are all two-tile")

func _enemy_turn(m: RefCounted) -> void:
	var planner := Planner.new()
	planner.begin(m)
	for beat in range(2):
		planner.beat(m,beat)
	planner.finish(m)

func _ranged_soldiers() -> void:
	# Javelin: hits the three tiles one square beyond its front, never melee.
	var m := fixture()
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("javelin",Vector2i(3,1),0))
	var row: Array = m.javelin_cells(m.enemies[0])
	row.sort()
	verify(row == [Vector2i(1,0),Vector2i(1,1),Vector2i(1,2)],"Javelin row is one square beyond the front, three wide")
	verify(ThreatPreview.attackers(m).has(0),"A javelin thrower in range gets the ! mark")
	_enemy_turn(m)
	verify(m.player.hp == 4 and m.enemies[0].cell == Vector2i(3,1),"Javelin throws from its tile, once per turn")
	m = fixture()
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("javelin",Vector2i(5,4),0))
	_enemy_turn(m)
	verify(m.enemies[0].cell == Vector2i(4,3) and m.player.hp == 5,"Javelin walks four ways toward a throwing spot")
	m = fixture()
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("javelin",Vector2i(2,2),0))
	_enemy_turn(m)
	verify(m.enemies[0].cell.x == 3 and m.player.hp == 4,"An adjacent javelin backs off and throws instead of stabbing")

	# Archer: up/down only, aims with 1 AP when the player is on its lane, shoots next turn.
	m = fixture()
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("archer",Vector2i(5,0),0))
	verify(m.enemy_offsets(m.enemies[0]) == [Vector2i.UP,Vector2i.DOWN],"Archer moves only up and down")
	_enemy_turn(m)
	verify(m.enemies[0].cell == Vector2i(5,1) and m.enemies[0].state != "aim","Archer steps toward the player's row")
	_enemy_turn(m)
	verify(m.enemies[0].cell == Vector2i(5,2) and m.enemies[0].state != "aim","One AP: moving uses the whole turn")
	_enemy_turn(m)
	verify(m.enemies[0].state == "aim" and m.player.hp == 5,"On the lane the archer spends its AP aiming")
	verify(m.archer_lane(m.enemies[0]) == [Vector2i(4,2),Vector2i(3,2),Vector2i(2,2),Vector2i(1,2),Vector2i(0,2)],"The danger lane runs left like a lance")
	verify(ThreatPreview.attackers(m).has(0),"An aimed archer marks the player with !")
	m.enemies.append(m.make_enemy("heavy",Vector2i(3,2),1))
	_enemy_turn(m)
	verify(m.player.hp == 5 and m.enemies[1].hp == 1 and m.enemies[0].state != "aim","The arrow hits the first unit, even another enemy")
	m.enemies.remove_at(1)
	m.enemies[0].state = "aim"
	m.walls[Vector2i(3,2)] = 3
	verify(m.archer_lane(m.enemies[0]) == [Vector2i(4,2)],"Walls stop the arrow lane")
	_enemy_turn(m)
	verify(m.player.hp == 5,"A wall shields the player")
	m.walls.clear()
	m.enemies[0].state = "aim"
	_enemy_turn(m)
	verify(m.player.hp == 4,"An unobstructed arrow hits the player")
	m.player.cell = Vector2i(1,3)
	m.enemies[0].state = "aim"
	m.summon_acorn(Vector2i(2,2))
	m.allies[0].ap = 0
	var acorns: int = m.allies.size()
	m.phase = Rules.Phase.ENEMY
	m.enemies[0].ap = 1
	m.archer_shoot(m.enemies[0])
	verify(m.allies.size() == acorns-1,"Arrows hit the player's allies too")

func _mid_weapons() -> void:
	var W := Run.Weapons
	var hammer: int = W.DATA.map(func(d): return d.id).find("hammer")
	var bow: int = W.DATA.map(func(d): return d.id).find("bow")
	verify(W.is_mid(hammer) and W.is_mid(bow) and not W.single_pool().has(hammer) and not W.single_pool().has(bow),"Hammer and bow never drop early")
	# Hammer: pawn move, 3 damage, shakes the side tiles and the three beyond.
	var m := fixture()
	m.owned_weapons.assign([0,1,hammer])
	m.weapon = hammer
	m.player.cell = Vector2i(1,2)
	verify(m.targets() == [Vector2i(2,2)],"Hammer moves like a pawn")
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(2,2),0))
	m.enemies.append(m.make_enemy("heavy",Vector2i(2,1),1))
	m.enemies.append(m.make_enemy("infantry",Vector2i(3,3),2))
	m.enemies.append(m.make_enemy("infantry",Vector2i(4,2),3))
	verify(m.hammer_area(Vector2i(2,2)).size() == 6,"Hammer area is the target, two sides and three beyond")
	verify(m.player_action(Vector2i(2,2)) and m.player.cell == Vector2i(1,2),"Hammer attacks without moving")
	verify(m.enemy_at(Vector2i(2,2)).is_empty() and m.enemy_at(Vector2i(2,1)).is_empty() and m.enemy_at(Vector2i(3,3)).is_empty(),"Three damage to everything in the area")
	verify(not m.enemy_at(Vector2i(4,2)).is_empty(),"The area stops three tiles wide")
	verify(m.events.any(func(e): return e.kind == "quake"),"The hammer shows a quake effect")
	m.player.cell = Vector2i(1,2)
	verify(m.player_action(Vector2i(2,2)) and m.player.cell == Vector2i(2,2),"Hammer can also step forward")
	# Bow: bishop lines, attack only.
	m = fixture()
	m.owned_weapons.assign([0,1,bow])
	m.weapon = bow
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(4,5),0))
	m.enemies.append(m.make_enemy("infantry",Vector2i(3,4),1))
	m.enemies.append(m.make_enemy("infantry",Vector2i(0,1),2))
	var shots: Array = m.targets()
	shots.sort()
	verify(shots == [Vector2i(0,1),Vector2i(3,4)],"Bow hits the first enemy on each diagonal line")
	verify(not m.player_action(Vector2i(2,1)) and m.player.cell == Vector2i(1,2),"Bow cannot move")
	verify(m.player_action(Vector2i(3,4)) and m.enemy_at(Vector2i(3,4)).is_empty() and m.player.cell == Vector2i(1,2),"Bow shoots from where the player stands")
	verify(m.targets().has(Vector2i(4,5)),"With the front enemy gone, the line reaches further")
	m.fairy_loadout.assign(["wall_fairy"])
	m.refill_fairies()
	var spots: Array = m.item_targets("wall_fairy")
	verify(spots.has(Vector2i(3,4)) and spots.has(Vector2i(0,3)) and not spots.has(Vector2i(2,2)),"With the bow, fairies go on the empty tiles of its diagonal lines")
	verify(not spots.has(Vector2i(4,5)) and not spots.has(Vector2i(5,6)),"Lines stop at the first enemy for placement too")

func _place_on_enemies() -> void:
	# Magic bolt and slash spirits may appear on an enemy's tile within weapon range.
	var m := fixture()
	m.weapon = 0
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(2,2),0))
	m.enemies.append(m.make_enemy("recruit",Vector2i(3,1),1))
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,2),2))
	m.fairy_loadout.assign(["slash_fairy","magic_bolt","wall_fairy"])
	m.refill_fairies()
	verify(m.item_targets("slash_fairy").has(Vector2i(2,2)) and m.item_targets("magic_bolt").has(Vector2i(2,2)),"Slash and bolt can be placed on an enemy in range")
	verify(not m.item_targets("wall_fairy").has(Vector2i(2,2)),"Other fairies still need an empty tile")
	verify(m.use_item("slash_fairy",Vector2i(2,2),Vector2i.RIGHT),"Slash placed on the enemy's tile")
	verify(m.enemy_at(Vector2i(3,1)).is_empty() and m.enemy_at(Vector2i(2,2)).hp == 1,"It hits the enemy underneath and slashes the row in front")
	verify(m.directional_preview("magic_bolt",Vector2i(2,2),Vector2i.RIGHT).has(Vector2i(2,2)),"The preview includes the enemy underneath")
	verify(m.use_item("magic_bolt",Vector2i(2,2),Vector2i.RIGHT) and m.enemy_at(Vector2i(2,2)).is_empty() and m.enemy_at(Vector2i(4,2)).is_empty(),"A bolt on an enemy hits it and flies on past it")

func _boss_room() -> RefCounted:
	var m := Rules.new()
	m.boss_variant = 1
	m.reset(Rules.BOSS_LEVEL)
	return m

func _rook_and_prison() -> void:
	# The alternative first boss room: rook + moving prison on 6x6.
	var m := _boss_room()
	verify(m.board_size == 6 and m.enemies.size() == 2,"The rook room is 6x6 with two bosses")
	var rook: Dictionary = m.enemies.filter(func(e): return e.type == "rook")[0]
	var prison: Dictionary = m.enemies.filter(func(e): return e.type == "prison")[0]
	verify(rook.hp == 3 and rook.ap == 1 and prison.hp == 1 and prison.ap == 1,"Rook HP3/AP1, prison HP1/AP1")
	verify(m.footprint(rook).size() == 4 and m.enemy_at(rook.cell + Vector2i(1,1)) == rook,"Both are two by two")
	verify(rook.state == "idle" and rook.facing == 3,"The rook starts blue, facing left")
	var intro := _boss_room()
	intro.player.cell = Vector2i(0,1)
	var intro_rook: Dictionary = intro.enemies.filter(func(e): return e.type == "rook")[0]
	verify(intro.boss_intro() and intro_rook.state == "brace" and intro.phase == Rules.Phase.PLAYER and intro.player.ap == 2,"Boss intro: it turns red and aims before the player's first turn")
	verify(not intro.boss_intro(),"The intro only plays once")
	# Opening enemy turn: it only braces toward the player.
	m.player.cell = Vector2i(0,1)
	_enemy_turn(m)
	verify(rook.state == "brace" and rook.facing == 3 and m.player.hp == 5,"First turn: it turns red and aims, no charge yet")
	verify(m.rook_lane(rook).has(Vector2i(0,1)) and m.rook_lane(rook).has(Vector2i(3,2)),"The two-wide charge lane is shown ahead")
	verify(ThreatPreview.attackers(m).has(rook.id),"A braced rook aimed at the player gets the ! mark")
	# Getting hit: 1 damage and shoved to the wall together.
	m = _boss_room()
	rook = m.enemies.filter(func(e): return e.type == "rook")[0]
	m.enemies = m.enemies.filter(func(e): return e.type == "rook")
	rook.cell = Vector2i(3,0)
	rook.state = "brace"
	rook.facing = 3
	m.player.cell = Vector2i(2,1)
	_enemy_turn(m)
	verify(m.player.hp == 4 and m.player.cell == Vector2i(0,1) and rook.cell == Vector2i(1,0),"A hit deals 1 and pushes the player to the wall with the rook")
	verify(rook.state == "brace","It aims again right after charging")
	# Dodging: it runs along its lane until it shares the player's axis, then aims at them.
	m = _boss_room()
	rook = m.enemies.filter(func(e): return e.type == "rook")[0]
	m.enemies = m.enemies.filter(func(e): return e.type == "rook")
	rook.cell = Vector2i(4,0)
	rook.state = "brace"
	rook.facing = 3
	m.player.cell = Vector2i(2,4)
	_enemy_turn(m)
	verify(m.player.hp == 5 and rook.cell == Vector2i(2,0),"A dodged charge stops on the player's column")
	verify(rook.facing == 2,"...and re-aims down at the player")
	_enemy_turn(m)
	verify(m.player.hp == 4 and m.player.cell == Vector2i(2,5) and rook.cell == Vector2i(2,3),"The next charge down pins the player against the bottom wall")
	# A wall spirit stops the charge.
	m = _boss_room()
	rook = m.enemies.filter(func(e): return e.type == "rook")[0]
	m.enemies = m.enemies.filter(func(e): return e.type == "rook")
	rook.cell = Vector2i(4,0)
	rook.state = "brace"
	rook.facing = 3
	m.player.cell = Vector2i(0,0)
	m.walls[Vector2i(2,0)] = 3
	_enemy_turn(m)
	verify(m.player.hp == 5 and rook.cell == Vector2i(3,0),"A wall spirit blocks the charge")
	# Multi-tile effects hit a big enemy once.
	m = _boss_room()
	rook = m.enemies.filter(func(e): return e.type == "rook")[0]
	m.phase = Rules.Phase.PLAYER
	m.weapon = 0
	m.player.cell = rook.cell + Vector2i(-1,0)
	m.fairy_loadout.assign(["magic_bolt"])
	m.refill_fairies()
	m.player.cell = Vector2i(1,1)
	rook.cell = Vector2i(3,1)
	verify(m.use_item("magic_bolt",Vector2i(2,1),Vector2i.RIGHT) and rook.hp == 2,"A bolt through both of the rook's tiles hits it once")
	verify(m.player_action(Vector2i(2,1)) and m.player.cell == Vector2i(2,1),"The player steps up to it")
	m.player.ap = 2
	verify(m.player_action(Vector2i(3,1)) and rook.hp == 1,"Striking any of its tiles damages it")
	# Moving prison: slides as a block, breaks into two executioners.
	m = _boss_room()
	prison = m.enemies.filter(func(e): return e.type == "prison")[0]
	m.enemies = m.enemies.filter(func(e): return e.type == "prison")
	prison.cell = Vector2i(3,3)
	m.player.cell = Vector2i(0,4)
	_enemy_turn(m)
	verify(prison.cell == Vector2i(2,3) and m.player.hp == 5,"The prison slides one tile toward the player")
	_enemy_turn(m)
	verify(prison.cell == Vector2i(1,3) and m.player.hp == 5,"...and again")
	_enemy_turn(m)
	verify(m.player.hp == 4 and prison.cell == Vector2i(1,3),"Touching the player it attacks instead of moving")
	m.phase = Rules.Phase.PLAYER
	m.player.ap = 2
	m.weapon = 0
	verify(m.player_action(Vector2i(1,4)),"The player strikes the prison")
	var guards: Array = m.enemies.filter(func(e): return e.type == "executioner")
	verify(guards.size() == 2 and m.phase == Rules.Phase.PLAYER,"Breaking it releases two executioners and the fight goes on")
	var spots: Array = guards.map(func(e): return e.cell)
	spots.sort()
	verify(spots == [Vector2i(1,3),Vector2i(2,4)],"They appear on a diagonal of its footprint")
	verify(guards.all(func(e): return e.hp == 2 and Rules.TYPES[e.type].ap == 2),"Executioners are HP2/AP2")
	_enemy_turn(m)
	verify(m.player.hp < 4,"Executioners attack like infantry")
	# The run draws the boss room.
	var run := Run.new()
	run.start(7)
	var seen := {}
	for i in 40:
		run.stage = 2
		run.advance()
		seen[run.battle.boss_variant] = true
	verify(seen.has(0) and seen.has(1),"The first boss is drawn between the horses and the rook room")

func _slot_room() -> RefCounted:
	var m := Rules.new()
	m.reset(Rules.BOSS2_LEVEL)
	m.owned_weapons.assign([0,1,3])
	return m

func _slot_ready(m: RefCounted, reel: int) -> Dictionary:
	var boss: Dictionary = m.enemies[0]
	m.rook_brace(boss)
	boss.reel = reel
	boss.last_reel = reel
	return boss

func _rotorick() -> void:
	var m := _slot_room()
	var boss: Dictionary = m.enemies[0]
	verify(boss.hp == 3 and boss.ap == 1 and m.footprint(boss).size() == 4,"Rotorick: HP3, AP1, two by two")
	verify(boss.state == "idle" and int(boss.reel) == 0,"Rotorick enters idle with the reel spinning")
	m.player.cell = Vector2i(0,2)
	verify(m.boss_intro() and boss.state == ("stun" if int(boss.reel) == 5 else "brace") and int(boss.reel) >= 1 and int(boss.reel) <= 7,"Before the first turn it aims and shows a reel")
	# The reel is drawn from the model's seed, never twice in a row, 7 rarer.
	var counts := {}
	var last := 0
	var repeats := 0
	for i in 700:
		var r: int = m.slot_roll(boss)
		boss.last_reel = r
		counts[r] = counts.get(r,0)+1
		if r == last:
			repeats += 1
		last = r
	verify(repeats == 0 and counts.size() == 7,"All seven results appear and none repeats back to back")
	verify(counts[7] < counts[1] and counts[7] < counts[4],"7 comes up less often")
	var copy: RefCounted = m.clone()
	verify(copy.slot_roll(boss) == m.slot_roll(boss),"Look-ahead copies roll the same results without disturbing them")
	# 1-3: weapon lock for the player's turn.
	m = _slot_room()
	boss = _slot_ready(m, 0)
	boss.last_reel = 0
	m.slot_rolls = 0
	for i in 50:
		m.floor_cells.clear()
		m.locked_slot = -1
		m.slot_spin(boss)
		if int(boss.reel) <= 3:
			break
	m.phase = Rules.Phase.PLAYER
	var slot: int = int(boss.reel) - 1
	verify(m.locked_slot == slot and m.weapon == m.owned_weapons[slot],"Reels 1-3 force the matching weapon slot")
	var other: int = m.owned_weapons[(slot+1)%3]
	verify(not m.equip(other) and m.equip(m.owned_weapons[slot]),"Other weapons cannot be equipped that turn")
	Planner.new().begin(m)
	verify(m.locked_slot == -1,"The lock ends when the enemy turn begins")
	# 4: the checker floor burns at the start of the enemy turn, allies and foes alike.
	m = _slot_room()
	boss = _slot_ready(m, 4)
	m.floor_cells.clear()
	var parity: int = (boss.cell.x + boss.cell.y) % 2
	for y in 6:
		for x in 6:
			if (x+y)%2 == parity:
				m.floor_cells.append(Vector2i(x,y))
	m.player.cell = Vector2i(0,0) if parity == 0 else Vector2i(1,0)
	m.summon_acorn(Vector2i(0,4) if parity == 0 else Vector2i(1,4))
	_enemy_turn(m)
	verify(m.player.hp <= 4 and m.allies.is_empty(),"Reel 4 burns everyone on the checker, player and allies")
	verify(boss.hp == 3,"Rotorick is not hurt by its own floor")
	# 5: jammed, no charge, no self damage.
	m = _slot_room()
	boss = _slot_ready(m, 5)
	boss.state = "stun"
	m.player.cell = Vector2i(0,2)
	var start: Vector2i = boss.cell
	_enemy_turn(m)
	verify(boss.cell == start and m.player.hp == 5 and boss.hp == 3,"Reel 5: it does not charge and loses no HP")
	verify(boss.state == "brace" and int(boss.reel) != 5,"...then it aims and spins again")
	# 6: leaves a shadow where it stood, then charges.
	m = _slot_room()
	boss = _slot_ready(m, 6)
	m.player.cell = Vector2i(0,0)
	start = boss.cell
	_enemy_turn(m)
	var shadows: Array = m.enemies.filter(func(e): return e.type == "shadow")
	verify(shadows.size() == 1 and shadows[0].cell == start and boss.cell != start,"Reel 6: a shadow stays behind and Rotorick charges")
	m.phase = Rules.Phase.PLAYER
	m.player.ap = 2
	m.player.cell = start + Vector2i(-2,0)
	m.weapon = 0
	var hp_before: int = m.player.hp
	m.player_action(start + Vector2i(-1,0))
	verify(m.player.hp == hp_before - 1 and m.enemies.filter(func(e): return e.type == "shadow").is_empty(),"Stepping next to the shadow gets you cut once, then it fades")
	# 7: AP+1 and a charge that always lands.
	m = _slot_room()
	boss = _slot_ready(m, 7)
	boss.facing = 3
	m.player.cell = Vector2i(1,5)
	_enemy_turn(m)
	verify(m.player.hp <= 4,"Reel 7: even a dodged line is chased down and hit")
	m = _slot_room()
	boss = _slot_ready(m, 7)
	boss.facing = 3
	m.player.cell = Vector2i(0,2)
	m.walls[Vector2i(3,2)] = 3
	m.walls[Vector2i(3,3)] = 3
	_enemy_turn(m)
	verify(m.player.hp == 5,"Reel 7 is still stopped by wall spirits")
	# Winning ignores leftover shadows.
	m = _slot_room()
	boss = m.enemies[0]
	m._leave_shadow(boss)
	boss.hp = 0
	m.check_outcome()
	verify(m.phase == Rules.Phase.WON,"Defeating Rotorick wins even with a shadow left")
