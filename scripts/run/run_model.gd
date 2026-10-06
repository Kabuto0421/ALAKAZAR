extends RefCounted

const Battle = preload("res://scripts/battle_model.gd")
const Rarity = preload("res://scripts/run/rarity.gd")
const Weapons = preload("res://scripts/run/weapon_catalog.gd")
enum State { START_WEAPON, START_FAIRY, BATTLE, REWARD, REPLACE, CAMP, CAMP_FORGE, CAMP_FAIRY, FINISHED, LOST, SHEATH, PREP }
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
## 1 = the demo's expedition; 2 = layer 2 (holed boards, the sheath fairy), entered after clearing layer 1.
var layer := 1
var layer2_stage := 0
var rng := RandomNumberGenerator.new()
## Forces the first boss room (0: horses, 1: rook + moving prison); -1 draws it at random.
var boss_choice := -1
## Forces the second boss room (0: Rotorick, 1: the storm shark); -1 draws it at random.
var boss2_choice := -1
# Expand these pools to introduce additional resource-defined fairy effects.
var starting_fairy_pool: Array[String] = ["magic_bolt","stealth_fairy","acorn_fairy"]
## Magic circle weapons: 3% of rewards, and only on a simple (plain moving) weapon.
const CIRCLE_CHANCE := 0.03
## Each weapon card first draws its rarity from this table (コモン, アンコモン, レア,
## 激レア), by the fight just won, then a weapon of that rarity: the rarity sets when
## a weapon turns up. The reward before the first boss leans to uncommon (the
## three-tile weapons and the mid-game ones); around Rotorick, cards
## are 25/30/35/10 (rare the likeliest), and in the late fights 30/40/25/5, the same as the fairies. Early on the rare row is
## tiny because magic circles (3% of rewards) already make about 1% of cards rare.
const WEAPON_TIER_ODDS := [
	[0.92, 0.06, 0.01, 0.01],
	[0.92, 0.06, 0.01, 0.01],
	[0.12, 0.84, 0.03, 0.01],
	[0.36, 0.45, 0.16, 0.03],
	[0.36, 0.45, 0.16, 0.03],
	[0.36, 0.45, 0.16, 0.03],
	[0.25, 0.30, 0.35, 0.10],
	[0.25, 0.30, 0.35, 0.10],
	[0.30, 0.40, 0.25, 0.05],
	[0.30, 0.40, 0.25, 0.05],
	[0.30, 0.40, 0.25, 0.05],
]
var reward_fairy_pool: Array[String] = ["magic_bolt","stealth_fairy","acorn_fairy","warp_fairy","wall_fairy","cannon_fairy","vane_cannon","firework_fairy","slash_fairy","capacitor_fairy","shadow_stitch","lone_wolf","abyss_spirit","gravity_fairy","glutton_fairy","freeze_fairy","blessing_fairy","meteor_fairy","guardian_fairy","axe_spirit","holy_spirit","time_fairy","cat_fairy","wheel_fairy"]

func start(seed_value: int = -1) -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	stage = 0
	layer = 1
	layer2_stage = 0
	battle.layout_override = null
	battle.sheathed_weapon = -1
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

## Each fairy card first draws its rarity from this table (コモン, アンコモン, レア,
## 激レア), by the fight just won (0 = the first fight), then a fairy of that rarity.
## Every fairy can turn up from the first reward; the rarer tiers grow as the run
## goes on (激レア from about 2% early to 10% by Rotorick; the rewards before and after
## Rotorick are 25/30/35/10 with rare the likeliest, and the late fights ease back to
## 30/40/25/5 so commons and uncommons turn up more).
const FAIRY_TIER_ODDS := [
	[0.76, 0.17, 0.05, 0.02],
	[0.76, 0.17, 0.05, 0.02],
	[0.74, 0.17, 0.07, 0.02],
	[0.51, 0.28, 0.14, 0.07],
	[0.48, 0.29, 0.15, 0.08],
	[0.46, 0.30, 0.16, 0.08],
	[0.25, 0.30, 0.35, 0.10],
	[0.25, 0.30, 0.35, 0.10],
	[0.30, 0.40, 0.25, 0.05],
	[0.30, 0.40, 0.25, 0.05],
	[0.30, 0.40, 0.25, 0.05],
]

