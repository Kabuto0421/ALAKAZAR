extends Node
## Cyber BGM: loops the battle theme and swaps to a one-shot jingle on the result screen.
## The OGGs are rendered by tools/generate_bgm.py.

const BATTLE = preload("res://assets/audio/bgm/battle_loop.ogg")
const BOSS = preload("res://assets/audio/bgm/boss_loop.ogg")
## The storm shark's song. The fight starts 46 s in: seven seconds of the shark lurking under the
## water, then the drop at 53 s is its entrance. The loop afterwards starts at that drop.
const SHARK = preload("res://assets/audio/bgm/storm_shark.ogg")
const SHARK_START := 46.0
const SHARK_DROP := 53.0
## Between fights: the draft (picks and rewards) and the camp.
const DRAFT = preload("res://assets/audio/bgm/draft_loop.ogg")
const CAMP = preload("res://assets/audio/bgm/camp_loop.ogg")
## Layer 2: the enemy's side in the fights (layer2_battle_loop.ogg, the first version, ruins and neon; the other fight versions are layer2_battle_fight_loop and layer2_battle_chip_loop), the fairies' side (a hero's theme) at the
## camp and the draft.
const LAYER2_BATTLE = preload("res://assets/audio/bgm/layer2_battle_loop.ogg")
const LAYER2_DRAFT = preload("res://assets/audio/bgm/layer2_draft_loop.ogg")
const LAYER2_CAMP = preload("res://assets/audio/bgm/layer2_camp_loop.ogg")
## Rotorick's loop in three sample-aligned versions, played together and cross-faded
## by the reel: normal, 5 (broken machine) and 7 (jackpot).
const ROTORICK_LAYERS = {
	"normal": preload("res://assets/audio/bgm/rotorick_loop.ogg"),
	"error": preload("res://assets/audio/bgm/rotorick_error.ogg"),
	"jackpot": preload("res://assets/audio/bgm/rotorick_jackpot.ogg"),
}
const LAYER_ORDER = ["normal", "error", "jackpot"]
## The Prison King: his theme and its rage twin, sample-aligned, played together.
const KING_LAYERS = [
	preload("res://assets/audio/bgm/king_loop.ogg"),
	preload("res://assets/audio/bgm/king_rage.ogg"),
]
const KING_VICTORY = preload("res://assets/audio/bgm/king_victory.ogg")
const SILENT_DB := -60.0
const CROSSFADE := 0.5
const VICTORY = preload("res://assets/audio/bgm/victory.ogg")
const DEFEAT = preload("res://assets/audio/bgm/defeat.ogg")
const VOLUME_DB := -10.0
const SfxPlayer = preload("res://scripts/audio/sfx_player.gd")

var player := AudioStreamPlayer.new()
var muted := false
## Loop played during the fight: "battle", "boss" (first boss) or "rotorick" (layer 2's: "battle2", "draft2", "camp2").
var theme := "battle"
var rotorick := AudioStreamSynchronized.new()
var layer := "normal"
var layer_tween: Tween
var king := AudioStreamSynchronized.new()
var king_raging := false
var king_tween: Tween
## True while a sting plays before the fight's music (the music waits for it).
var held := false
var hold_token := 0
var duck_tween: Tween
## Web: the browser mixes audio on the same single thread as the game, so a fight's layered music
## (three Ogg streams decoded at once for Rotorick, two for the king) made the sound crackle. There
## only the audible version plays, and a switch cross-fades into a second player.
var on_web := OS.has_feature("web")
var twin := AudioStreamPlayer.new()
var fade_tween: Tween

func _ready() -> void:
	player.volume_db = VOLUME_DB
	add_child(player)
	twin.volume_db = SILENT_DB
	add_child(twin)
	var shark_song: AudioStreamOggVorbis = SHARK
	shark_song.loop = true
	shark_song.loop_offset = SHARK_DROP
	rotorick.stream_count = LAYER_ORDER.size()
	for i in LAYER_ORDER.size():
		rotorick.set_sync_stream(i, ROTORICK_LAYERS[LAYER_ORDER[i]])
		rotorick.set_sync_stream_volume(i, 0.0 if i == 0 else SILENT_DB)
	king.stream_count = KING_LAYERS.size()
	for i in KING_LAYERS.size():
		king.set_sync_stream(i, KING_LAYERS[i])
		king.set_sync_stream_volume(i, 0.0 if i == 0 else SILENT_DB)

## Idempotent: call whenever the view refreshes; only a change of track restarts playback.
func sync(result_shown: bool, won: bool) -> void:
	var fight: AudioStream = _king_stream() if theme == "king" else BOSS if theme == "boss" else _rotorick_stream() if theme == "rotorick" else SHARK if theme == "shark" else DRAFT if theme == "draft" else CAMP if theme == "camp" else LAYER2_BATTLE if theme == "battle2" else LAYER2_DRAFT if theme == "draft2" else LAYER2_CAMP if theme == "camp2" else BATTLE
	var victory: AudioStream = KING_VICTORY if theme == "king" else VICTORY
	var track: AudioStream = (victory if won else DEFEAT) if result_shown else fight
	if player.stream == track:
		return
	player.stream = track
	if not muted and not held:
		_play()

