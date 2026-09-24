class_name ShogiMovePattern
extends RefCounted

# SPEC: 移動パターンは、将棋風の移動先をローカル座標で表す。
# local x は向きに対する右方向、local y は向きに対する後ろ方向。
# そのため Vector2i(0, -1) は「前方1マス」を意味する。
# SPEC: step_offsets は単発ジャンプ。ray_directions は遮蔽まで伸びる直線移動。
# 武器は DungeonPlayer.WEAPON_LOADOUTS を通じてこれらのパターンを選ぶ。
var piece_id := ""
var display_name := ""
var short_name := ""
var step_offsets: Array = []
var ray_directions: Array = []

func configure(id: String, name: String, short: String, steps: Array, rays: Array) -> void:
	piece_id = id
	display_name = name
	short_name = short
	step_offsets = steps.duplicate()
	ray_directions = rays.duplicate()

func get_destinations(origin: Vector2i, can_stand_on: Callable, forward_dir := Vector2i.UP) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	# SPEC: 移動先は can_stand_on が許可した最終セルだけが合法。ジャンプ系の移動は
	# 途中セルを見ない。
	for offset in step_offsets:
		var step_destination := origin + _to_world_offset(offset, forward_dir)
		if can_stand_on.call(step_destination):
			_add_unique(result, step_destination)

	for direction in ray_directions:
		var world_direction := _to_world_offset(direction, forward_dir)
		var ray_destination := origin + world_direction
		# SPEC: 直線移動は最初の遮蔽セルで止まり、その遮蔽セル自体は含めない。
		while can_stand_on.call(ray_destination):
			_add_unique(result, ray_destination)
			ray_destination += world_direction

	return result

func _to_world_offset(local_offset: Vector2i, forward_dir: Vector2i) -> Vector2i:
	# SPEC: 向きによってローカル将棋盤を回転させる。これにより、各コマを定義し直さず
	# Rキーで移動方向を変えられる。
	var normalized_forward := _normalize_cardinal(forward_dir)
	var right_dir := Vector2i(-normalized_forward.y, normalized_forward.x)
	var back_dir := -normalized_forward
	return right_dir * local_offset.x + back_dir * local_offset.y

func _normalize_cardinal(direction: Vector2i) -> Vector2i:
	if abs(direction.x) > abs(direction.y):
		return Vector2i(signi(direction.x), 0)
	if direction.y != 0:
		return Vector2i(0, signi(direction.y))
	return Vector2i.UP

func _add_unique(destinations: Array[Vector2i], destination: Vector2i) -> void:
	if not destinations.has(destination):
		destinations.append(destination)