## The reward right after a boss (the first one, Rotorick) leans rarer: this is added
## to that fight's row (taken from コモン).
const BOSS_FAIRY_BONUS := [-0.07, 0.0, 0.05, 0.02]

## The rarity odds for this reward's fairy cards.
func fairy_tier_odds() -> Array:
	var odds: Array = FAIRY_TIER_ODDS[clampi(stage, 0, FAIRY_TIER_ODDS.size() - 1)].duplicate()
	if Battle.BOSS_LEVELS.has(stage):
		for t in odds.size():
			odds[t] += BOSS_FAIRY_BONUS[t]
	return odds

## One fairy for a reward card: a rarity from the odds, then one of the candidates
## of that rarity (the nearest rarity with any left when that one has none).
func draw_fairy(candidates: Array) -> String:
	var pick: Variant = _draw_by_rarity(candidates, fairy_tier_odds(), "fairy")
	return "" if pick == null else str(pick)

## One weapon for a reward card, the same way (its rarity without any enchantment).
func draw_weapon(candidates: Array) -> int:
	var pick: Variant = _draw_by_rarity(candidates, WEAPON_TIER_ODDS[clampi(stage, 0, WEAPON_TIER_ODDS.size() - 1)], "weapon")
	return -1 if pick == null else int(pick)

func _draw_by_rarity(candidates: Array, odds: Array, kind: String) -> Variant:
	var roll := rng.randf()
	var tier := odds.size() - 1
	for t in odds.size():
		roll -= float(odds[t])
		if roll < 0.0:
			tier = t
			break
	for step in range(0, 4):
		for t in [tier - step, tier + step]:
			var pool: Array = candidates.filter(func(value: Variant) -> bool: return Rarity.tier({"kind":kind, "value":value}) == t)
			if not pool.is_empty():
				return pool[rng.randi_range(0, pool.size() - 1)]
	return null

## Draw `count` without repeats, each pick proportional to its weight.
func weighted_sample(pool: Array, count: int, weight: Callable) -> Array:
	var candidates := pool.duplicate()
	var result: Array = []
	while result.size() < count and not candidates.is_empty():
		var total := 0.0
		for item in candidates:
			total += float(weight.call(item))
		var roll := rng.randf() * total
		var pick := candidates.size() - 1
		for i in candidates.size():
			roll -= float(weight.call(candidates[i]))
			if roll <= 0.0:
				pick = i
				break
		result.append(candidates.pop_at(pick))
	return result

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
		# クロス短剣: a pair is two weapons; those that do not fit wait to replace slots.
		var incoming: Array = []
		if offer.kind == "weapon":
			incoming.append(int(offer.value))
			if Weapons.is_pair_head(int(offer.value)):
				incoming.append(Weapons.pair_of(int(offer.value)))
			incoming = incoming.filter(func(w: int) -> bool: return not battle.owned_weapons.has(w))
		var free: int = Battle.WEAPON_LIMIT - battle.owned_weapons.size()
		var full: bool = incoming.size() > free if offer.kind == "weapon" else battle.fairy_loadout.size() >= Battle.HAND_LIMIT
		if full:
			pending = offer.duplicate()
			if offer.kind == "weapon":
				# Leaving the choice must undo anything already placed.
				pending.snapshot = battle.owned_weapons.duplicate()
				pending.snapshot_enchants = battle.enchants.duplicate()
				# Fill the free slots first; the rest replace slots one by one.
				var placed: Array = []
				while not incoming.is_empty() and battle.owned_weapons.size() < Battle.WEAPON_LIMIT:
					var weapon_index: int = incoming.pop_front()
					battle.owned_weapons.append(weapon_index)
					placed.append(weapon_index)
					if weapon_index == int(offer.value):
						_enchant(weapon_index, offer)
				pending.placed = placed
				pending.remaining = incoming
			state = State.REPLACE
		else:
			if offer.kind == "weapon":
				for weapon_index in incoming:
					battle.owned_weapons.append(weapon_index)
				_enchant(int(offer.value), offer)
			else:
				battle.add_item(str(offer.value))
			advance()
	return true

