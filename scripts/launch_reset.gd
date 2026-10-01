extends RefCounted
## The trial version forgets its progress every time the game is launched: the fairy book
## (which fairies the title screen shows in colour) and the achievements start empty each
## time. Turn DEMO_RESET off when the full game keeps them.
##
## start_session() is called by the title screen and does its work once per launch (coming
## back to the title after a defeat does not wipe anything).

const DEMO_RESET := true
const FairyBook = preload("res://scripts/fairy_book.gd")
const Achievements = preload("res://scripts/title/achievements.gd")

static var started := false

static func start_session() -> void:
	if started:
		return
	started = true
	# The tests and screenshot tools run with recording off: they leave the files alone.
	if DEMO_RESET and FairyBook.recording:
		FairyBook.wipe()
		Achievements.wipe()
