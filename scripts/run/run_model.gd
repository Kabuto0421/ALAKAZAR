extends RefCounted

const Battle = preload("res://scripts/battle_model.gd")
const Weapons = preload("res://scripts/run/weapon_catalog.gd")
enum State { START_WEAPON, START_FAIRY, BATTLE, REWARD, REPLACE, CAMP, CAMP_FORGE, CAMP_FAIRY, FINISHED, LOST }
## Normal fights before the camp; the boss follows the camp.
const LAST_NORMAL_STAGE := 2
const CAMP_HEAL := 2
## Each reward shows this many weapons and fairies (pick one of them, or skip).
const WEAPON_OFFERS := 3
const FAIRY_OFFERS := 2
## Difficulty: 0 = normal. Raise it to strip the helpers below.
var difficulty := 0

## HP healed after each win: 1 on normal, none on higher difficulties.
func win_heal() -> int:
	return 1 if difficulty <= 0 else 0
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
## Rare 2x2 fairies: one of the two fairy offers after the first boss may be one.
const RARE_FAIRIES: Array[String] = ["axe_spirit", "holy_spirit"]
const RARE_CHANCE := 0.3
## Late fairies: placed only where no carried weapon reaches; they only turn
## up after Rotorick.
const LATE_FAIRIES: Array[String] = ["shadow_stitch", "lone_wolf"]
## Magic circle weapons: a rare early reward, commoner after the first boss.
const CIRCLE_CHANCE_EARLY := 0.1
const CIRCLE_CHANCE_LATE := 0.3
var reward_fairy_pool: Array[String] = ["magic_bolt","stealth_fairy","acorn_fairy","warp_fairy","wall_fairy","cannon_fairy","vane_cannon","firework_fairy","slash_fairy","capacitor_fairy","shadow_stitch","lone_wolf"]

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
				_enchant(int(offer.value), offer)
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
	battle.start_hp = mini(Battle.MAX_HP, battle.player.hp + win_heal())
	battle.refill_fairies()
	if stage == Battle.LAST_LEVEL:
		# No boss after the late fights yet: the run ends here.
		state = State.FINISHED
		return true
	state = State.REWARD
	offers.clear()
	var weapons: Array = []
	var single_only := stage < Weapons.SINGLE_TILE_STAGES
	var mid := stage >= Battle.BOSS_LEVEL
	var late := stage >= Battle.BOSS2_LEVEL
	# The last fight before a boss pays better: only three-tile weapons.
	var before_boss := is_before_boss()
	for index in range(Weapons.DATA.size()):
		if battle.owned_weapons.has(index) or Weapons.horizontal_only(index) or (Weapons.is_mid(index) and not mid) or (Weapons.is_late(index) and not late):
			continue
		if before_boss:
			if not Weapons.is_boss_reward(index):
				continue
		elif single_only and not Weapons.early_reward_pool().has(index):
			continue
		weapons.append(index)
	# After the first boss, one weapon slot is a mid-game drop (hammer, bow, ...) when one is
	# left; after Rotorick it is a sliding weapon instead.
	var drops: Array = (Weapons.late_pool() if late else Weapons.mid_pool()).filter(func(index: int) -> bool: return not battle.owned_weapons.has(index))
	if late and drops.is_empty():
		drops = Weapons.mid_pool().filter(func(index: int) -> bool: return not battle.owned_weapons.has(index))
	if mid and not drops.is_empty():
		var drop: int = sample(drops,1)[0]
		offers.append({"kind":"weapon","value":drop})
		weapons.erase(drop)
		for index in sample(weapons,WEAPON_OFFERS-1):
			offers.append({"kind":"weapon","value":index})
	else:
		for index in sample(weapons,WEAPON_OFFERS):
			offers.append({"kind":"weapon","value":index})
	# 飛車槍・角剣 only ever come as magic circle weapons.
	for offer in offers:
		if Weapons.is_late(int(offer.value)):
			offer.enchant = "circle"
			offer.rare = true
	# Now and then one weapon offer comes with a magic circle (never the bow, which cannot move).
	var circle_chance := CIRCLE_CHANCE_LATE if mid else CIRCLE_CHANCE_EARLY
	var movable: Array = offers.filter(func(o: Dictionary) -> bool: return Weapons.DATA[int(o.value)].get("ranged", "") == "" and o.get("enchant", "") == "")
	if not movable.is_empty() and rng.randf() < circle_chance:
		var pick: Dictionary = movable[rng.randi_range(0, movable.size() - 1)]
		pick.enchant = "circle"
		pick.rare = true
	var fairy_pool: Array = reward_fairy_pool.filter(func(id: String) -> bool: return late or not LATE_FAIRIES.has(id))
	var fairy_candidates: Array = fairy_pool.filter(func(id: String) -> bool: return not battle.fairy_loadout.has(id))
	# A full loadout may leave only one new fairy: owned fairies become valid swaps.
	if fairy_candidates.size() < 2:
		fairy_candidates = fairy_pool.duplicate()
	for id in sample(fairy_candidates,FAIRY_OFFERS):
		offers.append({"kind":"fairy","value":id})
	# Beating a boss (the first one or Rotorick) can turn the last fairy offer into a rare one.
	var rares: Array = RARE_FAIRIES.filter(func(id: String) -> bool: return not battle.fairy_loadout.has(id))
	if Battle.BOSS_LEVELS.has(stage) and not rares.is_empty() and rng.randf() < RARE_CHANCE:
		offers[offers.size()-1] = {"kind":"fairy","value":sample(rares,1)[0], "rare":true}
	return true

