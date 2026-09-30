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

## Mid and late fairies.
const UNCOMMON_FAIRIES: Array[String] = ["gravity_fairy", "shadow_stitch", "lone_wolf", "freeze_fairy", "blessing_fairy"]
const RARE_FAIRIES: Array[String] = ["axe_spirit", "meteor_fairy", "abyss_spirit", "warp_fairy"]
const SUPER_RARE_FAIRIES: Array[String] = ["glutton_fairy", "guardian_fairy", "holy_spirit"]
## Weapons rarer than their pool (by id); 飛車槍・角剣 are super rare as late weapons.
const RARE_WEAPONS: Array[String] = ["cross", "diagonal", "gold", "silver"]
const SUPER_RARE_WEAPONS: Array[String] = ["eight_knight"]

static func tier(offer: Dictionary) -> int:
	if offer.get("kind", "") == "weapon":
		var index := int(offer.value)
		var id: String = Weapons.DATA[index].id
		if Weapons.is_late(index) or SUPER_RARE_WEAPONS.has(id):
			return SUPER_RARE
		if offer.get("enchant", "") == "circle" or Weapons.DATA[index].get("rare", false) or RARE_WEAPONS.has(id):
			return RARE
		if Weapons.is_mid(index) or Weapons.is_boss_reward(index) or Weapons.from_rotorick(index):
			return UNCOMMON
		return COMMON
	var id := str(offer.value)
	if SUPER_RARE_FAIRIES.has(id):
		return SUPER_RARE
	if RARE_FAIRIES.has(id):
		return RARE
	if UNCOMMON_FAIRIES.has(id):
		return UNCOMMON
	return COMMON
