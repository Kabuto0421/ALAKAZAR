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
	verify(run.offers.size()==5 and run.offers.slice(0,3).all(func(o): return o.kind=="weapon") and run.offers.slice(3).all(func(o): return o.kind=="fairy"),"Rewards always contain three weapons and two fairies")
	verify(run.offers.slice(0,3).all(func(o): return not Run.Weapons.horizontal_only(int(o.value)) and not run.battle.owned_weapons.has(int(o.value))),"Reward weapons skip owned and left-right-only weapons")
	# Early weapon cards: mostly common, a few uncommon, rare and super rare under 1%.
	var tiers := [0, 0, 0, 0]
	var slots := 0
	for seed_value in 400:
		var trial := Run.new()
		trial.start(seed_value)
		trial.state = Run.State.BATTLE
		trial.battle.phase = Rules.Phase.WON
		trial.finish_battle()
		for o in trial.offers.slice(0,3):
			slots += 1
			tiers[Run.Rarity.tier({"kind":"weapon","value":o.value})] += 1
	verify(tiers[1] > slots * 0.02 and tiers[1] < slots * 0.11 and tiers[2] + tiers[3] < slots * 0.03,"Early weapon cards: about 6%% uncommon, rare ones under 1%% (%s of %d)" % [tiers, slots])
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
	run.choose(3)
	verify(run.stage==2 and m.fairy_loadout.size()==2 and m.board_size==6,"Fairy reward persists into six-by-six encounter")
	verify(m.enemies.size()==6 and m.enemies.filter(func(e): return e.type=="heavy").size()==2 and m.enemies.filter(func(e): return e.type=="infantry").size()==2,"Third encounter pairs two heavies with AP2 infantry")
	verify(m.enemies.filter(func(e): return e.type=="cavalry").size()==1,"Cavalry first appears in the third fight")
	verify(m.enemies.all(func(e): return not e.type in Rules.RANGED),"The third fight has no ranged soldiers either")
	verify(m.enemies.all(func(e): return m.inside(e.cell) and e.cell!=m.player.cell),"Rotated third-stage placements stay valid")
	m.player.hp = 2
	m.enemies.clear()
	m.check_outcome()
	run.finish_battle()
	verify(m.start_hp == 3,"HP carries over after a win, plus 1 for winning")
	run.skip_reward()
	verify(run.state==Run.State.CAMP,"The third fight's reward leads to the camp")
	verify(run.camp_forge() and run.state==Run.State.CAMP_FORGE and run.offers.size()==3,"Forging lists the owned weapons")
	run.camp_back()
	verify(run.state==Run.State.CAMP,"Forging can be cancelled")
	verify(run.camp_rest() and m.start_hp == 5,"Resting heals 2")
	verify(run.state==Run.State.BATTLE and m.level==Rules.BOSS_LEVEL and m.board_size==7,"The boss fight follows the camp on a 7x7 board")
	verify(m.player.hp == 5,"The boss fight starts with the carried HP")
	verify(m.enemies.size()==3 and m.enemies.all(func(e): return e.type=="horse" and e.hp==2 and e.ap==2),"Three 2HP horses")
	verify(m.enemy_offsets(m.enemies[0]).size()==6,"Horses jump like cavalry")
	m.enemies.clear()
	m.check_outcome()
	verify(run.finish_battle() and run.state==Run.State.REWARD,"Beating the boss opens a reward")
	verify(run.offers.slice(0,3).any(func(o): return Run.Weapons.is_mid(o.value)),"After the boss a hammer or bow is offered")
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
	verify(run.state==Run.State.BATTLE and m.level==Rules.BOSS2_LEVEL and m.board_size==8 and m.enemies.size()==1 and m.enemies[0].type=="slot","Rotorick waits after the mid-game camp")
	m.enemies.clear()
	m.check_outcome()
	verify(run.finish_battle() and run.state==Run.State.REWARD,"Beating Rotorick opens a reward")
	run.skip_reward()
	for k in 3:
		verify(run.state==Run.State.BATTLE and m.level==Rules.LATE_LEVELS[k] and m.enemies.size() >= 7,"Late fight %d follows" % (k+1))
		verify(m.enemies.all(func(e): return m.footprint(e).all(func(c): return m.inside(c) and c != m.player.cell)),"Late placements are valid")
		m.enemies.clear()
		m.check_outcome()
		run.finish_battle()
		if k < 2:
			verify(run.state==Run.State.REWARD,"Each late fight but the last gives a reward")
			run.skip_reward()
		if k == 1:
			verify(run.state==Run.State.CAMP,"A late camp comes before the last late fight")
			run.camp_rest()
	verify(run.state==Run.State.REWARD,"The last late fight gives a reward")
	run.skip_reward()
	verify(run.state==Run.State.CAMP,"A last camp comes before the Prison King")
	run.camp_rest()
	verify(run.state==Run.State.BATTLE and m.level==Rules.FINAL_LEVEL and m.board_size==10 and m.enemies.any(func(e): return e.type=="king"),"The Prison King waits on a 10x10 board")
	verify(m.enemies.all(func(e): return m.footprint(e).all(func(c): return m.inside(c) and c != m.player.cell)),"Final placements are valid")
	m.enemies = m.enemies.filter(func(e): return e.type != "king")
	m.check_outcome()
	verify(m.phase == Rules.Phase.WON,"Felling the king wins the fight whatever is left")
	verify(run.finish_battle() and run.state==Run.State.FINISHED,"Beating the Prison King completes the expedition")

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
	var incoming: String = run.offers[3].value
	run.choose(3)
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
	_expiring_and_rewards()
	_capacitor()
	_class_ups()
	_rare_fairies()
	_magic_circle()
	_mechanic_weapons()
	_resonance()
	_knockback()
	_difficulty()
	_shield_soldier()
	_analyst()
	_loner_fairies()
	_optional_rules()
	_generals()
	_abyss()
	_gravity()
	_glutton()
	_prison_king()
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
	for turn in range(Rules.WALL_TURNS):
		verify(m.walls.has(Vector2i(2,2)),"Wall stands on player turn %d" % (turn+1))
		planner.begin(m)
		planner.finish(m)
	verify(not m.walls.has(Vector2i(2,2)),"Wall crumbles before the sixth player turn")

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
	verify(m.enemy_at(Vector2i(2,0)).hp == 1 and not m.enemy_at(Vector2i(2,4)).is_empty(),"One shot down its line (two once upgraded), nothing behind")
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

	# Slash spirit: the two tiles left and right of where it is placed.
	m = fixture()
	m.fairy_loadout.assign(["slash_fairy"])
	m.refill_fairies()
	m.weapon = 0
	m.enemies.clear()
	m.enemies.append(m.make_enemy("recruit",Vector2i(2,1),0))
	m.enemies.append(m.make_enemy("heavy",Vector2i(3,2),1))
	m.enemies.append(m.make_enemy("recruit",Vector2i(2,4),2))
	verify(not m.item_definition("slash_fairy").directional,"The slash needs no direction")
	verify(m.use_item("slash_fairy",Vector2i(2,2)),"Slash spirit is placed in weapon range")
	verify(m.enemy_at(Vector2i(2,1)).is_empty() and m.enemy_at(Vector2i(3,2)).hp == 2,"Slash hits the tiles above and below, not beside")
	verify(not m.enemy_at(Vector2i(2,4)).is_empty(),"Slash reaches only one tile up and down")
	verify(m.side_slash_cells(Vector2i(2,2)) == [Vector2i(2,1),Vector2i(2,3)],"Slash area is up and down")

	# 斬撃精霊+ (class-up): a 3-wide, 5-long wave in the chosen direction; lanes stop at blockers.
	m = fixture()
	m.enemies.clear()
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,1),0))
	m.enemies.append(m.make_enemy("recruit",Vector2i(5,2),1))
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,3),2))
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,4),3))
	m.walls[Vector2i(3,3)] = 2
	m.slash(Vector2i(2,2),Vector2i.RIGHT)
	verify(m.enemy_at(Vector2i(4,1)).is_empty() and m.enemy_at(Vector2i(5,2)).is_empty(),"The wave hits the centre and side lanes")
	verify(not m.enemy_at(Vector2i(4,3)).is_empty(),"A wall stops a lane")
	verify(not m.enemy_at(Vector2i(4,4)).is_empty(),"The wave is only three lanes wide")
	verify(m.slash_cells(Vector2i(0,2),Vector2i.RIGHT).filter(func(c): return c.y == 2).size() == 5,"...and five tiles long")
	m.fairy_plus["slash_fairy"] = 1
	verify(m.is_directional("slash_fairy") and m.item_definition("flying_slash") == null,"斬撃精霊+ asks for a direction; the flying slash is no longer a fairy of its own")

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
	verify(jump_pairs == 13,"Thirteen odd two-tile weapons are in the early pool (mirror twins removed)")
	verify(W.single_pool().all(func(i): return not W.horizontal_only(i)),"Left/right-only weapons are never offered")
	verify(W.opening_pool().size() == 12,"Twelve up-and-down weapons make the opening pick varied")
	verify(W.early_reward_pool().size() == 16 and W.early_reward_pool().all(func(i): return W.offsets(i).size() == 2 or W.knockback(i) > 0 or W.DATA[i].get("early", false)),"Early rewards are the two-tile jumpers, the shield, the swap staff and the mallet")

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
	verify(m.enemies[0].cell == Vector2i(5,2) and m.enemies[0].state != "aim","With 2 AP the archer moves two tiles toward the player's row")
	_enemy_turn(m)
	verify(m.enemies[0].state == "aim" and m.player.hp == 5,"On the lane it aims, and aiming ends its turn")
	verify(m.archer_lane(m.enemies[0]) == [Vector2i(4,2),Vector2i(3,2),Vector2i(2,2),Vector2i(1,2),Vector2i(0,2)],"The danger lane runs left like a lance")
	verify(ThreatPreview.attackers(m).has(0),"An aimed archer marks the player with !")
	m.enemies.append(m.make_enemy("heavy",Vector2i(3,2),1))
	_enemy_turn(m)
	verify(m.player.hp == 5 and m.enemies[1].hp == 1,"The arrow hits the first unit, even another enemy")
	verify(m.enemies[0].state == "aim","With its second AP it aims again right away")
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
	verify(not m.enemy_at(Vector2i(3,1)).is_empty() and m.enemy_at(Vector2i(2,2)).hp == 1,"It hits the enemy underneath and the tiles beside it")
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
	verify(not m.walls.has(Vector2i(2,0)),"...and is smashed by it")
	# An acorn ally in the lane is smashed too, so the rook never gets stuck.
	m = _boss_room()
	rook = m.enemies.filter(func(e): return e.type == "rook")[0]
	m.enemies = m.enemies.filter(func(e): return e.type == "rook")
	rook.cell = Vector2i(4,0)
	rook.state = "brace"
	rook.facing = 3
	m.player.cell = Vector2i(0,0)
	m.summon_acorn(Vector2i(3,1))
	_enemy_turn(m)
	verify(m.allies.is_empty() and rook.cell == Vector2i(4,0) and m.player.hp == 5,"An acorn in the lane is smashed and the charge stops there")
	_enemy_turn(m)
	verify(m.player.hp == 4,"Next turn the lane is clear and the charge lands")
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
	verify(boss.hp == 7 and boss.ap == 1 and m.footprint(boss).size() == 4,"Rotorick: HP7, AP1, two by two")
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
	verify(boss.hp == 7,"Rotorick is not hurt by its own floor")
	# 5: jammed, no charge, no self damage.
	m = _slot_room()
	boss = _slot_ready(m, 5)
	boss.state = "stun"
	m.player.cell = Vector2i(0,2)
	var start: Vector2i = boss.cell
	_enemy_turn(m)
	verify(boss.cell == start and m.player.hp == 5 and boss.hp == 7,"Reel 5: it does not charge and loses no HP")
	verify(boss.state == "brace" and int(boss.reel) != 5,"...then it aims and spins again")
	# 6: leaves a shadow where it stood, then charges.
	m = _slot_room()
	boss = _slot_ready(m, 6)
	m.player.cell = Vector2i(0,0)
	start = boss.cell
	_enemy_turn(m)
	var shadows: Array = m.enemies.filter(func(e): return e.type == "shadow")
	verify(shadows.size() == 1 and shadows[0].cell == start and boss.cell != start,"Reel 6: a shadow stays behind and Rotorick charges")
	verify(m.enemy_at(start).is_empty() and not m.shadow_at(start).is_empty(),"The shadow blocks nothing: its tiles hold no enemy")
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
	verify(m.player.hp <= 4 and not m.walls.has(Vector2i(3,3)),"Reel 7 smashes a wall spirit and keeps chasing")
	# Winning ignores leftover shadows.
	m = _slot_room()
	boss = m.enemies[0]
	m._leave_shadow(boss)
	boss.hp = 0
	m.check_outcome()
	verify(m.phase == Rules.Phase.WON,"Defeating Rotorick wins even with a shadow left")

