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
	# The title screen: the project starts there; two big menu items, the title theme
	# loops from the march (after the fanfare), and 実績 opens its page.
	verify(ProjectSettings.get_setting("application/run/main_scene") == "res://title.tscn","The game starts on the title screen")
	var title = load("res://title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	verify(title.item_labels.size() == 2 and title.item_labels[0].text == "GAME START" and title.item_labels[1].text == "実績","Title menu: GAME START and 実績")
	verify(title.item_labels.all(func(l): return l.get_theme_font_size("font_size") >= 52),"The menu items are big")
	verify(title.music.playing and title.MUSIC.loop and title.MUSIC.loop_offset > 10.0,"The title theme plays and loops after its fanfare")
	title.reveal = title.MENU_TIME
	title.selected = 1
	title._activate()
	verify(is_instance_valid(title.achievements_page),"実績 opens the achievements page")
	title._close_achievements()
	verify(not is_instance_valid(title.achievements_page),"...and it closes")
	var Achievements = load("res://scripts/title/achievements.gd")
	verify(Achievements.all().is_empty() and Achievements.unlocked_count() == 0 and not Achievements.unlock("nothing"),"Achievements are ready but empty (unknown ids are ignored)")
	title.queue_free()
	await process_frame
	await check_title_sync()
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
		verify(view.actors[-1].weapon_row==2 and view.actors[-1].sword_attack_elapsed>=0.0,"Weapon %d uses sword art and attack motion" % weapon)
		# Knockback weapons deal no damage of their own.
		var shoved: bool = Rules.WEAPONS[weapon].get("knockback",0) > 0
		verify(view.model.player.ap==1 and (struck.hp==1 or (shoved and struck.hp==2)),"Sword action deals one damage for one AP (knockback: none)")
		view._act(target)
		verify(view.model.player.ap==1,"Animation rejects duplicate taps")
		await create_timer(Motion.duration(1)+0.08).timeout
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
	var sounds: Array = ["step", "enemy_step", "king_revive", "fortress_spawn", "king_hit", "fortress_crack", "fortress_collapse", "king_collapse"]
	verify(sounds.all(func(n): return battle.sfx.has(n) and ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % n)),"Every remaining sound effect has its file")
	verify(["king_intro", "king_rage", "king_fall", "rotorick_intro"].all(func(n): return battle.sfx.has(n)),"The boss stings are loaded")
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