## Enter layer 2 straight away. `build`: {"weapons": basic weapons, "sheath": weapon index (-1 none),
## "fairies": ids, "plus": class-up every fairy once, "hp"}. Used by the debug start and, later, by the layer 1 ending.
func start_layer2(build: Dictionary, seed_value: int = -1) -> void:
	start(seed_value)
	layer = 2
	layer2_stage = 0
	stage = Battle.MID_LEVELS[0]
	battle.owned_weapons.assign(build.get("weapons", [0, 1]))
	battle.sheathed_weapon = int(build.get("sheath", -1))
	battle.fairy_loadout.assign(build.get("fairies", []))
	battle.fairy_plus.clear()
	if build.get("plus", false):
		for id in battle.fairy_loadout:
			if battle.can_class_up(id):
				battle.fairy_plus[id] = 1
	battle.start_hp = int(build.get("hp", Battle.MAX_HP))
	battle.refill_fairies()
	# Layer 2 opens on the reward for clearing layer 1, then the prep screen, then the first fight.
	layer2_stage = -1
	_roll_rewards()

func start_battle() -> void:
	battle.layout_override = Battle.LAYER2_FORMATIONS[layer2_stage] if layer == 2 else null
	battle.reset(stage,true)
	battle.win_heal = win_heal()
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
	if layer == 2 and layer2_stage >= Battle.LAYER2_FORMATIONS.size() - 1:
		state = State.FINISHED
		return true
	if layer == 1 and stage == Battle.LAST_LEVEL:
		# The Prison King is down: the expedition is over.
		state = State.FINISHED
		return true
	_roll_rewards()
	return true

## The reward cards for the fight just won: weapons and fairies drawn by rarity for this point in the run.
func _roll_rewards() -> void:
	state = State.REWARD
	offers.clear()
	# Weapons: each card draws a rarity for this point in the run, then a weapon of it.
	var weapons: Array = range(Weapons.DATA.size()).filter(func(index: int) -> bool: return not battle.owned_weapons.has(index) and not Weapons.horizontal_only(index) and not Weapons.is_pair_member(index) and not (Weapons.is_pair_head(index) and battle.owned_weapons.has(Weapons.pair_of(index))))
	for k in WEAPON_OFFERS:
		var index := draw_weapon(weapons)
		if index < 0:
			break
		weapons.erase(index)
		offers.append({"kind":"weapon","value":index})
	# 飛車槍・角剣 only ever come as magic circle weapons.
	for offer in offers:
		if Weapons.is_late(int(offer.value)):
			offer.enchant = "circle"
			offer.rare = true
	# Now and then one simple weapon offer comes with a magic circle.
	var movable: Array = offers.filter(func(o: Dictionary) -> bool: return Weapons.is_simple(int(o.value)) and o.get("enchant", "") == "")
	if not movable.is_empty() and rng.randf() < CIRCLE_CHANCE:
		var pick: Dictionary = movable[rng.randi_range(0, movable.size() - 1)]
		pick.enchant = "circle"
		pick.rare = true
	var fairy_candidates: Array = reward_fairy_pool.filter(func(id: String) -> bool: return not battle.fairy_loadout.has(id))
	# A full loadout may leave only one new fairy: owned fairies become valid swaps.
	if fairy_candidates.size() < FAIRY_OFFERS:
		fairy_candidates = reward_fairy_pool.duplicate()
	for k in FAIRY_OFFERS:
		var id := draw_fairy(fairy_candidates)
		fairy_candidates.erase(id)
		offers.append({"kind":"fairy","value":id})

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
		var remaining: Array = pending.get("remaining", [int(pending.value)])
		if remaining.is_empty() or pending.get("placed", []).has(battle.owned_weapons[slot]):
			return false
		var coming: int = remaining.pop_front()
		battle.enchants.erase(battle.owned_weapons[slot])
		battle.owned_weapons[slot] = coming
		if coming == int(pending.value):
			_enchant(int(pending.value), pending)
		if not remaining.is_empty():
			# The other half of the pair still needs a slot.
			pending.remaining = remaining
			pending.placed = pending.get("placed", []) + [coming]
			return true
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
		if pending.has("snapshot"):
			battle.owned_weapons.assign(pending.snapshot)
			battle.enchants = pending.snapshot_enchants
		pending.clear()
		state = State.REWARD

## Layer 2: between fights, the sheathed weapon can trade places with an equipped one.
func can_sheath_swap() -> bool:
	return layer == 2 and battle.sheathed_weapon >= 0 and state in [State.REWARD, State.CAMP, State.PREP]