func _expiring_and_rewards() -> void:
	# A class-up makes a fairy 1 AP cheaper and usable once more per battle.
	var um := fixture()
	um.fairy_loadout.assign(["magic_bolt"])
	um.refill_fairies()
	verify(um.fairy_ap_cost("magic_bolt") == 1 and um.fairy_charges == [1],"Before the class-up: 1 AP, once a battle")
	um.fairy_plus["magic_bolt"] = true
	um.refill_fairies()
	verify(um.fairy_ap_cost("magic_bolt") == 0 and um.fairy_charges == [2],"After it: 0 AP, twice a battle")
	verify(um.item_definition("warp_fairy").ap_cost == 0,"The warp fairy costs 0 AP")
	# A magic bolt flies through a cannon and sets it off; an acorn beside a cannon fires it.
	var bm := fixture()
	bm.enemies.clear()
	bm.player.cell = Vector2i(0,2)
	bm.owned_weapons.assign([0])
	bm.weapon = 0
	bm.place_cannon(Vector2i(3,2), Vector2i.UP, "lance")
	var target: Dictionary = bm.make_enemy("heavy", Vector2i(3,0), 5)
	target.hp = 9
	bm.enemies.append_array([target, bm.make_enemy("heavy", Vector2i(5,5), 6)])
	bm.fairy_loadout.assign(["magic_bolt"])
	bm.refill_fairies()
	verify(bm.use_item("magic_bolt", Vector2i(1,2), Vector2i.RIGHT) and target.hp == 8,"The bolt passes the cannon, which fires")
	bm.summon_acorn(Vector2i(3,3))
	bm.act_allies()
	verify(target.hp == 7,"The acorn next to the cannon fires it instead of walking")
	# Rarity: four tiers; the glutton is super rare, new fairies come up more often.
	var Rarity = load("res://scripts/run/rarity.gd")
	verify(Rarity.tier({"kind":"fairy","value":"glutton_fairy"}) == Rarity.SUPER_RARE and Rarity.tier({"kind":"fairy","value":"meteor_fairy"}) == Rarity.RARE and Rarity.tier({"kind":"fairy","value":"guardian_fairy"}) == Rarity.SUPER_RARE and Rarity.tier({"kind":"fairy","value":"magic_bolt"}) == Rarity.COMMON,"Glutton super rare, meteor rare, magic bolt common")
	var wids: Array = Run.Weapons.DATA.map(func(w): return w.id)
	verify(Rarity.tier({"kind":"weapon","value":wids.find("rook_spear"),"enchant":"circle"}) == Rarity.SUPER_RARE and Rarity.tier({"kind":"weapon","value":wids.find("hammer")}) == Rarity.UNCOMMON,"Rook spear super rare, hammer uncommon")
	verify(Rarity.tier({"kind":"fairy","value":"holy_spirit"}) == Rarity.SUPER_RARE,"The holy spirit is super rare")
	# Fairy cards draw a rarity first: 激レア about 1% early, rising to 10% at the end.
	var odds: Array = Run.FAIRY_TIER_ODDS
	verify(odds.all(func(row): return absf(row.reduce(func(a, b): return a + b, 0.0) - 1.0) < 0.001),"Each row of fairy rarity odds adds up to 1")
	var rising := true
	for k in range(1, odds.size()):
		rising = rising and odds[k][3] >= odds[k-1][3] and odds[k][0] <= odds[k-1][0]
	verify(rising and is_equal_approx(odds[0][3], 0.01) and is_equal_approx(odds[-1][3], 0.10),"Super rare fairies climb from 1% to 10%, commons shrink")
	var boss_odds := Run.new()
	boss_odds.stage = Rules.BOSS_LEVEL
	var boosted: Array = boss_odds.fairy_tier_odds()
	boss_odds.stage = Rules.MID_LEVELS[0]
	verify(boosted[2] > odds[Rules.BOSS_LEVEL][2] and boosted[3] > odds[Rules.BOSS_LEVEL][3] and absf(boosted.reduce(func(a, b): return a + b, 0.0) - 1.0) < 0.001 and boss_odds.fairy_tier_odds() == odds[Rules.MID_LEVELS[0]],"The reward right after a boss leans rarer, the next one does not")
	var drawer := Run.new()
	drawer.start(3)
	var super_early := 0
	var super_late := 0
	var early_tiers := {}
	for k in 4000:
		drawer.stage = 0
		var early_id := drawer.draw_fairy(drawer.reward_fairy_pool)
		early_tiers[Rarity.tier({"kind":"fairy","value":early_id})] = true
		if Rarity.tier({"kind":"fairy","value":early_id}) == Rarity.SUPER_RARE:
			super_early += 1
		drawer.stage = 10
		if Rarity.tier({"kind":"fairy","value":drawer.draw_fairy(drawer.reward_fairy_pool)}) == Rarity.SUPER_RARE:
			super_late += 1
	verify(early_tiers.size() == 4,"Every rarity can turn up from the first reward")
	verify(super_early > 10 and super_early < 90 and super_late > 300 and super_late < 500,"Super rare fairy cards: about 1%% early (%d/4000), 10%% late (%d/4000)" % [super_early, super_late])
	# 氷結妖精: the 3x3 around it is frozen for three enemy turns.
	var fz := fixture()
	fz.enemies.clear()
	fz.player.cell = Vector2i(0,2)
	fz.owned_weapons.assign([0])
	fz.weapon = 0
	var icy: Dictionary = fz.make_enemy("heavy", Vector2i(2,2), 0)
	var far_one: Dictionary = fz.make_enemy("heavy", Vector2i(5,5), 1)
	fz.enemies.append_array([icy, far_one])
	fz.fairy_loadout.assign(["freeze_fairy"])
	fz.refill_fairies()
	verify(fz.use_item("freeze_fairy", Vector2i(1,2)) and fz.frozen(icy) and not fz.frozen(far_one),"Freezing catches the 3x3 only")
	var fplanner := Planner.new()
	for turn in 3:
		var before_cell: Vector2i = icy.cell
		fplanner.begin(fz)
		fplanner.beat(fz,0)
		fplanner.beat(fz,1)
		fplanner.finish(fz)
		verify(icy.cell == before_cell and fz.player.hp == 5,"A frozen enemy neither moves nor strikes (turn %d)" % (turn + 1))
	verify(not fz.frozen(icy),"...and thaws after three turns")
	# 加護の妖精: standing in it, a hit also lands on the tiles above and below.
	var bl := fixture()
	bl.enemies.clear()
	bl.player.cell = Vector2i(1,2)
	bl.owned_weapons.assign([0])
	bl.weapon = 0
	var mid_foe: Dictionary = bl.make_enemy("heavy", Vector2i(2,2), 0)
	var top_foe: Dictionary = bl.make_enemy("heavy", Vector2i(2,1), 1)
	var low_foe: Dictionary = bl.make_enemy("heavy", Vector2i(2,3), 2)
	bl.enemies.append_array([mid_foe, top_foe, low_foe, bl.make_enemy("heavy", Vector2i(5,5), 3)])
	bl.fairy_loadout.assign(["blessing_fairy"])
	bl.refill_fairies()
	bl.place_blessing(Vector2i(1,1))
	verify(bl.blessed(bl.player.cell) and bl.player_action(Vector2i(2,2)) and mid_foe.hp == 1 and top_foe.hp == 1 and low_foe.hp == 1,"Blessed, the hit also lands above and below")
	# 隕石妖精: meteors land in weapon reach, 99 to enemies in the 3x3; more with each class-up.
	var mt := fixture()
	mt.enemies.clear()
	mt.player.cell = Vector2i(0,2)
	mt.owned_weapons.assign([0])
	mt.weapon = 0
	var crushed: Dictionary = mt.make_enemy("heavy", Vector2i(1,1), 0)
	mt.enemies.append_array([crushed, mt.make_enemy("heavy", Vector2i(5,5), 1)])
	mt.fairy_loadout.assign(["meteor_fairy"])
	mt.refill_fairies()
	verify(mt.use_item("meteor_fairy", mt.player.cell) and crushed.hp <= 0 and mt.player.hp == 5,"A meteor on the only tile in reach crushes the 3x3, sparing the player")
	verify(mt.meteor_count() == 1 and mt.can_class_up("meteor_fairy"),"One meteor to start; it can be upgraded")
	for k in 4:
		mt.class_up(0)
	verify(mt.meteor_count() == 5 and not mt.can_class_up("meteor_fairy") and mt.fairy_title("meteor_fairy") == "隕石妖精+4","Four class-ups: five meteors, and no more")
	# A chain reads link by link: each cannon set off fires one beat after the last.
	var ch := fixture()
	ch.enemies.clear()
	ch.enemies.append(ch.make_enemy("heavy", Vector2i(5,5), 0))
	ch.place_cannon(Vector2i(1,1), Vector2i.RIGHT, "lance")
	ch.place_cannon(Vector2i(3,1), Vector2i.DOWN, "lance")
	ch.start_chain()
	ch.fire_cannon(ch.cannon_at(Vector2i(1,1)))
	var muzzles: Array = ch.events.filter(func(e): return e.kind == "muzzle")
	var beats: Array = muzzles.map(func(e): return snappedf(e.delay, 0.01))
	verify(beats == [0.0, 0.18],"The cannon it sets off fires one beat later")
	ch.cannons.clear()
	ch.place_cannon(Vector2i(1,1), Vector2i.RIGHT, "lance", true)
	ch.place_cannon(Vector2i(3,1), Vector2i.DOWN, "lance", true)
	ch.events.clear()
	ch.start_chain()
	ch.fire_cannon(ch.cannon_at(Vector2i(1,1)))
	beats = ch.events.filter(func(e): return e.kind == "muzzle").map(func(e): return snappedf(e.delay, 0.01))
	verify(beats == [0.0, 0.18, 0.48, 0.78],"Upgraded: first volley, the cannon it sets off (both volleys), then the second volley")
	verify(ch.events.filter(func(e): return e.kind == "chain").map(func(e): return e.count) == [2],"The chain link is counted for the combo")
	# 守護神の妖精: calls back one of each ally kind summoned this battle, with +1 HP.
	var gd := fixture()
	gd.enemies.clear()
	gd.enemies.append(gd.make_enemy("heavy", Vector2i(5,5), 0))
	gd.player.cell = Vector2i(0,0)
	gd.summon_acorn(Vector2i(4,0))
	gd.summon_glutton(Vector2i(5,1))
	gd.summon_acorn(Vector2i(0,5))
	gd.allies.clear()
	gd.summon_guardian(Vector2i(2,2))
	var called: Array = gd.allies.filter(func(a): return a.type != "guardian")
	var boss: Array = gd.allies.filter(func(a): return a.type == "guardian")
	verify(boss.size() == 1 and boss[0].hp == 3 and boss[0].size == 2,"The guardian is a 2x2 ally with HP 3")
	verify(called.map(func(a): return a.type) == ["acorn", "glutton"],"It calls one of each summoned kind (the glutton too), in order")
	verify(called[0].hp == 2 and called[1].hp == 2,"Everyone it calls gets +1 HP")
	verify(called.all(func(a): return gd.footprint_distance(boss[0], a.cell) <= 1),"They appear right around it")
	var entrance: Array = gd.events.filter(func(e): return e.kind == "guardian")
	verify(entrance.size() == 1 and entrance[0].calls.size() == 2 and entrance[0].calls[1].delay > entrance[0].calls[0].delay,"The calls come one after another")
	# The capacitor charges by itself at the end of every player turn.
	var cm := fixture()
	cm.place_cannon(Vector2i(3,3), Vector2i.UP, "capacitor")
	cm.charge_capacitors()
	verify(int(cm.cannon_at(Vector2i(3,3)).charge) == 1,"A capacitor stores 1 at the end of the player's turn")
	# Placed spirits (cannons, stealth) vanish after five player turns, like walls.
	var m := fixture()
	m.place_cannon(Vector2i(3,3), Vector2i.UP, "vane")
	m.place_stealth(Vector2i(4,4))
	for k in Rules.WALL_TURNS - 1:
		m.tick_walls()
	verify(m.cannons.size() == 1 and m.fairies.size() == 1,"Placed spirits last through four turn changes")
	m.tick_walls()
	verify(m.cannons.is_empty() and m.fairies.is_empty(),"...and vanish on the fifth, like the wall")
	# The reward right before a boss leans to uncommon weapons (the three-tile ones).
	var uncommon_cards := 0
	for seed_value in 200:
		var run := Run.new()
		run.start(seed_value)
		run.stage = 2
		run.state = Run.State.BATTLE
		run.battle.phase = Rules.Phase.WON
		run.finish_battle()
		for o in run.offers.slice(0,3):
			if Run.Rarity.tier({"kind":"weapon","value":o.value}) == Run.Rarity.UNCOMMON:
				uncommon_cards += 1
	verify(uncommon_cards > 600 * 0.75,"The reward before the boss is mostly uncommon weapons (%d/600)" % uncommon_cards)
	var threes: Array = range(Run.Weapons.DATA.size()).filter(func(i): return Run.Weapons.is_boss_reward(i))
	verify(threes.size() == 10,"Nine three-tile weapons and the lance feed the pre-boss reward")

