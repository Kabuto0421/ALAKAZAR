extends Node
## One-shot sound effects and the boss stings. Kept sparse on purpose: footsteps
## and the boss fights only.
## Effects are rendered by tools/generate_sfx.py, stings by tools/generate_bgm.py.

const SFX_DIR := "res://assets/audio/sfx/"
const NAMES := ["step", "enemy_step", "king_revive", "fortress_spawn", "king_hit", "fortress_crack",
	"fortress_collapse", "king_collapse"]
## Cannon chain links chain_01..chain_20: one semitone up per link (never pitch-jittered).
const CHAIN_LINKS := 20
## Played at the music's level, never pitch-shifted.
const STINGS := {
	"king_intro": preload("res://assets/audio/bgm/king_intro.ogg"),
	"king_rage": preload("res://assets/audio/bgm/king_rage_sting.ogg"),
	"king_fall": preload("res://assets/audio/bgm/king_fall.ogg"),
	"rotorick_intro": preload("res://assets/audio/bgm/rotorick_intro.ogg"),
}
const VOLUME_DB := -4.0
const STING_DB := -10.0
const VOICES := 12
## The same sound twice within this many ms plays once.
const REPEAT_MS := 60

## Shared with the music's mute (M).
static var muted := false
static var _streams := {}
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var last_played := {}

func _ready() -> void:
	if _streams.is_empty():
		for name in NAMES:
			_streams[name] = load(SFX_DIR + name + ".ogg")
		for link in range(1, CHAIN_LINKS + 1):
			_streams["chain_%02d" % link] = load(SFX_DIR + "chain_%02d.ogg" % link)
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func has(name: String) -> bool:
	return _streams.has(name) or STINGS.has(name)

## Play an effect with a slight random pitch, so repeats never sound identical.
func play(name: String, volume_db: float = 0.0) -> void:
	if not _streams.has(name):
		return
	_start(_streams[name], VOLUME_DB + volume_db, randf_range(0.95, 1.05), name)

## The n-th link of this turn's cannon chain (1 = the first set-off), in tune.
func chain_link(link: int) -> void:
	var name := "chain_%02d" % clampi(link, 1, CHAIN_LINKS)
	if _streams.has(name):
		_start(_streams[name], VOLUME_DB, 1.0, name)

func sting(name: String) -> void:
	if STINGS.has(name):
		_start(STINGS[name], STING_DB, 1.0, name)

func _start(stream: AudioStream, volume_db: float, pitch: float, name: String) -> void:
	if muted or voices.is_empty() or not is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(name, -100000)) < REPEAT_MS:
		return
	last_played[name] = now
	# A free voice, or else the oldest one.
	var voice: AudioStreamPlayer = null
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		voice = voices[next_voice]
		next_voice = (next_voice + 1) % voices.size()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()
