extends SceneTree
const Run = preload("res://scripts/run/run_model.gd")
const Rules = preload("res://scripts/battle_model.gd")
const Card = preload("res://scripts/run/choice_card.gd")
const Motion = preload("res://scripts/animation/sword_motion.gd")
var checks := 0
var failures := 0
var app

func verify(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func click(button: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)

func cards() -> Array:
	return app.screen.get_children().filter(func(node): return node is Card)

func run() -> void:
	# The first-battle manual would cover the board; it is checked on its own below.
	load("res://scripts/battle_view.gd").help_seen = true
	root.size=Vector2i(1728,1080)
	# The tests must not leave anything in the player's fairy book.
	load("res://scripts/fairy_book.gd").recording=false
	# ...and must not depend on what an earlier run left in it.
	load("res://scripts/fairy_book.gd").reset_memory()
	# The title screen: the project starts there; two big menu items, the title theme
	# loops from the march (after the fanfare), and 実績 opens its page.
	verify(ProjectSettings.get_setting("application/run/main_scene") == "res://title.tscn","The game starts on the title screen")
	var title = load("res://title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	verify(title.enemies.texture == title.ENEMIES,"The king stands on the title screen before he is beaten")
	verify(title.item_labels.size() == 2 and title.item_labels[0].text == "GAME START" and title.item_labels[1].text == "実績","Title menu: GAME START and 実績")
	verify(title.item_labels.all(func(l): return l.get_theme_font_size("font_size") >= 52),"The menu items are big")
	# The catalog: every weapon and fairy as the reward cards, opened from the title.
	title.reveal = title.MENU_TIME
	title._open_catalog()
	verify(is_instance_valid(title.catalog),"The catalog opens from the title screen")
	var catalog_weapons := 0
	for index in title.CatalogView.Weapons.DATA.size():
		if not title.CatalogView.Weapons.is_pair_member(index):
			catalog_weapons += 1
	verify(title.catalog.entries("weapon").size() == catalog_weapons and catalog_weapons >= 30,"The weapon catalog lists every weapon (the cross dagger set as one card)")
	verify(title.catalog.entries("fairy").size() == title.CatalogView.Rules.ITEMS.size(),"The fairy catalog lists every fairy")
	var tiers: Array = title.catalog.entries("weapon").map(func(o): return title.CatalogView.Rarity.tier(o))
	var sorted_ok := true
	for k in range(1, tiers.size()):
		sorted_ok = sorted_ok and tiers[k] >= tiers[k - 1]
	verify(sorted_ok,"The catalog runs from common to super rare")
	verify(title.catalog.grid.get_child_count() == title.catalog.entries("weapon").size(),"One card per weapon is built")
	title.catalog._show("fairy")
	await process_frame
	verify(title.catalog.grid.get_child_count() == title.CatalogView.Rules.ITEMS.size(),"The fairy tab builds one card per fairy")
	title.catalog.close()
	await process_frame
	verify(not is_instance_valid(title.catalog),"The catalog closes")
	verify(title.music.playing and title.MUSIC.loop and title.MUSIC.loop_offset > 10.0,"The title theme plays and loops after its fanfare")
	title.reveal = title.MENU_TIME
	title.selected = 1
	title._activate()
	verify(is_instance_valid(title.achievements_page),"実績 opens the achievements page")
	title._close_achievements()
	verify(not is_instance_valid(title.achievements_page),"...and it closes")
	var Achievements = load("res://scripts/title/achievements.gd")
	Achievements.recording = false
	Achievements.reset_memory()
	var ach_ids: Array = Achievements.all().map(func(a): return a.id)
	verify(ach_ids.size() == 10 and ach_ids[0] == "fairy_master" and ach_ids[-1] == "the_world" and Achievements.all().all(func(a): return load(a.icon) != null and a.title != "" and a.description != ""),"Achievements: the fairy master first, the world last (each with an icon, name and description)")
	verify(Achievements.unlocked_count() == 0 and not Achievements.unlock("nothing"),"...none earned at first (unknown ids are ignored)")
	verify(Achievements.progress("fairy_master") == [0, load("res://scripts/battle_model.gd").ITEMS.size()] and Achievements.progress("the_world").is_empty(),"The fairy master shows how many fairies have been used; the other has no count")
	title.queue_free()
	await process_frame
	await check_title_sync()
	check_title_extras()
	await check_fairy_book()
	check_launch_reset()
	await check_fallen_king()
	await check_every_fairy_is_complete()
	await check_defeat_goes_to_title()
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	verify(app.run.state==Run.State.START_WEAPON and not is_instance_valid(app.battle_view),"Initial draft is a separate screen with no battlefield")
	click(cards()[0])
	await process_frame
	verify(app.run.state==Run.State.START_FAIRY and cards().size()==3,"Weapon click opens fairy selection")
	for card in cards():
		if card.offer.value=="acorn_fairy":
			click(card)
			break
	await create_timer(0.8).timeout
	var view = app.battle_view
	verify(view != null and view.model.board_size==4 and view.model.phase==Rules.Phase.PLAYER,"Fairy click starts the first battle and enemy-first turn")
	verify(view.grid_buttons.filter(func(b): return b.visible).size()==16,"Only 4x4 board cells are clickable")
	# The field manual: H opens it over the battle, pages turn, closing hands control back.
	view._toggle_rules()
	await process_frame
	verify(view.help.visible and view.show_rules and view.help.page == 0,"H opens the field manual")
	view.help._turn(1)
	view.help._turn(99)
	verify(view.help.page == view.help.PAGES.size()-1,"Manual pages turn and stop at the last one")
	view.help.close()
	await process_frame
	verify(not view.help.visible and not view.show_rules,"Closing the manual returns to the battle")
	# The battle has a way back to the title: the first press only asks (so a stray click cannot end the run).
	verify(view.title_button!=null and view.title_button.text==view.TITLE_LABEL,"The battle screen has a title button")
	view.title_button.pressed.emit()
	verify(view.title_button.text==view.TITLE_SURE and is_instance_valid(view),"Pressing it once asks for a second press and stays in the battle")
	view.title_asked_at=-100.0
	view.clock=0.0
	view._process(0.0)
	verify(view.title_button.text==view.TITLE_LABEL,"...and the question lapses after a few seconds")
	verify(view.actors[-1].facing==1 and view.model.enemies.all(func(e): return view.actors[e.id].facing==3),"Player faces right and enemy sprites face left")
	verify(not view.model.turn_to(0),"Rotation and paid equip buttons were removed")
	verify(view.inventory_ui.quick_buttons[0].position.x==24 and view.weapon_buttons[0].position.y>=620,"Fairies are on the left; weapons moved below board")
	click(view.weapon_buttons[1])
	verify(view.model.weapon==1 and view.model.player.ap==2,"One click equips backward weapon without AP")
	click(view.weapon_buttons[0])
	verify(view.model.weapon==0 and view.model.player.ap==2,"Repeated switching remains free")
	view._act(view.model.player.cell)
	verify(view.model.facing==1 and view.model.player.ap==2,"Clicking the player does not open rotation")
	view.model.enemies.clear()
	view.model.enemies.append(view.model.make_enemy("recruit",Vector2i(2,2),0))
	view.model.enemies.append(view.model.make_enemy("heavy",Vector2i(3,0),1))
	view._sync_units(false)
	view._update_controls()
	click(view.inventory_ui.quick_buttons[0])
	verify(view.selected_item=="acorn_fairy" and view.model.player.ap==2,"Fairy selection does not consume AP")
	click(view.weapon_buttons[1])
	verify(view.selected_item=="acorn_fairy" and view.model.weapon==1,"Switching weapon keeps the selected fairy (only its reach follows the new weapon)")
	click(view.weapon_buttons[0])
	verify(view.selected_item=="acorn_fairy" and view.model.weapon==0,"... and back again")
	click(view.weapon_buttons[0])
	verify(view.selected_item=="" and view.model.weapon==0,"Pressing the weapon already in hand drops the fairy (back to the weapon)")
	click(view.inventory_ui.quick_buttons[0])
	view._act(Vector2i(1,2))
	await create_timer(0.25).timeout
	verify(view.model.allies.size()==1 and view.model.fairy_charges==[0] and view.model.player.ap==1,"Acorn placement commits once for 1AP")
	verify(view.inventory_ui.quick_buttons[0].disabled,"Used skill stays visible but cannot be used twice")
	click(view.end_button)
	await create_timer(0.9).timeout
	verify(view.model.enemy_at(Vector2i(2,2)).is_empty() and view.model.kills==1,"Ally kills its adjacent target before enemies move")
	verify(view.model.phase==Rules.Phase.PLAYER and view.model.player.ap==2,"Turn returns to player after allies and enemies")
	# Every movement pattern shares the existing sword animation, including backward attacks.
	for weapon in range(Rules.WEAPONS.size()):
		# Mid-game weapons, the swap staff (no damage, it trades places) and the mallet (a hammer) have their own tests.
		if Rules.WEAPONS[weapon].get("tier","") in ["mid","late"] or Rules.WEAPONS[weapon].get("swap", false) or Rules.WEAPONS[weapon].get("hammer", false):
			continue
		view.model.phase=Rules.Phase.PLAYER
		view.model.player.ap=2
		# Two-tile jumps need room on the small board, so stand where the first offset lands inside.
		var first: Vector2i = view.model.weapon_offsets(weapon)[0]
		view.model.player.cell=Vector2i(clampi(1,-first.x,view.model.board_size-1-first.x),clampi(1,-first.y,view.model.board_size-1-first.y))
		view.model.allies.clear()
		view.model.enemies.clear()
		view.model.owned_weapons.assign([weapon])
		view.model.equip(weapon)
		view.model.blade_charge = 0
		var target: Vector2i = view.model.player.cell+first
		view.model.enemies.append(view.model.make_enemy("heavy",target,0))
		view.model.enemies.append(view.model.make_enemy("heavy",Vector2i(3,3),1))
		var struck: Dictionary = view.model.enemies[0]
		view._sync_units(false)
		view._update_controls()
		view._act(target)
		verify(view.actors[-1].weapon_row==2 and (view.actors[-1].sword_attack_elapsed>=0.0 or (load("res://scripts/run/weapon_catalog.gd").is_dagger(weapon) and view.actors[-1].dagger_attack_elapsed>=0.0)),"Weapon %d uses sword art and attack motion" % weapon)
		# Knockback weapons deal no damage of their own.
		var shoved: bool = Rules.WEAPONS[weapon].get("knockback",0) > 0
		verify(view.model.player.ap==1 and (struck.hp==1 or (shoved and struck.hp==2)),"Sword action deals one damage for one AP (knockback: none)")
		view._act(target)
		verify(view.model.player.ap==1,"Animation rejects duplicate taps")
		await create_timer(Motion.duration(1)+0.08).timeout
	# クロス短剣 in the real view: the boosted blow plays the finisher, spreads, and the boost passes on.
	var cat = load("res://scripts/run/weapon_catalog.gd")
	var dagger_ids: Array = cat.DATA.map(func(w): return w.id)
	var thunder_index: int = dagger_ids.find("thunder_dagger")
	var flame_index: int = dagger_ids.find("flame_dagger")
	view.model.phase=Rules.Phase.PLAYER
	view.model.player.ap=2
	view.model.player.cell=Vector2i(1,1)
	view.model.allies.clear()
	view.model.enemies.clear()
	view.model.owned_weapons.assign([thunder_index, flame_index, 0])
	view.model.equip(flame_index)
	view.model.combo_boost=flame_index
	var hit_dagger: Dictionary = view.model.make_enemy("heavy",Vector2i(2,2),0)
	var spread_dagger: Dictionary = view.model.make_enemy("heavy",Vector2i(3,1),1)
	hit_dagger.hp = 6
	spread_dagger.hp = 6
	view.model.enemies.append(hit_dagger)
	view.model.enemies.append(spread_dagger)
	var spread_hp: int = spread_dagger.hp
	view._sync_units(false)
	view._update_controls()
	await process_frame
	verify(view.actors[-1].dagger_look=="flame" and view.actors[-1].dagger_boosted,"A boosted flame dagger shows the crossed stance")
	view._act(Vector2i(2,2))
	verify(view.actors[-1].dagger_attack_elapsed>=0.0 and view.actors[-1].dagger_attack_boosted,"The boosted blow starts the finisher pose")
	await create_timer(0.45).timeout
	verify(view.flashes.any(func(f): return f.kind=="cross_strike"),"The cross strike effect plays")
	verify(spread_dagger.hp<spread_hp or not view.model.enemies.has(spread_dagger),"The diagonal neighbour was struck")
	await create_timer(0.9).timeout
	verify(not view.busy and view.model.combo_boost==thunder_index,"The finisher ends and the boost has moved to the thunder dagger")
	view.model.equip(thunder_index)
	view._sync_units(false)
	verify(view.actors[-1].dagger_look=="thunder" and view.actors[-1].dagger_boosted,"Switching to the thunder dagger shows its crossed stance")
	view.model.equip(flame_index)
	view._sync_units(false)
	verify(view.actors[-1].dagger_look=="flame" and not view.actors[-1].dagger_boosted,"Holding the un-boosted dagger keeps the ordinary stance")
	view.model.equip(0)
	view._sync_units(false)
	verify(view.actors[-1].dagger_look=="" and not view.actors[-1].dagger_boosted,"Any other weapon goes back to the ordinary pose")
	view.model.owned_weapons.assign([0,1,2])
	view.model.weapon=0
	view.model.enemies.clear()
	view.model.check_outcome()
	view._update_controls()
	await process_frame
	click(view.result_button)
	await process_frame
	verify(app.run.state==Run.State.REWARD and cards().size()==5,"Clear button opens five rewards")
	verify(app.run.battle.fairy_charges==[1],"Clear restores the used fairy")
	click(cards()[0])
	await process_frame
	verify(app.run.state==Run.State.REPLACE and cards().size()==3,"Weapon reward opens replacement choices at cap")
	click(cards()[2])
	await create_timer(0.8).timeout
	verify(app.run.state==Run.State.BATTLE and app.battle_view.model.board_size==5,"Replacement click starts 5x5 stage")
	verify(app.battle_view.grid_buttons.filter(func(b): return b.visible).size()==25,"5x5 has 25 active hit targets")
	# Sound: footsteps and the boss sounds exist, and the M key silences effects with the music.
	var battle = app.battle_view
	var sounds: Array = ["step", "enemy_step", "king_revive", "fortress_spawn", "king_hit", "fortress_crack", "fortress_collapse", "king_collapse", "sword_swing", "meteor", "cross_strike"]
	verify(sounds.all(func(n): return battle.sfx.has(n) and ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % n)),"Every remaining sound effect has its file")
	verify(["king_intro", "king_rage", "king_fall", "rotorick_intro"].all(func(n): return battle.sfx.has(n)),"The boss stings are loaded")
	# Weapons: J, K, L and the mouse wheel; fairies: 1, 2, 3.
	var weapon_count: int = battle.model.owned_weapons.size()
	if weapon_count >= 2:
		var press := func(code: Key) -> void:
			var key := InputEventKey.new()
			key.keycode = code
			key.pressed = true
			battle._unhandled_input(key)
		var wheel := func(button: MouseButton) -> void:
			var scroll := InputEventMouseButton.new()
			scroll.button_index = button
			scroll.pressed = true
			battle._unhandled_input(scroll)
		press.call(KEY_K)
		verify(battle.model.weapon==battle.model.owned_weapons[1],"K equips the second weapon")
		press.call(KEY_J)
		verify(battle.model.weapon==battle.model.owned_weapons[0],"J equips the first weapon")
		wheel.call(MOUSE_BUTTON_WHEEL_DOWN)
		verify(battle.model.weapon==battle.model.owned_weapons[1],"The wheel down steps to the next weapon")
		wheel.call(MOUSE_BUTTON_WHEEL_UP)
		wheel.call(MOUSE_BUTTON_WHEEL_UP)
		verify(battle.model.weapon==battle.model.owned_weapons[weapon_count-1],"The wheel up from the first weapon wraps to the last")
		press.call(KEY_1)
		verify(battle.model.weapon==battle.model.owned_weapons[weapon_count-1],"1 no longer switches weapons")
	verify(battle.inventory_ui.keys[0].text=="1" and battle.inventory_ui.keys[2].text=="3","The fairy slots are labelled 1, 2 and 3")
	# Achievements earned in a battle: every fairy used, and winning while time stands still.
	var Book = load("res://scripts/fairy_book.gd")
	Book.path="user://fairy_book_test.cfg"
	Book.recording=true
	Book.reset_memory()
	Achievements.reset_memory()
	var all_items: Array = load("res://scripts/battle_model.gd").ITEMS
	for item in all_items.slice(0, all_items.size()-1):
		Book.record_use(item.id)
	battle._check_achievements()
	verify(not Achievements.is_unlocked("fairy_master") and Achievements.progress("fairy_master")[0]==all_items.size()-1,"One fairy short of all: not yet (the count shows it)")
	Book.record_use(all_items[-1].id)
	battle._check_achievements()
	verify(Achievements.is_unlocked("fairy_master") and battle.toast.current=="fairy_master","Having used every fairy earns 妖精マスター (and shows the banner)")
	battle.model.phase=Rules.Phase.WON
	battle.model.time_stop=0
	battle._check_achievements()
	verify(not Achievements.is_unlocked("the_world"),"Winning with time running earns nothing")
	battle.model.time_stop=1
	battle._check_achievements()
	verify(Achievements.is_unlocked("the_world"),"Winning while time stands still earns ザ・ワールド")
	battle.model.phase=Rules.Phase.PLAYER
	battle.model.time_stop=0
	Book.recording=false
	Book.path=Book.SAVE_PATH
	Book.reset_memory()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fairy_book_test.cfg"))
	Achievements.reset_memory()
	# Summoned allies explain themselves under the cursor, like enemies.
	var free_cell := Vector2i(-1,-1)
	for y in battle.model.board_size:
		for x in battle.model.board_size:
			var c := Vector2i(x,y)
			if free_cell == Vector2i(-1,-1) and c != battle.model.player.cell and battle.model.enemy_at(c).is_empty() and not battle.model.blocked(c):
				free_cell = c
	battle.model.summon_glutton(free_cell)
	battle._sync_units(false)
	battle.hover_cell = free_cell
	verify(battle._preview_ally().get("type","") == "glutton","Hovering a summoned ally picks it for the inspector")
	battle.queue_redraw()
	await process_frame
	battle.model.allies.clear()
	battle._sync_units(false)
	# The abyss and magic circle effects open over the whole screen (they once crashed).
	battle._open_abyss_fx()
	battle._cast_circle_fx({"cells": [Vector2i(1,1)], "line": [Vector2i(1,1)], "targets": []})
	var layers: Array = battle.get_children().filter(func(n): return n is CanvasLayer and n.get_child_count() == 1)
	verify(layers.any(func(l): return l.get_child(0).get_script() == load("res://scripts/fx/abyss_fx.gd")),"The abyss effect opens on its own layer")
	verify(layers.any(func(l): return l.get_child(0).get_script() == load("res://scripts/fx/magic_circle_fx.gd")),"The magic circle effect opens on its own layer")
	await create_timer(3.0).timeout
	verify(battle.position == Vector2.ZERO and not battle.get_children().any(func(n): return n is CanvasLayer and n.get_child_count() == 1 and n.get_child(0).get_script() == load("res://scripts/fx/abyss_fx.gd")),"They clean up and leave the board steady")
	battle.bgm.toggle_mute()
	verify(battle.sfx.muted,"Muting the music mutes the sound effects too")
	battle.bgm.toggle_mute()
	verify(not battle.sfx.muted,"Unmuting brings them back")
	app.queue_free()
	await create_timer(0.2).timeout
	print("RUN UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)


# The title screen follows the music through its cue sheet (written by tools/generate_bgm.py).
func check_title_sync() -> void:
	var Sync = load("res://scripts/title/title_sync.gd")
	var sync = Sync.new()
	verify(sync.load_sheet(),"The title theme's cue sheet loads")
	var music = load("res://assets/audio/bgm/title_theme.ogg")
	verify(absf(sync.length-music.get_length())<0.05,"...and is as long as the title theme (the cues were made for this file)")
	verify(absf(sync.loop_start-music.loop_offset)<0.001,"...and loops where the music does")
	var hits: Array = sync.recent("hit",100.0,100.0)
	var expected := [9.6,17.17,26.48,34.76,41.85]
	verify(hits.size()==5 and range(5).all(func(i): return absf(hits[i][0]-expected[i])<0.02),"The big hits are at 9.6, 17.2, 26.5, 34.8 and 41.85 s")
	verify(["fanfare","glen","war","cyber","build","climax","finish","outro","fusion"]==sync.sections.map(func(e): return e[0]),"The sections are the fanfare, glen, war, cyber, build, climax, finish, outro and fusion")
	verify(sync.section_name(5.0)=="fanfare" and sync.section_name(14.0)=="glen" and sync.section_name(20.0)=="war" and sync.section_name(30.0)=="cyber" and sync.section_name(33.0)=="build" and sync.section_name(35.0)=="climax" and sync.section_name(41.0)=="outro" and sync.section_name(45.0)=="fusion","...and tell where a time falls")
	verify(absf(sync.age("kick",26.6)-0.117)<0.01 and sync.age("kick",1.0)==INF,"The age of the latest kick (none before the first)")
	verify(sync.pulse("kick",26.483,9.0)>0.9 and sync.pulse("kick",27.0-0.01,9.0)<0.05,"A kick pulse jumps on the beat and has died away before the next")
	verify(sync.fresh("hit",26.4,26.6).size()==1 and sync.fresh("hit",26.5,26.6).is_empty(),"A cue is fresh only in the reading it falls in")
	verify(sync.fresh("hit",26.6,26.5).is_empty(),"...a clock stepping back a little repeats nothing")
	var round_trip: Array = sync.fresh("hit",58.3,18.0)
	verify(round_trip.size()==1 and absf(round_trip[0][0]-17.172)<0.01,"...the loop's wrap gives the cues on both sides of it (not the fanfare's)")
	verify(absf(sync.wrap(58.5)-12.098)<0.01 and sync.wrap(30.0)==30.0,"Times past the end come round to the loop's start")
	verify(sync.letter_of([20.0,74])==0 and sync.letter_of([20.0,90])==7 and sync.letter_of([5.0,67])==0 and sync.letter_of([5.0,79])==7 and sync.letter_of([20.0,82])==4,"Low notes light the logo's left letters, high notes the right")
	verify(sync.energy(13.0)<sync.energy(35.0) and sync.energy(57.0)<sync.energy(45.0),"The music is calm in the glen, full at the climax and thins out at the end")
	# The screen, stepped through song time.
	var title = load("res://title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	title.music.stop()
	title.reveal = title.MENU_TIME+5.0
	title.call_done = true
	# Song time is set by hand and the screen stepped one frame at a time.
	var at := func(t: float) -> void:
		title.override_time = t
		title._process(1.0/60.0)
	var param := func(material: ShaderMaterial, name: String): return material.get_shader_parameter(name)
	var gradient: ShaderMaterial = title.grade.material
	at.call(20.0)
	var war_saturation: float = param.call(gradient,"saturation")
	at.call(30.0)
	var cyber_saturation: float = param.call(gradient,"saturation")
	verify(war_saturation>1.0 and cyber_saturation<0.7,"The war is vivid and the cyber part drained of colour")
	verify(title.fx.digital>0.95 and title.fx.digital_left==0.0,"The rain turns into digital rain in the cyber part...")
	at.call(48.0)
	verify(param.call(gradient,"saturation")>1.2 and title.fx.digital_left>0.4,"...and the fusion has both worlds at full colour, with digital rain over the forest too")
	at.call(14.5)
	verify(title.fx.digital<0.05,"...and the glen's rain is plain rain again (the change eases in over a second or so)")
	at.call(26.4)
	at.call(26.51)
	verify(title.flash.color.a>0.25 and title.flash.color.b>title.flash.color.r-0.01 and param.call(gradient,"aberration")>0.008 and param.call(gradient,"glitch")>0.5,"A big hit flashes the screen (cyan for the cyber part), splits the colours and tears the picture")
	verify(title.art.position.length()>0.01,"...and jolts it")
	at.call(29.0)
	verify(title.flash.color.a<0.02 and param.call(gradient,"aberration")<0.001,"...and it settles")
	# The kick pulses the logo, the menu frame and the fairies; the army's lights follow the beat.
	var kick_time: float = sync.last("kick",30.0)[0]
	at.call(kick_time+0.01)
	verify(title.kick_pulse>0.7 and title.logo.scale.x>1.02 and param.call(title.window_mat,"lift")>0.5 and param.call(title.heroes_mat,"wave")>0.002,"The kick swells the logo and lights the menu frame and the fairies")
	verify(param.call(title.enemies_mat,"cyan_glow")>0.5 and param.call(title.enemies_mat,"red_glow")<0.05,"...and flares the army's cyan lights in the cyber part")
	at.call(kick_time+0.4)
	verify(title.kick_pulse<0.05 and title.logo.scale.x<1.005,"...and lets go before the next one")
	at.call(17.2)
	verify(param.call(title.enemies_mat,"red_glow")>0.3,"The war drums flare the army's red lights")
	# Melody notes light ALAKAZAR's letters.
	var note: Array = sync.fresh("note",22.0,25.0)[0]
	at.call(note[0]+0.03)
	var letters: PackedFloat32Array = param.call(title.logo_mat,"shine")
	verify(letters[sync.letter_of(note)]>0.7,"A melody note lights its letter of the logo")
	# The build-up pushes in, the climax lets go; the outro closes letterbox bars, the fusion throws them open.
	at.call(20.0)
	verify(is_equal_approx(title.art.scale.x,1.0) and not title.bar_top.visible,"No zoom or letterbox in the glen")
	at.call(34.5)
	verify(title.art.scale.x>1.04,"The build-up zooms in")
	at.call(40.9)
	verify(title.bar_top.visible and title.bar_top.position.y+120.0>50.0 and title.bar_bottom.position.y<1030.0 and absf(title.art.scale.x-1.0)<0.01,"The outro closes the letterbox bars (and the zoom has let go)")
	at.call(41.86)
	at.call(42.6)
	verify(not title.bar_top.visible,"...which the fusion's hit throws open")
	# The loop: past the file's end the screen is in the glen again.
	title.override_time=59.0
	verify(absf(title._song_time()-12.598)<0.01 and title.sync.section_name(title._song_time())=="glen","The song time folds back into the loop")
	title.queue_free()
	await process_frame


# Fairies the title art does not show are set out by themselves, clear of everything painted.
func check_title_extras() -> void:
	var Extras = load("res://scripts/title/title_extras.gd")
	var Model = load("res://scripts/battle_model.gd")
	var missing: Array = Extras.missing()
	verify(missing.any(func(item): return item.id=="time_fairy"),"The time fairy, not in the art, is set out on the title screen")
	verify(Extras.in_art().all(func(id): return Model.ITEMS.any(func(item): return item.id==id)),"Every fairy the art is said to show exists")
	verify(missing.size()<=Extras.capacity(),"There is room for every fairy the art does not show")
	var image: Image = load("res://assets/title/layer_10_heroes.png").get_image()
	var logo: Image = load("res://assets/title/layer_30_logo.png").get_image()
	var painted := 0
	for y in range(int(Extras.AREA.position.y),int(Extras.AREA.end.y)):
		for x in range(int(Extras.AREA.position.x),int(Extras.AREA.end.x)):
			if image.get_pixel(x,y).a>0.05 or (logo.get_pixel(x,y).a>0.05 and logo.get_pixel(x,y).r>0.7):
				painted+=1
	verify(painted==0,"The free space holds none of the heroes' or the logo's pixels")
	var spots: Array[Rect2] = []
	for index in Extras.capacity():
		spots.append(Rect2(Extras.slot_center(index)-Vector2.ONE*Extras.SIZE/2,Vector2.ONE*Extras.SIZE))
	verify(spots.all(func(r): return Extras.AREA.grow(2).encloses(r)),"Every slot lies inside the free space (with room to bob)")
	verify(range(spots.size()).all(func(i): return range(i+1,spots.size()).all(func(j): return not spots[i].intersects(spots[j]))),"...and no two slots overlap")


# Beaten by the enemy, the way back is the title screen (a cleared run still re-picks a build).
func check_defeat_goes_to_title() -> void:
	var view = load("res://scripts/run/run_view.gd").new()
	root.add_child(view)
	await process_frame
	view.run.state=Run.State.LOST
	view._render()
	var buttons: Array = view.find_children("*","Button",true,false)
	verify(buttons.any(func(b): return b.text=="タイトルへ戻る →") and not buttons.any(func(b): return b.text=="初期ビルドを選び直す →"),"After a defeat the button goes back to the title screen")
	view.run.state=Run.State.FINISHED
	view._render()
	buttons = view.find_children("*","Button",true,false)
	verify(buttons.any(func(b): return b.text=="初期ビルドを選び直す →") and buttons.any(func(b): return b.text=="タイトルへ戻る →"),"...while a cleared run offers a new build and the way back to the title")
	view.queue_free()
	await process_frame


# A fairy stands in the dark on the title screen until it has been used in a battle.
func check_fairy_book() -> void:
	var Book = load("res://scripts/fairy_book.gd")
	var Roster = load("res://scripts/title/title_roster.gd")
	var Model = load("res://scripts/battle_model.gd")
	var Extras = load("res://scripts/title/title_extras.gd")
	var units: Array = Roster.heroes()
	verify(units.size()==23 and units.all(func(u): return u.texture!=null and u.rect.size.x>0),"Every hero-side picture of the title art loads (23)")
	verify(Roster.shown_items().all(func(id): return Model.ITEMS.any(func(item): return item.id==id)),"...and each fairy among them is a fairy of the game")
	var covered: Array = Roster.shown_items()
	covered.append_array(Extras.missing().map(func(item): return item.id))
	verify(Model.ITEMS.all(func(item): return covered.has(item.id)),"Every fairy of the game is on the title screen, as a picture or set out by itself")
	# The book: first use is noted once, kept in the file, and announced once.
	Book.path="user://fairy_book_test.cfg"
	Book.recording=true
	Book.reset_memory()
	verify(not Book.has_used("wall_fairy") and Book.unseen().is_empty(),"Nothing is used at first")
	verify(Book.record_use("wall_fairy") and not Book.record_use("wall_fairy") and Book.has_used("wall_fairy"),"The first use is recorded (once)")
	verify(Book.unseen()==["wall_fairy"],"...and waits to be shown on the title screen")
	Book.reset_memory()
	Book._loaded=false
	verify(Book.has_used("wall_fairy"),"...and is still there after the game is restarted")
	# The title screen.
	var title = load("res://title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	title.music.stop()
	title.reveal=title.MENU_TIME+5.0
	title._update_reveal()
	var by_item := func(screen, item: String) -> Dictionary:
		for unit in screen.hero_units:
			if unit.item==item:
				return unit
		return {}
	verify(by_item.call(title,"wall_fairy").node.modulate==Color.WHITE and by_item.call(title,"meteor_fairy").node.modulate==Extras.LOCKED,"A used fairy is in colour, an unused one a silhouette")
	verify(by_item.call(title,"").node.modulate==Color.WHITE,"The hero is always in colour")
	verify(Book.unseen().is_empty(),"The title screen has announced what it showed")
	title.queue_free()
	await process_frame
	# A fairy used since the last time waits in the dark, then pops out just as ALAKAZAR
	# appears after the drum roll (the brass call).
	Book.record_use("meteor_fairy")
	title = load("res://title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	title.music.stop()
	title.reveal=title.CALL_TIME-0.2
	title._update_reveal()
	verify(by_item.call(title,"meteor_fairy").node.modulate==Extras.LOCKED,"A newly used fairy waits in the dark until ALAKAZAR appears...")
	var motes_before: int = title.fx._motes.size()
	title.reveal=title.CALL_TIME+0.1
	title._update_reveal()
	verify(title.fx._motes.size() > motes_before,"A shower of sparks goes up with the new fairy")
	verify(by_item.call(title,"meteor_fairy").node.modulate.r>1.0 and by_item.call(title,"meteor_fairy").node.scale.x>1.1,"...then steps out with a bright pop on the brass call")
	title.reveal=title.CALL_TIME+3.0
	title._update_reveal()
	verify(is_equal_approx(by_item.call(title,"meteor_fairy").node.scale.x,1.0) and by_item.call(title,"meteor_fairy").node.modulate==Color.WHITE,"...and settles")
	# The gentle horn of the fanfare has no rain; the later parts do.
	var fanfare_look: Dictionary = title._grade_at(5.0)
	var war_look: Dictionary = title._grade_at(20.0)
	verify(is_equal_approx(float(fanfare_look.rain),0.0) and is_equal_approx(float(war_look.rain),1.0),"No rain under the fanfare's horn, rain in the later parts")
	title.queue_free()
	await process_frame
	Book.recording=false
	Book.path=Book.SAVE_PATH
	Book.reset_memory()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fairy_book_test.cfg"))


# The checklist for a new fairy: if one is added to the game and any of these is forgotten,
# this fails and names the fairy. (Its record in the fairy book needs nothing: it is kept by
# the fairy's id; and the title screen sets an unpictured fairy out by itself.)
func check_every_fairy_is_complete() -> void:
	var Model = load("res://scripts/battle_model.gd")
	var Preview = load("res://scripts/items/item_preview.gd")
	var Rarity = load("res://scripts/run/rarity.gd")
	var Card = load("res://scripts/run/choice_card.gd")
	var Extras = load("res://scripts/title/title_extras.gd")
	var Roster = load("res://scripts/title/title_roster.gd")
	var m = Model.new()
	m.reset(0)
	# The example animations may only draw while their canvas is redrawing.
	var canvas := Control.new()
	root.add_child(canvas)
	var drawn := {}
	var asking := {"id": ""}
	canvas.draw.connect(func():
		if asking.id != "":
			drawn[asking.id] = Preview.paint(canvas, m, asking.id, 0.5))
	var problems: Array[String] = []
	for item in Model.ITEMS:
		var id: String = item.id
		asking.id = id
		canvas.queue_redraw()
		await process_frame
		await process_frame
		if item.icon == null or item.effect == null or item.title=="" or item.description=="" or item.summary=="":
			problems.append("%s: item data (icon, effect, title, description, summary)" % id)
		for text in [m.fairy_description(id), m.fairy_summary(id)]:
			if "{" in text or "}" in text:
				problems.append("%s: a {placeholder} in its text is not filled (text_values)" % id)
		if not Model.PLUS_TEXT.has(id):
			problems.append("%s: no class-up text (PLUS_TEXT)" % id)
		else:
			for text in [m.fairy_description(id, 1), m.fairy_summary(id, 1)]:
				if "{" in text:
					problems.append("%s: a {placeholder} in its class-up text is not filled" % id)
		if not drawn.get(id, false):
			problems.append("%s: no example animation (ItemPreview.paint)" % id)
		var listed := 0
		for list in [Rarity.COMMON_FAIRIES, Rarity.UNCOMMON_FAIRIES, Rarity.RARE_FAIRIES, Rarity.SUPER_RARE_FAIRIES]:
			listed += 1 if list.has(id) else 0
		if listed != 1:
			problems.append("%s: not in exactly one rarity list (Rarity.*_FAIRIES)" % id)
		if not Roster.shown_items().has(id) and not Extras.missing().any(func(other): return other.id==id):
			problems.append("%s: nowhere on the title screen" % id)
		var card = Card.new()
		card.size = Vector2(300, 350)
		card.offer = {"kind": "fairy", "value": id}
		card.model = m
		canvas.add_child(card)
		if card.get_child_count() < 3:
			problems.append("%s: its reward card drew nothing" % id)
		card.queue_free()
	for problem in problems:
		printerr("NEW FAIRY CHECK: ", problem)
	verify(problems.is_empty(),"Every fairy has its item data, texts, example animation, rarity, title spot and card (%d problems)" % problems.size())
	canvas.queue_free()
	await process_frame


# The trial version forgets fairies and achievements at every launch (but only once per launch).
func check_launch_reset() -> void:
	var Book = load("res://scripts/fairy_book.gd")
	var Reset = load("res://scripts/launch_reset.gd")
	Book.path="user://fairy_book_test.cfg"
	Book.recording=true
	Book.reset_memory()
	Book.record_use("wall_fairy")
	verify(FileAccess.file_exists("user://fairy_book_test.cfg"),"A used fairy is kept in the file")
	Reset.started=false
	Reset.start_session()
	if Reset.DEMO_RESET:
		verify(not Book.has_used("wall_fairy") and not FileAccess.file_exists("user://fairy_book_test.cfg"),"A new launch forgets it (memory and file)")
	else:
		verify(Book.has_used("wall_fairy") and FileAccess.file_exists("user://fairy_book_test.cfg"),"With the trial reset switched off, a new launch keeps the records")
	Book.record_use("meteor_fairy")
	Reset.start_session()
	verify(Book.has_used("meteor_fairy"),"...but only once: coming back to the title does not wipe")
	# With recording off (tests, tools) nothing is touched.
	Book.recording=false
	Reset.started=false
	Reset.start_session()
	verify(Book.has_used("meteor_fairy"),"The tests and tools never wipe the player's data")
	Reset.started=true
	Book.reset_memory()
	Book.path=Book.SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fairy_book_test.cfg"))

## Beating the Prison King changes the title screen: his rubble replaces him.
func check_fallen_king() -> void:
	var Ach = load("res://scripts/title/achievements.gd")
	Ach.recording = false
	Ach.reset_memory()
	Ach.unlock("alakazar_king")
	var screen = load("res://title.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	verify(screen.enemies.texture == screen.ENEMIES_FALLEN,"After ALAKAZAR's KING the title shows the fallen king")
	screen.queue_free()
	await process_frame
	Ach.reset_memory()