## Fixture with one upgraded fairy in hand and heavies (HP 3) placed as asked.
func _plus_room(id: String, foes: Array) -> RefCounted:
	var m := fixture()
	m.fairy_loadout.assign([id])
	m.fairy_plus[id] = true
	m.refill_fairies()
	m.weapon = 0
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	for k in foes.size():
		m.enemies.append(m.make_enemy("heavy",foes[k],k))
	return m

func _hurt(m: RefCounted, cell: Vector2i) -> bool:
	var enemy: Dictionary = m.enemy_at(cell)
	return not enemy.is_empty() and enemy.hp < m.TYPES.heavy.hp

func _class_ups() -> void:
	# Magic bolt+: fires both ways along the chosen line.
	var m := _plus_room("magic_bolt",[Vector2i(2,0),Vector2i(2,5)])
	verify(m.use_item("magic_bolt",Vector2i(2,2),Vector2i.UP) and _hurt(m,Vector2i(2,0)) and _hurt(m,Vector2i(2,5)),"Magic bolt+ hits both ways along its line")
	# Stealth+: strikes every adjacent enemy.
	m = _plus_room("stealth_fairy",[Vector2i(2,1),Vector2i(2,3)])
	verify(m.use_item("stealth_fairy",Vector2i(2,2)) and _hurt(m,Vector2i(2,1)) and _hurt(m,Vector2i(2,3)) and m.fairies.is_empty(),"Stealth fairy+ strikes every adjacent enemy, then fades")
	# Acorn+: HP 2 and diagonal attacks.
	m = _plus_room("acorn_fairy",[Vector2i(3,3)])
	m.use_item("acorn_fairy",Vector2i(2,2))
	verify(m.allies.size() == 1 and m.allies[0].hp == 2,"Acorn+ has 2 HP")
	m.act_allies()
	verify(_hurt(m,Vector2i(3,3)),"Acorn+ attacks a diagonal neighbour")
	# Warp+: costs no AP.
	m = _plus_room("warp_fairy",[Vector2i(5,5)])
	m.player.ap = 0
	verify(m.fairy_ap_cost("warp_fairy") == 0 and m.use_item("warp_fairy",Vector2i(0,0)) and m.player.cell == Vector2i(0,0),"Warp+ works with 0 AP")
	# Wall+: two tiles in the chosen direction.
	m = _plus_room("wall_fairy",[Vector2i(5,5)])
	verify(m.is_directional("wall_fairy") and not m.use_item("wall_fairy",Vector2i(2,2)),"Wall+ asks for a direction")
	verify(m.use_item("wall_fairy",Vector2i(2,2),Vector2i.DOWN) and m.walls.has(Vector2i(2,2)) and m.walls.has(Vector2i(2,3)) and m.walls.has(Vector2i(2,4)) and m.walls.size() == 3,"Wall+ builds a three-tile line")
	# Lance cannon+: the same two volleys ahead, 0 AP to place and two per battle.
	m = _plus_room("cannon_fairy",[Vector2i(2,0),Vector2i(2,5)])
	verify(m.fairy_ap_cost("cannon_fairy") == 0 and m.fairy_charges == [2],"Lance cannon+ is free to place and comes twice")
	# Vane cannon+: two volleys, then turns.
	m = _plus_room("vane_cannon",[Vector2i(2,0),Vector2i(2,5)])
	m.use_item("vane_cannon",Vector2i(2,2),Vector2i.UP)
	verify(m.player_action(Vector2i(2,2)) and m.enemy_at(Vector2i(2,0)).is_empty() and not _hurt(m,Vector2i(2,5)) and m.cannon_at(Vector2i(2,2)).dir == Vector2i.RIGHT,"Vane cannon+ fires ahead, not behind, then turns")
	# Firework+: spares the player.
	m = _plus_room("firework_fairy",[Vector2i(3,3)])
	m.use_item("firework_fairy",Vector2i(2,2))
	var hp: int = m.player.hp
	verify(m.player_action(Vector2i(2,2)) and m.player.hp == hp and _hurt(m,Vector2i(3,3)),"Firework+ spares the player but hits enemies")
	# Capacitor+: starts with one charge, so two strikes discharge.
	m = _plus_room("capacitor_fairy",[Vector2i(2,5)])
	m.use_item("capacitor_fairy",Vector2i(2,2))
	verify(m.cannon_at(Vector2i(2,2)).charge == 1,"Capacitor+ starts with a charge")
	m.player.ap = 2
	m.player_action(Vector2i(2,2))
	m.player_action(Vector2i(2,2))
	verify(_hurt(m,Vector2i(2,5)),"Capacitor+ discharges after two strikes")
	# Class-up bookkeeping.
	m = fixture()
	m.fairy_loadout.assign(["slash_fairy","magic_bolt"])
	m.refill_fairies()
	verify(m.class_up(0) and m.fairy_loadout[0] == "slash_fairy" and m.fairy_title("slash_fairy") == "斬撃精霊+","The slash spirit's class-up is 斬撃精霊+")
	verify(m.class_up(1) and m.is_plus("magic_bolt") and m.fairy_title("magic_bolt") == "魔弾精霊+" and not m.class_up(1),"A fairy takes one class-up only")
	# Camp: forging is once per weapon; class-up picks a fairy; swapping it out loses the "+".
	var run := Run.new()
	run.start(3)
	run.choose(0)
	run.choose(0)
	run.stage = Run.LAST_NORMAL_STAGE
	run.state = Run.State.CAMP
	var first: int = run.battle.owned_weapons[0]
	run.camp_forge()
	run.camp_forge_weapon(0)
	run.state = Run.State.CAMP
	run.camp_forge()
	verify(not run.camp_forge_weapon(0) and run.battle.weapon_power[first] == 1,"A weapon can be forged only once")
	run.camp_back()
	var fairy: String = run.battle.fairy_loadout[0]
	verify(run.camp_class_up() and run.state == Run.State.CAMP_FAIRY and run.camp_class_up_fairy(0) and run.state == Run.State.BATTLE,"The camp class-up upgrades a fairy and moves on")
	verify(run.battle.is_plus(fairy) or run.battle.fairy_loadout[0] != fairy,"...and the fairy is upgraded")
	run.battle.fairy_plus["magic_bolt"] = true
	run.battle.fairy_loadout.assign(["magic_bolt"])
	run.state = Run.State.REPLACE
	run.pending = {"kind":"fairy","value":"wall_fairy"}
	run.replace(0)
	verify(not run.battle.is_plus("magic_bolt"),"Swapping out an upgraded fairy loses its class-up")

