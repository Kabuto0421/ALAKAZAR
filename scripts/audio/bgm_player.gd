extends Node
## Cyber BGM: loops the title or battle theme and swaps to a one-shot jingle on the result screen.
## The OGGs are rendered by tools/generate_bgm.py.

const TITLE = preload("res://assets/audio/bgm/title_loop.ogg")
const BATTLE = preload("res://assets/audio/bgm/battle_loop.ogg")
const VICTORY = preload("res://assets/audio/bgm/victory.ogg")
const DEFEAT = preload("res://assets/audio/bgm/defeat.ogg")
const VOLUME_DB := -10.0

## Shared across scenes so muting on the title screen carries into battle.
static var muted := false
var player := AudioStreamPlayer.new()

func _ready() -> void:
	player.volume_db = VOLUME_DB
	add_child(player)

## Idempotent: call whenever the view refreshes; only a change of track restarts playback.
func sync(result_shown: bool, won: bool) -> void:
	play_track((VICTORY if won else DEFEAT) if result_shown else BATTLE)

func play_track(track: AudioStream) -> void:
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