func _enchant(index: int, offer: Dictionary) -> void:
	if offer.get("enchant", "") != "":
		battle.enchants[index] = offer.enchant

## True on the reward right before a camp and its boss.
func is_before_boss() -> bool:
	return stage == LAST_NORMAL_STAGE or stage == Battle.MID_LEVELS[-1]

func replace(slot: int) -> bool:
	if state != State.REPLACE:
		return false
	if pending.kind == "weapon":
		if slot < 0 or slot >= battle.owned_weapons.size():
			return false
		battle.enchants.erase(battle.owned_weapons[slot])
		battle.owned_weapons[slot] = int(pending.value)
		_enchant(int(pending.value), pending)
	else:
		if slot < 0 or slot >= battle.fairy_loadout.size():
			return false
		var id := str(pending.value)
		var old: String = battle.fairy_loadout[slot]
		battle.fairy_loadout[slot] = id
		# A class-up belongs to the fairy that was upgraded; giving it up loses it.
		if not battle.fairy_loadout.has(old):
			battle.fairy_plus.erase(old)
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
	elif stage == Battle.MID_LEVELS[-1] or stage == Battle.LATE_LEVELS[1]:
		# Mid-game camp before Rotorick; late camp before the last late fight.
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

## Each weapon can be forged once.
func can_forge() -> bool:
	return battle.owned_weapons.any(func(index: int) -> bool: return not battle.weapon_power.has(index))

func can_class_up() -> bool:
	return battle.fairy_loadout.any(func(id: String) -> bool: return battle.can_class_up(id))

func camp_forge() -> bool:
	if state != State.CAMP or not can_forge():
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
	if battle.weapon_power.has(index):
		return false
	battle.weapon_power[index] = 1
	_leave_camp()
	return true

func camp_class_up() -> bool:
	if state != State.CAMP or not can_class_up():
		return false
	state = State.CAMP_FAIRY
	offers.clear()
	for id in battle.fairy_loadout:
		offers.append({"kind":"fairy", "value":id})
	return true

func camp_class_up_fairy(slot: int) -> bool:
	if state != State.CAMP_FAIRY or not battle.class_up(slot):
		return false
	_leave_camp()
	return true

func camp_back() -> void:
	if state in [State.CAMP_FORGE, State.CAMP_FAIRY]:
		state = State.CAMP
		offers.clear()

func _leave_camp() -> void:
	offers.clear()
	if stage == Battle.LATE_LEVELS[1]:
		stage = Battle.LATE_LEVELS[2]
		start_battle()
		return
	stage = Battle.BOSS_LEVEL if stage == LAST_NORMAL_STAGE else Battle.BOSS2_LEVEL
	start_battle()
