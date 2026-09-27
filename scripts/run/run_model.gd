extends RefCounted

const Battle = preload("res://scripts/battle_model.gd")
const Weapons = preload("res://scripts/run/weapon_catalog.gd")
enum State { START_WEAPON, START_FAIRY, BATTLE, REWARD, REPLACE, CAMP, CAMP_FORGE, FINISHED, LOST }
## Normal fights before the camp; the boss follows the camp.
const LAST_NORMAL_STAGE := 2
const CAMP_HEAL := 2
## Every win heals a little so a long expedition stays survivable.
const WIN_HEAL := 1
var state: State = State.START_WEAPON
var battle := Battle.new()
var stage := 0
var offers: Array[Dictionary] = []
## Opening offers are rolled once so going back does not reroll them.
var start_weapon_offers: Array[Dictionary] = []
var start_fairy_offers: Array[Dictionary] = []
var pending: Dictionary = {}
var rng := RandomNumberGenerator.new()
## Forces the first boss room (0: horses, 1: rook + moving prison); -1 draws it at random.
var boss_choice := -1
# Expand these pools to introduce additional resource-defined fairy effects.
var starting_fairy_pool: Array[String] = ["magic_bolt","stealth_fairy","acorn_fairy"]
var reward_fairy_pool: Array[String] = ["magic_bolt","stealth_fairy","acorn_fairy","warp_fairy","wall_fairy","cannon_fairy","vane_cannon","firework_fairy","slash_fairy","capacitor_fairy"]

func start(seed_value: int = -1) -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	stage = 0
	state = State.START_WEAPON
	pending.clear()
	battle.reset()
	battle.owned_weapons.assign([0,1])
	battle.fairy_loadout.clear()
	battle.fairy_charges.clear()
	battle.inventory.clear()
	offers.clear()
	start_weapon_offers.clear()
	start_fairy_offers.clear()
	for index in sample(Weapons.opening_pool(), Weapons.START_CHOICE_COUNT):
		start_weapon_offers.append({"kind":"weapon", "value":index})
	for id in sample(starting_fairy_pool,3):
		start_fairy_offers.append({"kind":"fairy","value":id})
	offers.assign(start_weapon_offers)

## From the fairy pick back to the weapon pick, keeping the same offers.
func back_to_weapon() -> void:
	if state != State.START_FAIRY:
		return
	battle.owned_weapons.assign([0,1])
	state = State.START_WEAPON
	offers.assign(start_weapon_offers)

func sample(pool: Array, count: int) -> Array:
	var candidates := pool.duplicate()
	var result: Array = []
	while result.size() < count and not candidates.is_empty():
		var index := rng.randi_range(0,candidates.size()-1)
		result.append(candidates.pop_at(index))
	return result

func choose(index: int) -> bool:
	if state not in [State.START_WEAPON,State.START_FAIRY,State.REWARD] or index < 0 or index >= offers.size():
		return false
	var offer: Dictionary = offers[index]
	if state == State.START_WEAPON:
		battle.owned_weapons.append(int(offer.value))
		state = State.START_FAIRY
		offers.assign(start_fairy_offers)
	elif state == State.START_FAIRY:
		battle.add_item(str(offer.value))
		start_battle()
	else:
		var full: bool = battle.owned_weapons.size() >= Battle.WEAPON_LIMIT if offer.kind == "weapon" else battle.fairy_loadout.size() >= Battle.HAND_LIMIT
		if full:
			pending = offer.duplicate()
			state = State.REPLACE
		else:
			if offer.kind == "weapon":
				battle.owned_weapons.append(int(offer.value))
			else:
				battle.add_item(str(offer.value))
			advance()
	return true

func start_battle() -> void:
	battle.reset(stage,true)
	state = State.BATTLE