func _rare_fairies() -> void:
	# Wind axe: a 2x2 rook-style charge that drives the enemy into the wall, then vanishes.
	var m := fixture()
	m.fairy_loadout.assign(["axe_spirit"])
	m.refill_fairies()
	m.weapon = 0
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	var tough: Dictionary = m.make_enemy("heavy",Vector2i(4,2),0)
	tough.hp = 5
	m.enemies.append(tough)
	verify(m.item_targets("axe_spirit").has(Vector2i(2,2)) and m.big_anchor(Vector2i(2,2)) != Vector2i(-1,-1),"The axe fits a 2x2 block around a tile in range")
	verify(not m.use_item("axe_spirit",Vector2i(2,2)),"The axe needs a direction")
	verify(m.use_item("axe_spirit",Vector2i(2,2),Vector2i.RIGHT),"The axe charges")
	verify(tough.cell == Vector2i(m.board_size-1,2) and tough.hp == 4,"It hits for 1 and drives the enemy to the wall (a wall adds nothing)")
	verify(m.allies.is_empty() and m.events.any(func(e): return e.kind == "axe"),"The axe vanishes after its charge")
	# Holy spirit: a 2x2 ally that strikes what touches it; broken, it frees two knights.
	m = fixture()
	m.fairy_loadout.assign(["holy_spirit"])
	m.refill_fairies()
	m.weapon = 0
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	verify(m.use_item("holy_spirit",Vector2i(2,2)) and m.allies.size() == 1 and m.allies[0].type == "holy" and m.allies[0].size == 2,"The holy spirit is summoned as a 2x2 ally")
	var holy: Dictionary = m.allies[0]
	verify(m.footprint(holy).all(func(c): return m.blocked(c) and m.ally_at(c) == holy),"It blocks all four of its tiles")
	var foe: Dictionary = m.make_enemy("heavy",m.footprint(holy)[1]+Vector2i.RIGHT,0)
	m.enemies.append(foe)
	m.phase = Rules.Phase.PLAYER
	m.act_allies()
	verify(foe.hp == 1,"It strikes an enemy touching its side")
	var far: Dictionary = m.make_enemy("heavy",Vector2i(5,5),1)
	m.enemies.assign([far])
	var before: Vector2i = holy.cell
	m.phase = Rules.Phase.PLAYER
	m.act_allies()
	verify(holy.cell != before and m.footprint_distance(holy,far.cell) < 4,"With no one touching, it slides toward the nearest enemy")
	holy.hp = 0
	m._bury_allies()
	var knights: Array = m.allies.filter(func(a): return a.type == "holy_knight")
	verify(knights.size() == 2 and knights.all(func(k): return k.hp == 2 and k.ap == 2),"Broken, it frees two holy knights (HP2, AP2)")
	# Knights fight like acorns.
	var knight: Dictionary = knights[0]
	var next_to: Dictionary = m.make_enemy("heavy",knight.cell+Vector2i.UP if m.inside(knight.cell+Vector2i.UP) else knight.cell+Vector2i.DOWN,2)
	m.enemies.append(next_to)
	next_to.hp = 5
	m.phase = Rules.Phase.PLAYER
	m.act_allies()
	verify(next_to.hp <= 3,"A holy knight attacks an adjacent enemy twice a turn (AP2)")
	# The 2x2 spirits are ordinary reward fairies now (風斧 rare, 聖精霊 super rare).
	verify(Run.new().reward_fairy_pool.has("axe_spirit") and Run.new().reward_fairy_pool.has("holy_spirit"),"The axe and holy spirits are in the reward pool")

func _magic_circle() -> void:
	var m := fixture()
	# Enclosure: a diamond of four (touching diagonally) captures its centre; the edge is no wall.
	var diamond: Array = [Vector2i(3,1),Vector2i(2,2),Vector2i(4,2),Vector2i(3,3)]
	var found: Dictionary = m.circle_enclosure(diamond)
	verify(found.inside == [Vector2i(3,2)] and found.line.size() == 4,"A diagonal diamond encloses its centre")
	verify(m.circle_enclosure([Vector2i(0,2),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),Vector2i(4,2),Vector2i(5,2)]).inside.is_empty() or m.board_size > 6,"A line across the board encloses nothing (the edge is not a wall)")
	# A circle weapon: moves paint white tiles, cannot attack, and closing a shape deals 99.
	var down_right: int = Run.Weapons.DATA.map(func(w): return w.id).find("front_diagonal")
	m.owned_weapons.assign([0,1,down_right])
	m.enchants[down_right] = "circle"
	m.weapon = down_right
	m.player.cell = Vector2i(2,2)
	m.enemies.clear()
	var boss: Dictionary = m.make_enemy("heavy",Vector2i(3,2),0)
	boss.hp = 50
	m.enemies.append(boss)
	m.enemies.append(m.make_enemy("heavy",Vector2i(5,5),1))
	m.circle_tiles.assign([Vector2i(3,1),Vector2i(4,2)])
	verify(m.circle_preview(Vector2i(3,3)).has(Vector2i(3,2)),"Hovering the closing move previews the captured area")
	var blocker: Dictionary = m.make_enemy("heavy",Vector2i(3,3),2)
	m.enemies.append(blocker)
	verify(not m.player_action(Vector2i(3,3)) and blocker.hp == 2,"A circle weapon cannot attack")
	m.enemies.erase(blocker)
	verify(m.player_action(Vector2i(3,3)) and boss.hp <= 0,"Closing the circle deals 99 to what it encloses")
	verify(m.events.any(func(e): return e.kind == "circle") and not m.circle_tiles.has(Vector2i(3,1)) and not m.circle_tiles.has(Vector2i(2,2)),"The white line that closed it is used up")
	# Plain moves just paint.
	m.phase = Rules.Phase.PLAYER
	m.player.ap = 2
	m.player.cell = Vector2i(0,0)
	m.circle_tiles.clear()
	m.player_action(Vector2i(1,1))
	verify(m.circle_tiles.has(Vector2i(0,0)) and m.circle_tiles.has(Vector2i(1,1)),"A move paints where it started and where it landed")
	# Rewards: circle weapons show up now and then, and choosing one keeps the enchantment.
	var seen := 0
	for seed_value in 400:
		var run := Run.new()
		run.start(seed_value)
		run.choose(0)
		run.choose(0)
		run.battle.enemies.clear()
		run.battle.check_outcome()
		run.finish_battle()
		# (飛車槍・角剣 always carry a circle; the random one goes on simple weapons.)
		var slot: int = run.offers.find_custom(func(o): return o.get("enchant","") == "circle" and not Run.Weapons.is_late(int(o.value)))
		if slot >= 0:
			seen += 1
			verify(Run.Weapons.is_simple(int(run.offers[slot].value)),"Magic circles go only on simple weapons")
			run.choose(slot)
			if run.state == Run.State.REPLACE:
				run.replace(2)
			verify(run.battle.enchants.values().has("circle"),"A chosen circle weapon keeps its enchantment")
	verify(seen >= 3 and seen <= 25,"Circle weapons turn up in about 3%% of rewards (%d/400)" % seen)

func _weapon_room(id: String, foes: Array) -> RefCounted:
	var m := fixture()
	var index: int = Run.Weapons.DATA.map(func(w): return w.id).find(id)
	m.owned_weapons.assign([0,1,index])
	m.weapon = index
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	for k in foes.size():
		var foe: Dictionary = m.make_enemy("heavy",foes[k],k)
		foe.hp = 5
		m.enemies.append(foe)
	return m

