extends RefCounted
## Four rarity tiers for reward cards, each with its own frame colour:
## コモン (bronze), アンコモン (green), レア (blue), 激レア (gold).

const Weapons = preload("res://scripts/run/weapon_catalog.gd")

enum { COMMON, UNCOMMON, RARE, SUPER_RARE }
const NAMES := ["コモン", "アンコモン", "レア", "激レア"]
const COLORS := [Color("c98b5a"), Color("5fe08a"), Color("4fb4ff"), Color("ffc93c")]
## The light blue of the レア label, for every line of plain information (costs,
## summaries, notes, 選ぶ →): one crisp colour instead of item colours and greys.
const INFO := Color("4fb4ff")

## The fairies of the first picks (and the other plain ones). A new fairy goes in exactly
## one of these four lists: the tests fail until it does.
const COMMON_FAIRIES: Array[String] = ["magic_bolt", "stealth_fairy", "acorn_fairy", "wall_fairy", "cannon_fairy", "vane_cannon", "firework_fairy", "slash_fairy", "capacitor_fairy"]
## Mid and late fairies.
const UNCOMMON_FAIRIES: Array[String] = ["gravity_fairy", "shadow_stitch", "lone_wolf", "freeze_fairy", "blessing_fairy"]
const RARE_FAIRIES: Array[String] = ["axe_spirit", "abyss_spirit", "warp_fairy", "wheel_fairy", "cat_fairy"]
const SUPER_RARE_FAIRIES: Array[String] = ["glutton_fairy", "guardian_fairy", "holy_spirit", "time_fairy", "meteor_fairy"]
## Weapons rarer than their pool (by id); 飛車槍・角剣 are super rare as late weapons.
const UNCOMMON_WEAPONS: Array[String] = ["vertical", "front_diagonal", "sickle"]
const RARE_WEAPONS: Array[String] = ["diagonal", "fan", "tee", "assault", "scales"]
const SUPER_RARE_WEAPONS: Array[String] = ["eight_knight"]

static func tier(offer: Dictionary) -> int:
	if offer.get("kind", "") == "weapon":
		var index := int(offer.value)
		# The hammers are one rarity above where they would otherwise sit.
		return mini(_weapon_tier(offer) + (1 if Weapons.is_hammer(index) else 0), SUPER_RARE)
	var id := str(offer.value)
	if SUPER_RARE_FAIRIES.has(id):
		return SUPER_RARE
	if RARE_FAIRIES.has(id):
		return RARE
	if UNCOMMON_FAIRIES.has(id):
		return UNCOMMON
	return COMMON

static func _weapon_tier(offer: Dictionary) -> int:
	var index := int(offer.value)
	var id: String = Weapons.DATA[index].id
	if Weapons.is_late(index) or SUPER_RARE_WEAPONS.has(id):
		return SUPER_RARE
	if offer.get("enchant", "") == "circle" or Weapons.DATA[index].get("rare", false) or RARE_WEAPONS.has(id):
		return RARE
	if Weapons.is_mid(index) or Weapons.is_boss_reward(index) or Weapons.from_rotorick(index) or UNCOMMON_WEAPONS.has(id):
		return UNCOMMON
	return COMMON

## Super rare weapons cannot be forged (nor can the ones that are never forgeable).
static func can_forge(index: int) -> bool:
	return Weapons.can_forge(index) and tier({"kind": "weapon", "value": index}) < SUPER_RARE
