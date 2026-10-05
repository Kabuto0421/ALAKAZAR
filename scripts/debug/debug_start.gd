extends RefCounted
## Debug entry for the Steam build: jump straight into layer 2 with a chosen build.
## Only reachable in debug builds (or with a `user://debug_enabled` file); never in a release export.

static var pending := false
static var build: Dictionary = {}

static func enabled() -> bool:
	return OS.has_feature("debug") or FileAccess.file_exists("user://debug_enabled")

static func launch(tree: SceneTree, chosen: Dictionary) -> void:
	build = chosen
	pending = true
	tree.change_scene_to_file("res://main.tscn")