func _mechanic_weapons() -> void:
	# 香車槍: slides right to the first enemy.
	var m := _weapon_room("lance",[Vector2i(4,2)])
	verify(m.targets() == [Vector2i(2,2),Vector2i(3,2),Vector2i(4,2)],"The lance reaches every free tile to the right and the first enemy")
	verify(m.player_action(Vector2i(4,2)) and m.enemies[0].hp == 4,"...and strikes it")
	verify(m.player_action(Vector2i(3,2)) and m.player.cell == Vector2i(3,2),"...or slides to any free tile on the way")
	# 飛車槍 and 角剣: four lines each.
	m = _weapon_room("rook_spear",[Vector2i(1,0)])
	verify(m.targets().has(Vector2i(1,0)) and not m.targets().has(Vector2i(1,-1)) and m.targets().has(Vector2i(m.board_size-1,2)) and m.targets().has(Vector2i(0,2)),"The rook spear slides along the four lines, stopping at the first enemy")
	m = _weapon_room("bishop_blade",[Vector2i(3,4)])
	verify(m.targets().has(Vector2i(2,3)) and m.targets().has(Vector2i(3,4)) and not m.targets().has(Vector2i(4,5)) and m.targets().has(Vector2i(0,1)),"The bishop blade slides along the diagonals")
	# A sliding weapon with a magic circle paints its whole path.
	m = _weapon_room("rook_spear",[])
	m.enemies.append(m.make_enemy("heavy",Vector2i(5,5),0))
	m.enchants[m.weapon] = "circle"
	m.player_action(Vector2i(4,2))
	verify([Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),Vector2i(4,2)].all(func(c): return m.circle_tiles.has(c)),"A circle rook spear paints every tile it slid over")
	# 鎖鎌: hit two tiles away and drag the enemy in.
	m = _weapon_room("sickle",[Vector2i(3,2)])
	verify(m.player_action(Vector2i(3,2)) and m.enemies[0].hp == 4 and m.enemies[0].cell == Vector2i(2,2),"The sickle hits and pulls the enemy next to the player")
	# 入替の杖: trade places, no damage; not with a 2x2.
	m = _weapon_room("swap_staff",[Vector2i(3,1)])
	verify(m.player_action(Vector2i(3,1)) and m.player.cell == Vector2i(3,1) and m.enemies[0].cell == Vector2i(1,2) and m.enemies[0].hp == 5,"The swap staff trades places without damage")
	verify(m.player.ap == 1,"An unforged swap costs 1 AP")
	# Forged: the first swap each turn is free, the next one costs AP again.
	m = _weapon_room("swap_staff",[Vector2i(3,1)])
	m.weapon_power[m.weapon] = 1
	var ap_before: int = m.player.ap
	verify(m.player_action(Vector2i(3,1)) and m.player.ap == ap_before,"A forged swap staff's first swap costs no AP")
	verify(m.player_action(Vector2i(1,2)) and m.player.cell == Vector2i(1,2) and m.player.ap == ap_before - 1,"The second swap that turn costs 1 AP")
	m.tick_walls()
	verify(m.free_swap_ready(),"The free swap comes back next turn")
	# 溜め大剣: +1 for each turn it sat unused, up to +2, back to normal after a hit.
	m = _weapon_room("charge_blade",[Vector2i(2,2)])
	m.tick_walls()
	m.tick_walls()
	m.tick_walls()
	verify(m.weapon_damage(m.weapon) == 3,"The charge blade builds up to 3 damage while unused")
	m.player_action(Vector2i(2,2))
	verify(m.enemies[0].hp == 2 and m.weapon_damage(m.weapon) == 1,"Its hit spends the charge")
	m.tick_walls()
	verify(m.weapon_damage(m.weapon) == 1,"A turn it was used in stores nothing")
	# Forged: hits for 2 and stores up to +3, so up to 5.
	m = _weapon_room("charge_blade",[Vector2i(2,2)])
	m.weapon_power[m.weapon] = 1
	for k in 5:
		m.tick_walls()
	verify(m.weapon_damage(m.weapon) == 5,"Forged, the charge blade builds up to 5")
	# Pools: the lance is a pre-boss reward, the rook and bishop mid-game drops, the staff an early reward.
	var W := Run.Weapons
	var ids: Array = W.DATA.map(func(w): return w.id)
	verify(W.is_boss_reward(ids.find("lance")) and W.late_pool().has(ids.find("rook_spear")) and W.late_pool().has(ids.find("bishop_blade")) and W.early_reward_pool().has(ids.find("swap_staff")),"New weapons sit in their reward pools")
	verify(W.DATA.size() == 46,"39 weapons plus the three generals, the king staff, the mallet, the cross hammer and the thunder blade")
	var early_ids: Array = W.early_reward_pool().map(func(i): return W.DATA[i].id)
	verify(early_ids.has("flick_down") and early_ids.has("return_goose") and not W.DATA.any(func(w): return w.id in ["tall_knight", "slant"]),"跳下剣 and 帰雁剣 replace 立桂剣 and 袈裟剣 in the early pool")
	var thunder: int = W.DATA.map(func(w): return w.id).find("thunder")
	verify(W.offsets(thunder) == [Vector2i(1,-1), Vector2i(-1,1)],"雷剣 reaches up-right and down-left")
	# 十字槌: a rare mid-game hammer that moves like the cross sword and spreads in a cross.
	var cross_hammer: int = ids.find("cross_hammer")
	verify(W.mid_pool().has(cross_hammer) and W.is_hammer(cross_hammer) and W.base_damage(cross_hammer) == 2,"The cross hammer is a mid-game hammer that hits for 2")
	verify(Run.Rarity.tier({"kind":"weapon","value":cross_hammer}) == Run.Rarity.RARE,"...and a rare one")
	var ch := _weapon_room("cross_hammer",[Vector2i(2,1),Vector2i(1,1),Vector2i(3,1),Vector2i(2,0),Vector2i(3,2)])
	verify(ch.hammer_area(Vector2i(2,1)).size() == 5,"Its blow covers the target and the four tiles around it")
	verify(ch.player_action(Vector2i(1,1)) and ch.enemy_at(Vector2i(1,1)).hp == 3 and ch.enemy_at(Vector2i(2,1)).hp == 3 and ch.enemy_at(Vector2i(3,1)).hp == 5 and ch.enemy_at(Vector2i(2,0)).hp == 5,"Striking up: 2 to the target and to its side, nothing beyond the cross")
	verify(W.base_damage(ids.find("rook_spear")) == 0 and W.base_damage(ids.find("bishop_blade")) == 0 and not W.can_forge(ids.find("rook_spear")) and not W.can_forge(ids.find("bishop_blade")),"Rook spear and bishop blade: 0 damage, cannot be forged")
	var mallet: int = ids.find("mallet")
	verify(W.early_reward_pool().has(mallet) and W.is_hammer(mallet) and W.base_damage(mallet) == 1,"The mallet: an early hammer that hits for 1")
	verify(W.mid_pool().has(ids.find("king_staff")) and W.DATA[ids.find("king_staff")].swap,"The king staff (swap on all 8 neighbours) drops after the first boss")
	m = _weapon_room("king_staff",[Vector2i(2,3)])
	verify(m.player_action(Vector2i(2,3)) and m.player.cell == Vector2i(2,3) and m.enemies[0].cell == Vector2i(1,2) and m.enemies[0].hp == 5,"The king staff trades places diagonally without damage")
	verify(["eight_knight","gold","silver"].all(func(id): return W.mid_pool().has(ids.find(id))),"The generals drop after the first boss")
	verify(W.late_pool().size() == 2 and ["rook_spear","bishop_blade"].all(func(id): return W.late_pool().has(ids.find(id))),"The rook spear and bishop blade are the late drops")
	# Sliding weapons are super rare: next to never before Rotorick, now and then after it.
	var before := 0
	var after := 0
	for seed_value in 200:
		for stage in [Rules.BOSS_LEVEL, Rules.LATE_LEVELS[0]]:
			var trial := Run.new()
			trial.start(seed_value)
			trial.stage = stage
			trial.state = Run.State.BATTLE
			trial.battle.phase = Rules.Phase.WON
			trial.finish_battle()
			var sliding: bool = trial.offers.any(func(o): return o.kind == "weapon" and W.is_late(o.value))
			verify(trial.offers.all(func(o): return o.kind != "weapon" or not W.is_late(o.value) or o.get("enchant", "") == "circle"),"Rook and bishop moves only come as magic circle weapons")
			if stage < Rules.BOSS2_LEVEL:
				before += 1 if sliding else 0
			else:
				after += 1 if sliding else 0
	verify(before < after and after > 5,"Sliding weapons turn up more after Rotorick (%d before, %d after / 200)" % [before, after])
	# Rare even then: most late rewards offer neither.
	var rare_hits := 0
	for seed_value in 100:
		var trial := Run.new()
		trial.start(seed_value)
		trial.choose(0)
		trial.choose(0)
		trial.stage = Rules.LATE_LEVELS[0]
		trial.start_battle()
		trial.battle.enemies.clear()
		trial.battle.check_outcome()
		trial.finish_battle()
		if trial.offers.any(func(o): return o.kind == "weapon" and W.is_late(o.value)):
			rare_hits += 1
	verify(rare_hits > 5 and rare_hits < 40,"The rook spear and bishop blade are rare late rewards (%d / 100)" % rare_hits)


func _capacitor() -> void:
	var m := fixture()
	m.fairy_loadout.assign(["capacitor_fairy"])
	m.refill_fairies()
	m.weapon = 0
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(2,5),0))
	m.enemies.append(m.make_enemy("recruit",Vector2i(5,2),1))
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,4),2))
	verify(Run.new().reward_fairy_pool.has("capacitor_fairy"),"The capacitor can be won as a reward")
	verify(m.use_item("capacitor_fairy",Vector2i(2,2)),"The capacitor is placed on an empty tile in range")
	var cap: Dictionary = m.cannon_at(Vector2i(2,2))
	m.player.ap = 2
	verify(m.player_action(Vector2i(2,2)) and cap.charge == 1 and m.enemy_at(Vector2i(5,2)).hp == 1,"A weapon strike stores one charge, nothing fires yet")
	verify(m.player_action(Vector2i(2,2)) and cap.charge == 2,"A second strike stores two")
	m.player.ap = 2
	verify(m.player_action(Vector2i(2,2)) and cap.charge == 0,"The third strike discharges and resets")
	verify(m.enemy_at(Vector2i(5,2)).is_empty() and m.enemy_at(Vector2i(2,5)).hp == 1,"The discharge hits every enemy on the four lines")
	verify(not m.enemy_at(Vector2i(4,4)).is_empty(),"...but not off them")
	verify(not m.cannon_at(Vector2i(2,2)).is_empty(),"It stays and can be charged again")
	# A lance cannon's shot that ends on the capacitor charges it too.
	m.place_cannon(Vector2i(2,0), Vector2i.DOWN, "lance")
	m.player.ap = 2
	m.player.cell = Vector2i(1,0)
	verify(m.player_action(Vector2i(2,0)) and cap.charge == 1,"A chained cannon shot adds a charge")

func _resonance() -> void:
	# A shot flies through other cannons, and each cannon it passes fires as well.
	var m := fixture()
	m.player.cell = Vector2i(0,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("recruit",Vector2i(4,2),0))
	m.enemies.append(m.make_enemy("recruit",Vector2i(2,5),1))
	m.place_cannon(Vector2i(1,2), Vector2i.RIGHT, "lance")
	m.place_cannon(Vector2i(2,2), Vector2i.DOWN, "lance")
	m.weapon = 0
	verify(m.player_action(Vector2i(1,2)),"Striking the first cannon fires it")
	verify(m.enemy_at(Vector2i(4,2)).is_empty(),"The shot passes through the second cannon and hits beyond it")
	verify(m.enemy_at(Vector2i(2,5)).is_empty(),"The cannon it passed resonates and fires its own way")
	verify(m.events.any(func(e): return e.kind == "resonate"),"Resonance has its own effect")
	var passed: Array = []
	verify(m.cannon_line(Vector2i(1,2), Vector2i.RIGHT, passed).has(Vector2i(3,2)) and passed.size() == 1,"The line runs through cannons")
	m.walls[Vector2i(3,2)] = 2
	verify(not m.cannon_line(Vector2i(1,2), Vector2i.RIGHT, []).has(Vector2i(4,2)),"Walls still stop a shot")

func _knockback() -> void:
	var W := Run.Weapons
	var shield: int = W.DATA.map(func(d): return d.id).find("shield")
	verify(W.early_reward_pool().has(shield) and not W.opening_pool().has(shield),"The shield drops early (not as the opening pick)")
	var m := fixture()
	m.owned_weapons.assign([0,1,shield])
	m.weapon = shield
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(2,2),0))
	verify(m.player_action(Vector2i(2,2)) and m.enemies[0].cell == Vector2i(m.board_size-1,2) and m.enemies[0].hp == 2,"A shield hit deals no damage and knocks the enemy back all the way")
	verify(not m.events.any(func(e: Dictionary) -> bool: return e.kind == "hit"),"...with no hit to show")
	m = fixture()
	m.weapon = shield
	m.owned_weapons.assign([0,1,shield])
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(2,2),0))
	m.walls[Vector2i(4,2)] = 3
	verify(m.player_action(Vector2i(2,2)) and m.enemies[0].cell == Vector2i(3,2) and m.enemies[0].hp == 2,"Knocked into a wall it just stops, unhurt")
	m = fixture()
	m.weapon = shield
	m.owned_weapons.assign([0,1,shield])
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	var front: Dictionary = m.make_enemy("heavy",Vector2i(2,2),0)
	var back: Dictionary = m.make_enemy("heavy",Vector2i(5,2),1)
	m.enemies.append(front)
	m.enemies.append(back)
	m.player_action(Vector2i(2,2))
	verify(front.cell == Vector2i(4,2) and front.hp == 1 and back.hp == 1,"Knocked into another enemy down the line, both take 1")
	verify(m.events.filter(func(e: Dictionary) -> bool: return e.kind == "hit" and e.get("bump", false)).size() == 2,"Both collision hits are marked as bumps for the board")
	m = fixture()
	m.weapon = shield
	m.owned_weapons.assign([0,1,shield])
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("recruit",Vector2i(2,2),0))
	m.mines.append(Vector2i(3,2))
	m.player_action(Vector2i(2,2))
	verify(m.enemy_at(Vector2i(3,2)).is_empty() and m.mines.is_empty(),"A shove onto a mine sets it off")
	var gale: int = W.DATA.map(func(d): return d.id).find("gale")
	m = fixture()
	m.weapon = gale
	m.owned_weapons.assign([0,1,gale])
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(2,1),0))
	m.player_action(Vector2i(2,1))
	verify(m.enemies[0].cell == Vector2i(3,0),"Gale shoves diagonally outward")
	verify(W.offsets(gale).size() == 3,"Gale is a three-tile pre-boss weapon")