func finish_battle() -> bool:
	if state != State.BATTLE or not battle.terminal():
		return false
	if battle.phase == Battle.Phase.LOST:
		state = State.LOST
		return true
	# HP carries over to the next fight, plus a small heal for the win.
	battle.start_hp = mini(Battle.MAX_HP, battle.player.hp + WIN_HEAL)
	battle.refill_fairies()
	if stage == Battle.LAST_LEVEL:
		state = State.FINISHED
		return true
	state = State.REWARD
	offers.clear()
	var weapons: Array = []
	var single_only := stage < Weapons.SINGLE_TILE_STAGES
	var mid := stage >= Battle.BOSS_LEVEL
	# The last fight before a boss pays better: only three-tile weapons.
	var before_boss := is_before_boss()
	for index in range(Weapons.DATA.size()):
		if battle.owned_weapons.has(index) or Weapons.horizontal_only(index) or (Weapons.is_mid(index) and not mid):
			continue
		if before_boss:
			if Weapons.offsets(index).size() != 3:
				continue
		elif single_only and not Weapons.early_reward_pool().has(index):
			continue
		weapons.append(index)
	# After the first boss, one weapon slot is a mid-game drop (hammer, bow) when one is left.
	var drops: Array = Weapons.mid_pool().filter(func(index: int) -> bool: return not battle.owned_weapons.has(index))
	if mid and not drops.is_empty():
		var drop: int = sample(drops,1)[0]
		offers.append({"kind":"weapon","value":drop})
		weapons.erase(drop)
		for index in sample(weapons,1):
			offers.append({"kind":"weapon","value":index})
	else:
		for index in sample(weapons,2):
			offers.append({"kind":"weapon","value":index})
	var fairy_candidates: Array = reward_fairy_pool.filter(func(id: String) -> bool: return not battle.fairy_loadout.has(id))
	# A full loadout may leave only one new fairy: owned fairies become valid swaps.
	if fairy_candidates.size() < 2:
		fairy_candidates = reward_fairy_pool.duplicate()
	for id in sample(fairy_candidates,2):
		offers.append({"kind":"fairy","value":id})
	return true

## True on the reward right before a camp and its boss.
func is_before_boss() -> bool:
	return stage == LAST_NORMAL_STAGE or stage == Battle.MID_LEVELS[-1]

func replace(slot: int) -> bool:
	if state != State.REPLACE:
		return false
	if pending.kind == "weapon":
		if slot < 0 or slot >= battle.owned_weapons.size():
			return false
		battle.owned_weapons[slot] = int(pending.value)
	else:
		if slot < 0 or slot >= battle.fairy_loadout.size():
			return false
		var id := str(pending.value)
		battle.fairy_loadout[slot] = id
	pending.clear()
	advance()
	return true

func cancel_replace() -> void:
	if state == State.REPLACE:
		pending.clear()
		state = State.REWARD

func skip_reward() -> void:
	if state == State.REWARD:
		advance()

func advance() -> void:
	battle.refill_fairies()
	if stage == LAST_NORMAL_STAGE:
		# The boss room is drawn on arriving at the camp, so the camp can name it.
		battle.boss_variant = boss_choice if boss_choice >= 0 else rng.randi_range(0, Battle.BOSS_FORMATIONS.size() - 1)
		state = State.CAMP
	elif stage == Battle.MID_LEVELS[-1]:
		# Mid-game camp before Rotorick.
		state = State.CAMP
	else:
		stage += 1
		start_battle()

# --- camp -----------------------------------------------------------------

func camp_rest() -> bool:
	if state != State.CAMP:
		return false
	battle.start_hp = mini(Battle.MAX_HP, battle.start_hp + CAMP_HEAL)
	_leave_camp()
	return true

func camp_forge() -> bool:
	if state != State.CAMP:
		return false
	state = State.CAMP_FORGE
	offers.clear()
	for index in battle.owned_weapons:
		offers.append({"kind":"weapon", "value":index})
	return true

func camp_forge_weapon(slot: int) -> bool:
	if state != State.CAMP_FORGE or slot < 0 or slot >= battle.owned_weapons.size():
		return false
	var index: int = battle.owned_weapons[slot]
	battle.weapon_power[index] = int(battle.weapon_power.get(index, 0)) + 1
	_leave_camp()
	return true

func camp_back() -> void:
	if state == State.CAMP_FORGE:
		state = State.CAMP
		offers.clear()

func _leave_camp() -> void:
	offers.clear()
	stage = Battle.BOSS_LEVEL if stage == LAST_NORMAL_STAGE else Battle.BOSS2_LEVEL
	start_battle()
