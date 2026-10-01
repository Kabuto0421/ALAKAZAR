extends RefCounted
## The title theme's cue sheet: when every kick, war drum, big hit and melody note
## of assets/audio/bgm/title_theme.cues.json happens, so the title screen can move
## with the music. The sheet is written by tools/generate_bgm.py (the generator logs
## each event as it places the sound), in the seconds of the finished file: the
## fanfare (0 to loop_start), then the march, which loops back to loop_start.
##
## Everything is a function of the song time, with no state of its own, so a screen
## that reads the time from the audio stays in step through lag, loops and skips.
##
## Kinds: kick [t, strength], drum [t, strength] (war drums), clap [t, strength],
## hit [t, strength, mood], note [t, midi pitch, seconds, voice], harp [t, midi pitch].
## Voices: 0 whistle (and the fanfare's pipes), 1 pipes, 2 the EDM lead, 3 the fusion tune.

const PATH := "res://assets/audio/bgm/title_theme.cues.json"

var length := 0.0
var loop_start := 0.0
## [[name, start seconds], ...] in order.
var sections: Array = []
## [[seconds, 0-1], ...]: how hard the music plays, linear between the knots.
var energy_knots: Array = []
var _times := {}  # kind -> PackedFloat64Array
var _rows := {}  # kind -> Array of rows

func load_sheet(path: String = PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not data.has("events"):
		return false
	length = float(data.get("length", 0.0))
	loop_start = float(data.get("loop_start", 0.0))
	sections = data.get("sections", [])
	energy_knots = data.get("energy", [])
	for kind in data.events:
		var rows: Array = data.events[kind]
		var times := PackedFloat64Array()
		for row in rows:
			times.append(float(row[0]))
		_times[kind] = times
		_rows[kind] = rows
	return length > 0.0

## A song time folded into the file: past the end it comes round to the loop start.
func wrap(t: float) -> float:
	if length > 0.0 and t >= length:
		return loop_start + fmod(t - length, length - loop_start)
	return maxf(t, 0.0)

## How many rows of `kind` are at or before t.
func _count_upto(kind: String, t: float) -> int:
	return _times[kind].bsearch(t, false) if _times.has(kind) else 0

## The latest row of `kind` at or before t ([] if none yet).
func last(kind: String, t: float) -> Array:
	var n := _count_upto(kind, t)
	return _rows[kind][n - 1] if n > 0 else []

## Seconds since the latest `kind` event (INF before the first).
func age(kind: String, t: float) -> float:
	var row := last(kind, t)
	return t - float(row[0]) if not row.is_empty() else INF

## A pulse that jumps to the event's strength on the beat and dies away: strength *
## exp(-age * rate). The strength is a row's second value.
func pulse(kind: String, t: float, rate: float) -> float:
	var row := last(kind, t)
	if row.is_empty():
		return 0.0
	return float(row[1]) * exp(-(t - float(row[0])) * rate)

## Rows of `kind` in (t - span, t], oldest first.
func recent(kind: String, t: float, span: float) -> Array:
	if not _times.has(kind):
		return []
	var first: int = _times[kind].bsearch(t - span, false)
	var upto := _count_upto(kind, t)
	return _rows[kind].slice(first, upto)

## Rows of `kind` that happened between two readings of the clock: (from, to]. When the
## song has looped in between, the rows after `from` and then those up to `to` from the
## loop start. A reading that stepped back a little (the audio clock jitters) or a long
## way ahead (a stall) gives none or only the newest second's worth.
func fresh(kind: String, from: float, to: float) -> Array:
	if not _times.has(kind):
		return []
	if to < from:
		if from - to < 1.0:
			return []
		return _between(kind, from, length) + _between(kind, loop_start - 0.001, to)
	return _between(kind, maxf(from, to - 1.0), to)

func _between(kind: String, from: float, to: float) -> Array:
	var first: int = _times[kind].bsearch(from, false)
	return _rows[kind].slice(first, _count_upto(kind, to))

# --- sections ----------------------------------------------------------------

func section_index(t: float) -> int:
	var found := 0
	for i in sections.size():
		if float(sections[i][1]) <= t:
			found = i
	return found

func section_name(t: float) -> String:
	return str(sections[section_index(t)][0]) if not sections.is_empty() else ""

## When the section that holds t began.
func section_start(t: float) -> float:
	return float(sections[section_index(t)][1]) if not sections.is_empty() else 0.0

## When the first section called `name` begins (-1 if there is none).
func start_of(name: String) -> float:
	for entry in sections:
		if entry[0] == name:
			return float(entry[1])
	return -1.0

## 0-1: how hard the music plays at t.
func energy(t: float) -> float:
	if energy_knots.is_empty():
		return 0.5
	if t <= float(energy_knots[0][0]):
		return float(energy_knots[0][1])
	for i in range(1, energy_knots.size()):
		var t1 := float(energy_knots[i][0])
		if t <= t1:
			var t0 := float(energy_knots[i - 1][0])
			var f := clampf((t - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
			return lerpf(float(energy_knots[i - 1][1]), float(energy_knots[i][1]), f)
	return float(energy_knots[-1][1])

## Which of ALAKAZAR's eight letters a melody note lights: low notes the left, high
## notes the right, so a climbing tune sweeps across the title. The fanfare's pipes
## sit lower than the march's tunes.
func letter_of(row: Array) -> int:
	var low := 67.0 if float(row[0]) < loop_start else 74.0
	var high := 79.0 if float(row[0]) < loop_start else 90.0
	return clampi(int(floorf((float(row[1]) - low) / (high - low) * 8.0)), 0, 7)