func _difficulty() -> void:
	var run := Run.new()
	run.start(5)
	run.choose(0)
	run.choose(0)
	verify(run.win_heal() == 1,"Normal difficulty heals 1 per win")
	run.difficulty = 1
	verify(run.win_heal() == 0,"Higher difficulty drops the win heal")
	run.battle.player.hp = 3
	run.battle.enemies.clear()
	run.battle.check_outcome()
	run.finish_battle()
	verify(run.battle.start_hp == 3,"...so HP carries over unchanged")

func _shield_soldier() -> void:
	var m := fixture()
	m.weapon = 0
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	var guard: Dictionary = m.make_enemy("shield",Vector2i(2,2),0)
	m.enemies.append(guard)
	verify(m.player_action(Vector2i(2,2)) and guard.hp == 1 and m.events.any(func(e): return e.kind == "block"),"A shield soldier blocks a hit from directly left")
	m = fixture()
	m.owned_weapons.assign([0,1,3])
	m.weapon = 3
	m.player.cell = Vector2i(1,3)
	m.enemies.clear()
	guard = m.make_enemy("shield",Vector2i(2,2),0)
	m.enemies.append(guard)
	verify(m.player_action(Vector2i(2,2)) and m.enemy_at(Vector2i(2,2)).is_empty(),"A diagonal hit goes around the shield")
	m = fixture()
	m.player.cell = Vector2i(0,0)
	m.enemies.clear()
	guard = m.make_enemy("shield",Vector2i(4,2),0)
	m.enemies.append(guard)
	m.place_cannon(Vector2i(1,2), Vector2i.RIGHT, "lance")
	m.fire_cannon(m.cannons[0])
	verify(guard.hp == 1,"A shot flying in from the left is blocked")
	m.place_cannon(Vector2i(4,0), Vector2i.DOWN, "lance")
	m.fire_cannon(m.cannons[1])
	verify(guard.hp == 0,"A shot from above is not")
	var run := Run.new()
	run.start(3)
	for level in Rules.MID_LEVELS:
		m = Rules.new()
		m.reset(level)
		verify(m.enemies.any(func(e): return e.type == "shield"),"Mid-game fight %d has a shield soldier" % level)

func _analyst() -> void:
	var m := fixture()
	m.owned_weapons.assign([0,1,3])
	m.weapon = 0
	m.player.cell = Vector2i(1,2)
	m.enemies.clear()
	var eye: Dictionary = m.make_enemy("analyst",Vector2i(2,2),0)
	m.enemies.append(eye)
	verify(m.player_action(Vector2i(2,2)) and eye.hp == 1 and eye.learned == 0,"The first hit lands and the analyst learns that weapon")
	verify(m.player_action(Vector2i(2,2)) and eye.hp == 1 and m.events.any(func(e): return e.kind == "analyzed"),"The same weapon then does nothing")
	m.player.ap = 2
	m.player.cell = Vector2i(1,3)
	m.weapon = 3
	verify(m.player_action(Vector2i(2,2)) and m.enemy_at(Vector2i(2,2)).is_empty(),"A different weapon finishes it")
	m = fixture()
	m.enemies.clear()
	eye = m.make_enemy("analyst",Vector2i(3,2),0)
	m.enemies.append(eye)
	m.fairy_loadout.assign(["magic_bolt"])
	m.refill_fairies()
	eye.learned = 0
	m.weapon = 0
	m.use_item("magic_bolt",Vector2i(2,2),Vector2i.RIGHT)
	verify(eye.hp == 1,"Fairies are never analysed")
	for level in [4, 6]:
		m = Rules.new()
		m.reset(level)
		verify(m.enemies.any(func(e): return e.type == "analyst"),"Mid-game fight %d has an analyst" % level)

func _loner_fairies() -> void:
	# 影縫い精霊: only on tiles no carried weapon reaches; clicking it swaps for 0 AP, once a turn.
	var m := fixture()
	m.fairy_loadout.assign(["shadow_stitch"])
	m.refill_fairies()
	var reach: Array = m.all_reach()
	var spots: Array = m.item_targets("shadow_stitch")
	verify(not spots.is_empty() and spots.all(func(c): return not reach.has(c) and c != m.player.cell),"The shadow only goes where no carried weapon reaches")
	var spot: Vector2i = spots[0]
	var start: Vector2i = m.player.cell
	verify(m.use_item("shadow_stitch",spot) and m.player.ap == 2 and m.blocked(spot),"Pinning the shadow costs no AP and takes the tile")
	verify(m.player_action(spot) and m.player.cell == spot and m.shadow.cell == start and m.player.ap == 2,"Clicking the shadow swaps places for 0 AP")
	verify(not m.can_swap_shadow(start) and not m.player_action(start),"Only one swap a turn")
	m.tick_walls()
	verify(m.can_swap_shadow(start) and m.shadow.turns == Rules.WALL_TURNS - 1,"The swap comes back next turn while the shadow counts down")
	for k in Rules.WALL_TURNS - 1:
		m.tick_walls()
	verify(m.shadow.is_empty() and not m.blocked(start),"The shadow fades after five turns")
	# Class-up: arriving hits every enemy beside the landing tile.
	m = fixture()
	m.fairy_plus["shadow_stitch"] = true
	m.place_shadow(spot)
	var foe: Dictionary = {}
	for direction in Rules.CARDINALS:
		var cell: Vector2i = spot + direction
		if m.inside(cell) and cell != m.player.cell and not m.blocked(cell) and m.enemy_at(cell).is_empty():
			m.enemies.clear()
			foe = m.make_enemy("heavy",cell,0)
			foe.hp = 5
			m.enemies.append(foe)
			break
	verify(not foe.is_empty() and m.player_action(spot) and foe.hp == 4,"The upgraded shadow hits its neighbours on arrival")
	# 一匹狼の妖精: a lasting ally placed out of reach; it hunts alone and sulks within reach.
	m = fixture()
	m.fairy_loadout.assign(["lone_wolf"])
	m.refill_fairies()
	m.enemies.clear()
	reach = m.all_reach()
	var wolf_spots: Array = m.item_targets("lone_wolf")
	verify(not wolf_spots.is_empty() and wolf_spots.all(func(c): return not reach.has(c)),"The wolf is placed only where no weapon reaches")
	# A tile out of reach with room for a silver step right and prey up-right of that.
	var home := Vector2i(-1,-1)
	for cell in wolf_spots:
		var step: Vector2i = cell + Vector2i(1,0)
		var far: Vector2i = cell + Vector2i(2,-1)
		if home == Vector2i(-1,-1) and m.inside(step) and m.inside(far) and not reach.has(step) and not m.blocked(step) and not m.blocked(far) and m.distance(step, m.player.cell) > 1 and far != m.player.cell and m.enemy_at(cell + Vector2i(1,-1)).is_empty() and m.enemy_at(cell + Vector2i(1,1)).is_empty():
			home = cell
	verify(home != Vector2i(-1,-1),"Found room for the wolf")
	if home == Vector2i(-1,-1):
		return
	var prey: Dictionary = m.make_enemy("heavy",home + Vector2i(2,-1),0)
	prey.hp = 5
	m.enemies.append(prey)
	verify(m.use_item("lone_wolf",home) and m.allies.size() == 1 and m.allies[0].type == "wolf","The wolf joins as an ally")
	var wolf: Dictionary = m.allies[0]
	verify(wolf.hp == 3 and Rules.WOLF_AP == 3,"The lone wolf has HP 3 and AP 3")
	m.act_allies()
	verify(wolf.cell == home + Vector2i(1,0) and prey.hp == 1,"Alone, it takes a silver step and bites twice for 2 (3 AP)")
	m.tick_walls()
	verify(m.allies.size() == 1,"The wolf does not fade with the turn count")
	var crowd: Vector2i = Vector2i(-1,-1)
	for direction in Rules.CARDINALS:
		var cell: Vector2i = wolf.cell + direction
		if crowd == Vector2i(-1,-1) and m.inside(cell) and not m.blocked(cell) and cell != m.player.cell and m.enemy_at(cell).is_empty() and m.distance(cell, prey.cell) > 1:
			crowd = cell
	prey.hp = 5
	m.allies.append({"id":-50, "type":"holy_knight", "cell":crowd, "hp":1, "ap":0, "facing":2})
	m.act_allies()
	verify(prey.hp == 2,"With company beside it, each bite drops to 1")
	m.allies = m.allies.filter(func(a): return a.type == "wolf")
	# Class-up: a kill gives the AP back, so it can finish a second enemy.
	for plus in [false, true]:
		m.enemies.clear()
		wolf.cell = home
		wolf.plus = plus
		var a: Dictionary = m.make_enemy("heavy",home + Vector2i(1,-1),0)
		var b: Dictionary = m.make_enemy("heavy",home + Vector2i(1,1),1)
		a.hp = 4
		b.hp = 4
		m.enemies.append_array([a, b])
		m.act_allies()
		var dead: int = [a, b].filter(func(e): return e.hp <= 0).size()
		verify(dead == (2 if plus else 1),"%s wolf finishes %d of two HP4 enemies" % ["A classed-up" if plus else "A plain", dead])
	wolf.plus = false
	m.phase = Rules.Phase.PLAYER
	m.enemies.clear()
	prey = m.make_enemy("heavy",home + Vector2i(1,-1),0)
	prey.hp = 5
	m.enemies.append(prey)
	for y in m.board_size:
		for x in m.board_size:
			if not m.all_reach().has(wolf.cell) and Vector2i(x,y) != wolf.cell and not m.blocked(Vector2i(x,y)) and m.enemy_at(Vector2i(x,y)).is_empty():
				m.player.cell = Vector2i(x,y)
	verify(m.all_reach().has(wolf.cell),"The player can stand where a weapon reaches the wolf")
	m.act_allies()
	verify(prey.hp == 5 and wolf.sulking,"Within any weapon's reach, the wolf sulks and skips its turn")
	# A charge crashes into the pinned shadow like any placed thing: smashed, and it stops there.
	m = fixture()
	m.enemies.clear()
	var rook: Dictionary = m.make_enemy("rook",Vector2i(4,2),0)
	rook.facing = 3
	rook.state = "brace"
	m.enemies.append(rook)
	m.player.cell = Vector2i(0,5)
	m.place_shadow(Vector2i(2,2))
	var lane: Array = m.rook_lane(rook)
	verify(lane.has(Vector2i(3,2)) and not lane.has(Vector2i(2,2)) and not lane.has(Vector2i(1,2)),"The charge lane stops at the shadow")
	m.phase = Rules.Phase.ENEMY
	verify(m.rook_charge(rook) and m.shadow.is_empty() and rook.cell == Vector2i(3,2),"The charge smashes the shadow and stops in front of it")
	verify(m.events.any(func(e): return e.kind == "charge_end" and e.cell == rook.cell),"Each charge marks where it ended")
	# Charging at the player, the rook drives enemies in the way ahead of it along with the player.
	m = fixture()
	m.enemies.clear()
	rook = m.make_enemy("rook",Vector2i(4,2),0)
	rook.facing = 3
	rook.state = "brace"
	m.enemies.append(rook)
	var wedge: Dictionary = m.make_enemy("heavy",Vector2i(3,2),1)
	m.enemies.append(wedge)
	m.player.cell = Vector2i(1,2)
	m.player.hp = 5
	m.phase = Rules.Phase.ENEMY
	m.rook_charge(rook)
	verify(rook.cell == Vector2i(2,2) and wedge.cell == Vector2i(1,2) and m.player.cell == Vector2i(0,2) and m.player.hp == 4,"The rook plows the enemy and the player to the wall, hitting the player once")
	# Not charging at the player (a dodge), an enemy in the way still stops it.
	m = fixture()
	m.enemies.clear()
	rook = m.make_enemy("rook",Vector2i(4,2),0)
	rook.facing = 3
	rook.state = "brace"
	m.enemies.append(rook)
	wedge = m.make_enemy("heavy",Vector2i(2,2),1)
	m.enemies.append(wedge)
	m.player.cell = Vector2i(0,5)
	m.phase = Rules.Phase.ENEMY
	m.rook_charge(rook)
	verify(rook.cell == Vector2i(3,2) and wedge.cell == Vector2i(2,2),"Without the player in the lane, enemies still block the charge")