func sheath_open() -> bool:
	if not can_sheath_swap():
		return false
	pending = {"return_state": state}
	state = State.SHEATH
	return true

## The equipped weapon in `slot` goes into the sheath; what was in the sheath takes its place.
func sheath_swap(slot: int) -> bool:
	if state != State.SHEATH or slot < 0 or slot >= battle.owned_weapons.size():
		return false
	var drawn: int = battle.sheathed_weapon
	battle.sheathed_weapon = battle.owned_weapons[slot]
	battle.owned_weapons[slot] = drawn
	sheath_back()
	return true

func sheath_back() -> void:
	if state == State.SHEATH:
		state = pending.get("return_state", State.REWARD)
		pending.clear()

func skip_reward() -> void:
	if state == State.REWARD:
		if layer == 2:
			depart()
		else:
			advance()

## Layer 2: the reward is taken, and the fight waits until the player departs (so the sheath can still be swapped).
func depart() -> void:
	if state not in [State.REWARD, State.PREP]:
		return
	layer2_stage += 1
	start_battle()

func advance() -> void:
	battle.refill_fairies()
	if layer == 2:
		state = State.PREP
		offers.clear()
		return
	if stage == LAST_NORMAL_STAGE:
		# The boss room is drawn on arriving at the camp, so the camp can name it.
		battle.boss_variant = boss_choice if boss_choice >= 0 else rng.randi_range(0, Battle.BOSS_FORMATIONS.size() - 1)
		state = State.CAMP
		_roll_camp_tiles()
	elif stage == Battle.MID_LEVELS[-1] or stage == Battle.LATE_LEVELS[1] or stage == Battle.LATE_LEVELS[3]:
		if stage == Battle.MID_LEVELS[-1]:
			battle.boss2_variant = boss2_choice if boss2_choice >= 0 else rng.randi_range(0, Battle.BOSS2_FORMATIONS.size() - 1)
		# Camps: before Rotorick, after the second late fight, and before the Prison King.
		state = State.CAMP
		_roll_camp_tiles()
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

## Arriving at a camp draws, for each weapon that forges into a new tile, the tile its forge would
## add (so the forge screen can show it, and it stays the same for this camp). 5% of the time it
## is a tile on the outer ring of the 7x7.
var camp_tiles: Dictionary = {}
var camp_tiles_rolled := false
const OUTER_TILE_CHANCE := 0.05

func _roll_camp_tiles() -> void:
	camp_tiles.clear()
	camp_tiles_rolled = true
	for index in battle.owned_weapons:
		if not Rarity.can_forge(index) or Weapons.forge_kind(index) != "tile":
			continue
		var outer: bool = rng.randf() < OUTER_TILE_CHANCE
		var already: Array = battle.weapon_extra.get(index, [])
		var pool: Array[Vector2i] = Weapons.extra_candidates(index, outer, already)
		if pool.is_empty():
			pool = Weapons.extra_candidates(index, not outer, already)
		if not pool.is_empty():
			camp_tiles[index] = pool[rng.randi_range(0, pool.size() - 1)]

## Whether a weapon can be forged now: a tile weapon as often as a tile is left to draw, the others once.
func can_forge_weapon(index: int) -> bool:
	if not Rarity.can_forge(index):
		return false
	if Weapons.forge_kind(index) == "tile":
		return state != State.CAMP_FORGE or camp_tiles.has(index) or not camp_tiles_rolled
	return not battle.weapon_power.has(index)

func can_forge() -> bool:
	return battle.owned_weapons.any(func(index: int) -> bool: return can_forge_weapon(index))

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
	if not can_forge_weapon(index):
		return false
	battle.weapon_power[index] = int(battle.weapon_power.get(index, 0)) + 1
	if camp_tiles.has(index):
		var added: Array = battle.weapon_extra.get(index, [])
		added.append(camp_tiles[index])
		battle.weapon_extra[index] = added
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
	camp_tiles.clear()
	camp_tiles_rolled = false
	if stage == Battle.LATE_LEVELS[1] or stage == Battle.LATE_LEVELS[3]:
		stage = Battle.LATE_LEVELS[2] if stage == Battle.LATE_LEVELS[1] else Battle.FINAL_LEVEL
		start_battle()
		return
	stage = Battle.BOSS_LEVEL if stage == LAST_NORMAL_STAGE else Battle.BOSS2_LEVEL
	start_battle()
