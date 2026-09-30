extends SceneTree
const Run = preload("res://scripts/run/run_model.gd")
const Rarity = preload("res://scripts/run/rarity.gd")
const W = preload("res://scripts/run/weapon_catalog.gd")
const N := 20000
const OUT := "/tmp/claude-0/-home-user-ALAKAZAR/de898edd-1b50-5178-b539-e7e1278ffc04/scratchpad/odds.tsv"
func _initialize() -> void:
	var lines := PackedStringArray()
	var run := Run.new()
	run.start(1)
	var names := {}
	for item in run.battle.ITEMS:
		names[item.id] = item.title
	lines.append("opening_weapons\t" + ",".join(W.opening_pool().map(func(i): return W.DATA[i].name)))
	lines.append("opening_fairies\t" + ",".join(run.starting_fairy_pool.map(func(id): return names[id])))
	for s in range(0, 11):
		var wt := [0,0,0,0]
		var ft := [0,0,0,0]
		var any_rare := 0
		var circle := 0
		var freq := {}
		for i in N:
			run.rng.seed = i * 7919 + s
			run.battle.reset(s, true)
			run.battle.owned_weapons.assign([0,1])
			run.battle.fairy_loadout.clear()
			run.battle.enchants.clear()
			run.stage = s
			run.state = Run.State.BATTLE
			run.battle.phase = run.battle.Phase.WON
			if not run.finish_battle():
				printerr("fail ", s)
				break
			var rare := false
			for o in run.offers:
				var t := Rarity.tier(o)
				if o.kind == "weapon":
					wt[t] += 1
					if o.get("enchant","") == "circle": circle += 1
				else:
					ft[t] += 1
				if t >= Rarity.RARE: rare = true
				var key: String = ("w:" + W.DATA[int(o.value)].name + ("(魔法陣)" if o.get("enchant","") == "circle" else "")) if o.kind == "weapon" else "f:" + names[str(o.value)]
				freq[key] = int(freq.get(key, 0)) + 1
			if rare: any_rare += 1
		lines.append("stage\t%d\t%s\t%s\t%d\t%d" % [s, ",".join(wt.map(func(x): return str(x))), ",".join(ft.map(func(x): return str(x))), any_rare, circle])
		var keys := freq.keys()
		keys.sort_custom(func(a, b): return freq[a] > freq[b])
		for k in keys:
			lines.append("item\t%d\t%s\t%d" % [s, k, freq[k]])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	printerr("done")
	quit()