func _optional_rules() -> void:
	# All three rules are off by default.
	var m := fixture()
	verify(not m.rule_siege and not m.rule_friendly and not m.rule_combo,"Optional rules start off")
	# A: every 4 rounds the next ring closes; whoever stands inside takes 1 at the enemy turn.
	m.rule_siege = true
	m.enemies.clear()
	var edge: Dictionary = m.make_enemy("heavy",Vector2i(0,0),0)
	edge.hp = 5
	var inner: Dictionary = m.make_enemy("heavy",Vector2i(3,3),1)
	inner.hp = 5
	m.enemies.append_array([edge, inner])
	m.player.cell = Vector2i(0,2)
	m.player.hp = 5
	m.round_number = 3
	verify(m.siege_countdown() == 1 and not m.siege_warning(Vector2i(0,2)),"The siege counts down before it closes")
	m.round_number = 4
	verify(m.siege_countdown() == 0 and m.siege_warning(Vector2i(0,2)) and not m.siege_warning(Vector2i(2,2)),"The ring about to close is flagged on the edge")
	var planner = Planner.new()
	planner.begin(m)
	verify(m.siege_rings == 1 and m.player.hp == 4 and edge.hp == 4 and inner.hp == 5,"The outer ring closes and burns the player and the enemy on it, not the inner one")
	m.siege_tick()
	verify(m.player.hp == 3,"Staying inside the siege hurts every enemy turn")
	m.siege_rings = m.siege_max()
	m.round_number = 8
	m.siege_tick()
	verify(m.siege_rings == m.siege_max(),"A centre is always left open")
	# B: a dodged charge slams the enemy that stops it; a ramming charge crushes enemies pinned to the wall.
	m = fixture()
	m.rule_friendly = true
	m.enemies.clear()
	var rook: Dictionary = m.make_enemy("rook",Vector2i(4,2),0)
	rook.facing = 3
	rook.state = "brace"
	var wedge: Dictionary = m.make_enemy("heavy",Vector2i(2,2),1)
	wedge.hp = 5
	m.enemies.append_array([rook, wedge])
	m.player.cell = Vector2i(0,5)
	m.phase = Rules.Phase.ENEMY
	m.rook_charge(rook)
	verify(wedge.hp == 4,"Rule B: the charge slams the enemy in its way")
	m = fixture()
	m.rule_friendly = true
	m.enemies.clear()
	rook = m.make_enemy("rook",Vector2i(4,2),0)
	rook.facing = 3
	rook.state = "brace"
	wedge = m.make_enemy("heavy",Vector2i(3,2),1)
	wedge.hp = 5
	m.enemies.append_array([rook, wedge])
	m.player.cell = Vector2i(1,2)
	m.phase = Rules.Phase.ENEMY
	m.rook_charge(rook)
	verify(wedge.hp == 4 and m.player.hp == 4,"Rule B: the enemy pinned between the rook and the player is crushed too")
	# C: one action felling two enemies gives 1 AP back.
	for combo in [false, true]:
		m = fixture()
		m.rule_combo = combo
		m.fairy_loadout.assign(["magic_bolt"])
		m.refill_fairies()
		m.weapon = 0
		m.player.cell = Vector2i(1,1)
		m.enemies.clear()
		m.enemies.append(m.make_enemy("recruit",Vector2i(2,2),0))
		m.enemies.append(m.make_enemy("recruit",Vector2i(2,3),1))
		m.enemies.append(m.make_enemy("heavy",Vector2i(5,5),2))
		verify(m.use_item("magic_bolt",Vector2i(2,1),Vector2i.DOWN) and m.enemies.size() == 1,"The bolt fells both enemies (combo %s)" % combo)
		verify(m.player.ap == (2 if combo else 1),"Rule C refunds 1 AP only when it is on (combo %s)" % combo)

func _generals() -> void:
	# Gold: every neighbour but the two back diagonals (front = left). Silver: front three and back diagonals.
	var m := fixture()
	m.enemies.clear()
	var gold: Dictionary = m.make_enemy("gold",Vector2i(3,2),0)
	var silver: Dictionary = m.make_enemy("silver",Vector2i(3,4),1)
	m.enemies.append_array([gold, silver])
	verify(m.enemy_offsets(gold).size() == 6 and not m.enemy_offsets(gold).has(Vector2i(1,-1)) and not m.enemy_offsets(gold).has(Vector2i(1,1)) and m.enemy_offsets(gold).has(Vector2i(1,0)),"Gold moves like a shogi gold facing left")
	verify(m.enemy_offsets(silver).size() == 5 and not m.enemy_offsets(silver).has(Vector2i(0,1)) and not m.enemy_offsets(silver).has(Vector2i(1,0)) and m.enemy_offsets(silver).has(Vector2i(1,1)),"Silver moves like a shogi silver facing left")
	verify(gold.hp == 2 and gold.ap == 1 and silver.hp == 1 and silver.ap == 2,"Gold is sturdy (HP2 AP1), silver quick (HP1 AP2)")
	# Standing on a back diagonal of the gold is safe; standing in front of it is not.
	m.player.cell = Vector2i(4,1)
	m.player.hp = 5
	_enemy_turn(m)
	verify(m.player.hp == 5,"The gold cannot strike its back diagonal")
	m = fixture()
	m.enemies.clear()
	gold = m.make_enemy("gold",Vector2i(3,2),0)
	m.enemies.append(gold)
	m.player.cell = Vector2i(2,1)
	m.player.hp = 5
	_enemy_turn(m)
	verify(m.player.hp == 4,"The gold strikes its front diagonal")
	# The silver closes in over its own moves and strikes.
	m = fixture()
	m.enemies.clear()
	silver = m.make_enemy("silver",Vector2i(4,4),0)
	m.enemies.append(silver)
	m.player.cell = Vector2i(1,2)
	m.player.hp = 5
	_enemy_turn(m)
	verify(m.distance(silver.cell, m.player.cell) < 5,"The silver advances using its own moves")
	# Placed in the mid and late fights.
	var seen: Array = []
	for level in Rules.MID_LEVELS + Rules.LATE_LEVELS:
		m.reset(level)
		for e in m.enemies:
			if e.type in Rules.GENERALS and not seen.has(e.type):
				seen.append(e.type)
		verify(m.enemies.all(func(e): return m.footprint(e).all(func(c): return m.inside(c) and c != m.player.cell)),"Placements with generals stay valid (level %d)" % level)
	verify(seen.has("gold") and seen.has("silver"),"Gold and silver generals appear in the mid and late fights")

func _abyss() -> void:
	# 奈落の精霊: called on the player's own tile; every empty tile out of reach becomes a pit.
	var m := fixture()
	var ids: Array = Run.Weapons.DATA.map(func(w): return w.id)
	var shield: int = ids.find("shield")
	m.owned_weapons.assign([shield, 1, 2])
	m.weapon = shield
	m.fairy_loadout.assign(["abyss_spirit"])
	m.refill_fairies()
	m.enemies.clear()
	var foe: Dictionary = m.make_enemy("heavy",Vector2i(2,2),0)
	foe.hp = 5
	m.enemies.append(foe)
	m.enemies.append(m.make_enemy("heavy",Vector2i(5,5),1))
	verify(m.item_targets("abyss_spirit") == [m.player.cell],"The abyss is called on the player's own tile")
	verify(m.use_item("abyss_spirit",m.player.cell) and m.player.ap == 1 and m.abyss_turns == Rules.WALL_TURNS,"Calling it costs 1 AP and lasts five turns")
	var reach: Array = m.all_reach()
	verify(not m.pits.is_empty() and m.pits.all(func(c): return not reach.has(c)) and not m.pits.has(foe.cell) and m.pits.has(Vector2i(3,2)),"Every empty tile out of reach is a pit; enemies' tiles are spared")
	verify(m.blocked(Vector2i(3,2)),"Pits block walking")
	# Shoved into a pit, a small enemy falls whatever its HP.
	verify(m.player_action(Vector2i(2,2)) and m.enemy_at(Vector2i(2,2)).is_empty() and m.enemy_at(Vector2i(3,2)).is_empty() and m.enemies.size() == 1,"A shield shove drops the enemy into the abyss")
	# Moving re-digs around the new position.
	m.player.ap = 2
	m.player_action(Vector2i(2,2))
	reach = m.all_reach()
	verify(m.pits.all(func(c): return not reach.has(c)) and not m.pits.has(m.player.cell),"Pits follow the player's reach after a move")
	# A 2x2 charger does not fall: stumbling over a pit costs it 2.
	var rm := fixture()
	rm.enemies.clear()
	var rook: Dictionary = rm.make_enemy("rook",Vector2i(4,2),0)
	rook.facing = 3
	rook.state = "brace"
	rook.hp = 5
	rm.enemies.append(rook)
	rm.player.cell = Vector2i(0,5)
	rm.abyss_turns = 3
	rm.pits.append(Vector2i(3,2))
	rm.phase = Rules.Phase.ENEMY
	rm.rook_charge(rook)
	verify(rook.hp == 3 and not rm.pits.has(Vector2i(3,2)),"A charging rook stumbles over the pit for 2 and fills it")
	# The abyss closes after five turns.
	for k in Rules.WALL_TURNS - 1:
		m.tick_walls()
	verify(m.abyss_turns == 1 and not m.pits.is_empty(),"The abyss stays open until its last turn")
	m.tick_walls()
	verify(m.abyss_turns == 0 and m.pits.is_empty(),"...and then closes")

