extends RefCounted

# Measurements refer to the 480 px cells in sword-attack-directions.png.
# Anchors are the midpoint between the boots and the ground baseline, excluding VFX.
const CELL := 480.0
const COUNTS := [6, 5, 5, 5]
const FOOT_ANCHORS = [
	[Vector2(260.75, 456), Vector2(265.0, 455), Vector2(261.25, 455), Vector2(261.5, 455), Vector2(261.5, 456), Vector2(260.75, 456)],
	[Vector2(242.75, 418), Vector2(254.25, 430), Vector2(211.75, 448), Vector2(206.75, 425), Vector2(212.75, 423)],
	[Vector2(240.5, 434), Vector2(246.25, 431), Vector2(226.0, 400), Vector2(225.0, 422), Vector2(240.25, 426)],
	[Vector2(237.25, 418), Vector2(225.75, 430), Vector2(268.25, 448), Vector2(273.25, 425), Vector2(267.25, 423)],
]
const HEAD_WIDTHS = [[115, 96, 95, 94, 94, 115], [121, 123, 116, 131, 133], [118, 110, 103, 106, 99], [121, 123, 116, 131, 133]]
const IDLE_FOOT_ANCHORS = [Vector2(2.2983, 20.105), Vector2(-6.2762, 20.105), Vector2(0.0525, 19.8619), Vector2(7.116, 20.105)]
const TARGET_HEAD_WIDTHS = [20.3315, 21.5691, 20.7845, 20.8619]

# Entries are [frame, duration]. -1 draws the exact equipped standing sprite.
# Hold the loaded stance and contact pose, then recover briefly.
const WINDUP_DURATION := 0.25
const UP_WINDUP_DURATION := 0.20
const SLASH_DURATION := 0.2
const SEQUENCES = [
	[[-1,0.040],[1,UP_WINDUP_DURATION],[2,0.025],[3,SLASH_DURATION],[4,0.065],[-1,0.090]],
	[[-1,0.035],[0,0.045],[1,WINDUP_DURATION],[2,SLASH_DURATION],[3,0.045],[4,0.065],[-1,0.080]],
	[[-1,0.035],[0,0.060],[1,WINDUP_DURATION],[2,SLASH_DURATION],[3,0.065],[-1,0.090]],
	[[-1,0.035],[0,0.045],[1,WINDUP_DURATION],[2,SLASH_DURATION],[3,0.045],[4,0.065],[-1,0.080]],
]
const IMPACT_FRAMES := [3, 2, 2, 2]

static func duration(direction: int) -> float:
	var total := 0.0
	for beat in SEQUENCES[direction]:
		total += float(beat[1])
	return total

static func impact_time(direction: int) -> float:
	var elapsed := 0.0
	for beat in SEQUENCES[direction]:
		if int(beat[0]) == IMPACT_FRAMES[direction]:
			return elapsed
		elapsed += float(beat[1])
	return elapsed

static func frame_at(direction: int, elapsed: float) -> int:
	for beat in SEQUENCES[direction]:
		if elapsed < float(beat[1]):
			return int(beat[0])
		elapsed -= float(beat[1])
	return -1

static func frame_rect(direction: int, frame: int) -> Rect2:
	var factor: float = TARGET_HEAD_WIDTHS[direction] / float(HEAD_WIDTHS[direction][frame])
	var foot: Vector2 = FOOT_ANCHORS[direction][frame]
	var target: Vector2 = IDLE_FOOT_ANCHORS[direction]
	return Rect2((target - foot * factor).round(), Vector2.ONE * CELL * factor)
