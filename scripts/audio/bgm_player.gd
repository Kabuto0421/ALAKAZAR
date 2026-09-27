extends Node
## Cyber BGM: loops the battle theme and swaps to a one-shot jingle on the result screen.
## The OGGs are rendered by tools/generate_bgm.py.

const BATTLE = preload("res://assets/audio/bgm/battle_loop.ogg")
const BOSS = preload("res://assets/audio/bgm/boss_loop.ogg")
## Between fights: the draft (picks and rewards) and the camp.
const DRAFT = preload("res://assets/audio/bgm/draft_loop.ogg")
const CAMP = preload("res://assets/audio/bgm/camp_loop.ogg")
## Rotorick's loop in three sample-aligned versions, played together and cross-faded
## by the reel: normal, 5 (broken machine) and 7 (jackpot).
const ROTORICK_LAYERS = {
	"normal": preload("res://assets/audio/bgm/rotorick_loop.ogg"),
	"error": preload("res://assets/audio/bgm/rotorick_error.ogg"),
	"jackpot": preload("res://assets/audio/bgm/rotorick_jackpot.ogg"),
}
const LAYER_ORDER = ["normal", "error", "jackpot"]
const SILENT_DB := -60.0
const CROSSFADE := 0.5
const VICTORY = preload("res://assets/audio/bgm/victory.ogg")
const DEFEAT = preload("res://assets/audio/bgm/defeat.ogg")
const VOLUME_DB := -10.0

var player := AudioStreamPlayer.new()
var muted := false
## Loop played during the fight: "battle", "boss" (first boss) or "rotorick".
var theme := "battle"
var rotorick := AudioStreamSynchronized.new()
var layer := "normal"
var layer_tween: Tween

func _ready() -> void:
	player.volume_db = VOLUME_DB
	add_child(player)
	rotorick.stream_count = LAYER_ORDER.size()
	for i in LAYER_ORDER.size():
		rotorick.set_sync_stream(i, ROTORICK_LAYERS[LAYER_ORDER[i]])
		rotorick.set_sync_stream_volume(i, 0.0 if i == 0 else SILENT_DB)

## Idempotent: call whenever the view refreshes; only a change of track restarts playback.
func sync(result_shown: bool, won: bool) -> void:
	var fight: AudioStream = BOSS if theme == "boss" else rotorick if theme == "rotorick" else DRAFT if theme == "draft" else CAMP if theme == "camp" else BATTLE
	var track: AudioStream = (VICTORY if won else DEFEAT) if result_shown else fight
	if player.stream == track:
		return
	player.stream = track
	if not muted:
		player.play()

func toggle_mute() -> void:
	muted = not muted
	if muted:
		player.stop()
	else:
		player.play()

func _exit_tree() -> void:
	player.stop()

## Rotorick: fade to the version matching the shown reel. The three stay in sync, so the
## switch lands on the same beat. Idempotent.
func set_layer(name: String) -> void:
	if name == layer or not ROTORICK_LAYERS.has(name):
		return
	layer = name
	if layer_tween and layer_tween.is_valid():
		layer_tween.kill()
	layer_tween = create_tween().set_parallel(true)
	for i in LAYER_ORDER.size():
		var target := 0.0 if LAYER_ORDER[i] == name else SILENT_DB
		var from: float = rotorick.get_sync_stream_volume(i)
		# Fade in linear gain so the sum stays level through the cross-fade.
		layer_tween.tween_method(func(g: float) -> void: rotorick.set_sync_stream_volume(i, linear_to_db(maxf(g, 0.001))),
			db_to_linear(from), db_to_linear(target), CROSSFADE)

func layer_volume(name: String) -> float:
	return rotorick.get_sync_stream_volume(LAYER_ORDER.find(name))