func _gravity() -> void:
	# Outside the weapon's range it pulls enemies within 2 tiles one step in, without damage.
	var m := fixture()
	m.weapon = 0
	m.player.cell = Vector2i(0,0)
	m.fairy_loadout.assign(["gravity_fairy"])
	m.refill_fairies()
	m.enemies.clear()
	var far: Dictionary = m.make_enemy("heavy",Vector2i(4,2),0)
	var corner: Dictionary = m.make_enemy("heavy",Vector2i(4,4),1)
	var outside: Dictionary = m.make_enemy("heavy",Vector2i(5,5),2)
	m.enemies.append_array([far, corner, outside])
	verify(m.item_targets("gravity_fairy").has(Vector2i(4,0)) and m.gravity_pulls(Vector2i(2,2)) and not m.gravity_pulls(Vector2i(1,0)),"It goes on any empty tile; outside the weapon's range it pulls, inside it pushes")
	verify(m.use_item("gravity_fairy",Vector2i(2,2)) and far.cell == Vector2i(3,2) and corner.cell == Vector2i(3,3) and outside.cell == Vector2i(5,5),"Pull: enemies within 2 tiles step one tile in; farther ones stay")
	verify(far.hp == 2 and corner.hp == 2,"Pulling deals no damage")
	# Inside the range it blows the eight neighbours one tile away, also without damage.
	m = fixture()
	m.weapon = 0
	m.player.cell = Vector2i(2,3)
	m.fairy_loadout.assign(["gravity_fairy"])
	m.refill_fairies()
	m.enemies.clear()
	var east: Dictionary = m.make_enemy("heavy",Vector2i(4,3),0)
	var south: Dictionary = m.make_enemy("heavy",Vector2i(3,4),1)
	var wall: Dictionary = m.make_enemy("heavy",Vector2i(5,2),2)
	m.enemies.append_array([east, south, wall])
	verify(m.use_item("gravity_fairy",Vector2i(3,3)) and east.cell == Vector2i(5,3) and south.cell == Vector2i(3,5),"Push: the neighbours are blown a tile away")
	var blocked_one: Dictionary = m.enemies.filter(func(e): return e.id == 2)[0]
	verify(east.hp == 2 and south.hp == 2 and blocked_one.hp == 2,"Blowing deals no damage, even when something is in the way")
	# A pull into the abyss still drops the enemy.
	m = fixture()
	m.weapon = 0
	m.player.cell = Vector2i(0,0)
	m.enemies.clear()
	var faller: Dictionary = m.make_enemy("heavy",Vector2i(4,2),0)
	m.enemies.append_array([faller, m.make_enemy("heavy",Vector2i(0,5),1)])
	m.pits.append(Vector2i(3,2))
	m.gravity(Vector2i(2,2))
	verify(m.enemies.size() == 1,"Pulled over a pit, an enemy falls in")

func _glutton() -> void:
	# A summoned ally with gold moves (front = right) that bites whatever is nearest.
	var m := fixture()
	m.weapon = 0
	m.player.cell = Vector2i(1,1)
	m.fairy_loadout.assign(["glutton_fairy"])
	m.refill_fairies()
	m.enemies.clear()
	var snack: Dictionary = m.make_enemy("heavy",Vector2i(3,1),0)
	snack.hp = 5
	m.enemies.append_array([snack, m.make_enemy("heavy",Vector2i(5,5),1)])
	verify(m.use_item("glutton_fairy",Vector2i(2,1)) and m.allies.size() == 1 and m.allies[0].type == "glutton" and m.allies[0].hp == 1,"The glutton is summoned in weapon range as an HP1 ally")
	var glutton: Dictionary = m.allies[0]
	# The enemy (1 away) and the player (1 away) are both in reach: the player comes first.
	m.player.hp = 5
	m.act_allies()
	verify(m.player.hp == 0 and glutton.hp == 2 and m.phase == Rules.Phase.LOST,"On a tie it bites the player first, for 99 like the magic circle")
	verify(m.events.any(func(e): return e.kind == "hit" and e.id == -1 and e.get("damage", 0) == Rules.CIRCLE_DAMAGE),"The bite carries its 99 for the popup")
	# With the player out of reach it swallows 1x1 enemies whole (2x2 bosses do not fit).
	m = fixture()
	m.player.cell = Vector2i(0,5)
	m.enemies.clear()
	var rook: Dictionary = m.make_enemy("rook",Vector2i(3,1),0)
	var heavy: Dictionary = m.make_enemy("heavy",Vector2i(2,0),1)
	heavy.hp = 5
	m.enemies.append_array([rook, heavy, m.make_enemy("heavy",Vector2i(5,5),2)])
	m.summon_glutton(Vector2i(2,1))
	glutton = m.allies[0]
	m.act_allies()
	verify(rook.hp > 0 and heavy.hp <= 0 and glutton.hp == 2,"It eats a 1x1 enemy but a 2x2 boss is too big for it")
	# It bites other allies too.
	m = fixture()
	m.player.cell = Vector2i(0,5)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(5,5),0))
	m.summon_acorn(Vector2i(3,2))
	m.summon_glutton(Vector2i(2,2))
	var acorn: Dictionary = m.allies[0]
	m.act_allies()
	verify(acorn.hp <= 0 or not m.allies.has(acorn),"It swallows an ally next to it")
	# The player gets a warning when it is about to bite them.
	m = fixture()
	m.player.cell = Vector2i(1,1)
	m.enemies.clear()
	m.enemies.append(m.make_enemy("heavy",Vector2i(5,5),0))
	m.summon_glutton(Vector2i(2,1))
	verify(ThreatPreview.attackers(m).has(m.allies[0].id),"A glutton about to bite the player is flagged like an attacker")
	verify(Run.new().reward_fairy_pool.has("glutton_fairy"),"The glutton is in the reward pool")

func _prison_king() -> void:
	var m := Rules.new()
	m.reset(Rules.FINAL_LEVEL)
	m.phase = Rules.Phase.PLAYER
	var king: Dictionary = m.enemies.filter(func(e): return e.type == "king")[0]
	var forts: Array = m.enemies.filter(func(e): return e.type == "fortress")
	verify(king.size == 3 and king.hp == 10 and forts.size() == 2 and forts.all(func(f): return f.hp == 3),"The final room: a 3x3 king (HP10) and two fortresses (HP3)")
	# The pawn wall: a full column of soldiers stands in front of the king.
	var wall_x := 5
	verify(range(10).all(func(y): return not m.enemy_at(Vector2i(wall_x, y)).is_empty()),"A full wall of soldiers blocks the way to the king")
	# Fallen soldiers are remembered in order and raised one a turn, next to the king, nearest the player.
	var first: Dictionary = m.enemy_at(Vector2i(5,0))
	var second: Dictionary = m.enemy_at(Vector2i(5,3))
	first.hp = 0
	m.check_outcome()
	second.hp = 0
	m.check_outcome()
	verify(m.fallen == [first.type, second.type],"The king remembers the fallen in order")
	var before: int = m.enemies.size()
	m.phase = Rules.Phase.ENEMY
	m.round_number = 1
	m.king_turn(king)
	verify(m.enemies.size() == before and m.fallen.size() == 2,"He rests every other turn")
	m.round_number = 2
	m.king_turn(king)
	verify(m.enemies.size() == before + 1 and m.fallen == [second.type],"He raises one every other turn, the first to fall")
	var raised: Dictionary = m.enemies[-1]
	verify(raised.type == first.type and m.ring_of(king).has(raised.cell),"It rises right next to the king")
	# Fortresses send one soldier a turn and burst into two when broken.
	before = m.enemies.size()
	m.fortress_turn(forts[0])
	verify(m.enemies.size() == before + 1 and Rules.SOLDIERS.has(m.enemies[-1].type),"A fortress sends out one random soldier")
	before = m.enemies.size()
	forts[1].hp = 0
	m.check_outcome()
	verify(m.enemies.size() == before - 1 and not m.enemies.has(forts[1]),"A broken fortress just crumbles (no soldiers)")
	verify(m.ruins.has(forts[1].cell),"A broken fortress leaves rubble behind")
	# Enraged at half HP: each fortress sends out two a turn.
	verify(not m.king_enraged(),"Not enraged at full health")
	king.hp = Rules.KING_RAGE_HP
	m.check_outcome()
	verify(m.king_enraged() and king.enraged,"At half HP the king is enraged")
	verify(m.events.any(func(e): return e.kind == "king_rage"),"Enraging raises the rage cinematic")
	before = m.enemies.size()
	m.round_number += 2
	m.fortress_turn(forts[0])
	verify(m.enemies.size() == before + 2,"An enraged king's fortress sends out two")
	king.hp = 10
	# Rooted: shoves and blasts do not move them.
	var cell: Vector2i = king.cell
	m.knock_back(king, Vector2i.RIGHT, 1)
	verify(king.cell == cell and king.hp == 10,"The king cannot be shoved (and, like a wall, takes nothing from it)")
	# He never attacks: standing right next to him is safe from the king himself.
	m.player.cell = king.cell + Vector2i(-1, 1)
	m.player.hp = 5
	m.fallen.clear()
	m.king_turn(king)
	verify(m.player.hp == 5 and king.cell == cell,"The king neither attacks nor moves")
	# His fall is announced once, for the finale.
	m.events.clear()
	king.hp = 0
	m.check_outcome()
	verify(m.phase == Rules.Phase.WON and m.events.filter(func(e): return e.kind == "king_fall").size() == 1,"The king's fall wins and raises the finale once")
