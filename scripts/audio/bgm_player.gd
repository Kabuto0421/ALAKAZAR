extends Node
## Cyber BGM: loops the battle theme and swaps to a one-shot jingle on the result screen.
## The OGGs are rendered by tools/generate_bgm.py.

const BATTLE = preload("res://assets/audio/bgm/battle_loop.ogg")
const VICTORY = preload("res://assets/audio/bgm/victory.ogg")
const DEFEAT = preload("res://assets/audio/bgm/defeat.ogg")
const VOLUME_DB := -10.0

var player := AudioStreamPlayer.new()
var muted := false

func _ready() -> void:
	player.volume_db = VOLUME_DB
	add_child(player)

## Idempotent: call whenever the view refreshes; only a change of track restarts playback.
func sync(result_shown: bool, won: bool) -> void:
	var track: AudioStream = (VICTORY if won else DEFEAT) if result_shown else BATTLE
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