## Start the current stream (the shark's song begins part-way in).
func _play() -> void:
	player.play(SHARK_START if player.stream == SHARK else 0.0)

## Seconds into the shark's entrance (0 at the start, 7 at the drop), from the song itself so the
## picture stays on the beat; -1 when the song is not playing.
func shark_clock() -> float:
	if player.stream != SHARK or not player.playing:
		return -1.0
	return player.get_playback_position() + AudioServer.get_time_since_last_mix() - SHARK_START

func toggle_mute() -> void:
	muted = not muted
	SfxPlayer.muted = muted
	if muted:
		_stop_music()
	elif not held:
		_play()

## Keep the music silent for a sting (the boss intros), then start it from the top.
func hold(seconds: float) -> void:
	held = true
	hold_token += 1
	var token := hold_token
	_stop_music()
	await get_tree().create_timer(seconds).timeout
	if token != hold_token or not is_inside_tree():
		return
	held = false
	if not muted and player.stream != null:
		_play()

## Dip the music under a sting (the king's rage and fall) and bring it back.
func duck(seconds: float, depth_db: float = -12.0) -> void:
	if duck_tween and duck_tween.is_valid():
		duck_tween.kill()
	duck_tween = create_tween()
	duck_tween.tween_property(player, "volume_db", VOLUME_DB + depth_db, 0.15)
	duck_tween.tween_interval(maxf(seconds - 0.8, 0.0))
	duck_tween.tween_property(player, "volume_db", VOLUME_DB, 0.65)

func _exit_tree() -> void:
	_stop_music()

func _stop_music() -> void:
	_finish_fade()
	player.stop()
	twin.stop()

## The layered fights' music: all versions in sync (desktop), or only the audible one (Web).
func _rotorick_stream() -> AudioStream:
	return ROTORICK_LAYERS[layer] if on_web else rotorick

func _king_stream() -> AudioStream:
	return KING_LAYERS[1 if king_raging else 0] if on_web else king

## Web: cross-fade from the playing version to `next` on the same beat (the versions are
## sample-aligned), using the second player. With nothing playing the stream is simply swapped.
func _swap_stream(next: AudioStream) -> void:
	if player.stream == next:
		return
	_finish_fade()
	if not player.playing:
		player.stream = next
		return
	var at := player.get_playback_position() + AudioServer.get_time_since_last_mix()
	twin.stream = next
	twin.volume_db = SILENT_DB
	twin.play(at)
	fade_tween = create_tween().set_parallel(true)
	fade_tween.tween_method(func(g: float) -> void: player.volume_db = VOLUME_DB + linear_to_db(maxf(g, 0.001)), 1.0, 0.0, CROSSFADE)
	fade_tween.tween_method(func(g: float) -> void: twin.volume_db = VOLUME_DB + linear_to_db(maxf(g, 0.001)), 0.0, 1.0, CROSSFADE)
	fade_tween.chain().tween_callback(_finish_fade)

## End a cross-fade at once: the second player becomes the main one.
func _finish_fade() -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = null
	if not twin.playing:
		return
	var old := player
	player = twin
	twin = old
	twin.stop()
	twin.volume_db = SILENT_DB
	player.volume_db = VOLUME_DB

## Rotorick: fade to the version matching the shown reel. The three stay in sync, so the
## switch lands on the same beat. Idempotent.
func set_layer(name: String) -> void:
	if name == layer or not ROTORICK_LAYERS.has(name):
		return
	layer = name
	if on_web:
		if theme == "rotorick":
			_swap_stream(ROTORICK_LAYERS[name])
		return
	if layer_tween and layer_tween.is_valid():
		layer_tween.kill()
	layer_tween = create_tween().set_parallel(true)
	for i in LAYER_ORDER.size():
		var target := 0.0 if LAYER_ORDER[i] == name else SILENT_DB
		var from: float = rotorick.get_sync_stream_volume(i)
		# Fade in linear gain so the sum stays level through the cross-fade.
		layer_tween.tween_method(func(g: float) -> void: rotorick.set_sync_stream_volume(i, linear_to_db(maxf(g, 0.001))),
			db_to_linear(from), db_to_linear(target), CROSSFADE)

## The Prison King at half health: fade to the rage twin on the same beat. Idempotent.
func set_king_rage(on: bool) -> void:
	if on == king_raging:
		return
	king_raging = on
	if on_web:
		if theme == "king":
			_swap_stream(KING_LAYERS[1 if on else 0])
		return
	if king_tween and king_tween.is_valid():
		king_tween.kill()
	king_tween = create_tween().set_parallel(true)
	for i in KING_LAYERS.size():
		var target := 0.0 if (i == 1) == on else SILENT_DB
		var from: float = king.get_sync_stream_volume(i)
		king_tween.tween_method(func(g: float) -> void: king.set_sync_stream_volume(i, linear_to_db(maxf(g, 0.001))),
			db_to_linear(from), db_to_linear(target), CROSSFADE)

func layer_volume(name: String) -> float:
	if on_web:
		return 0.0 if layer == name else SILENT_DB
	return rotorick.get_sync_stream_volume(LAYER_ORDER.find(name))
