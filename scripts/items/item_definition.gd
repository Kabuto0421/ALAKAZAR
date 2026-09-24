extends Resource

enum Target { WEAPON_EMPTY, ANY_EMPTY }
@export var id: String
@export var title: String
@export_multiline var description: String
@export var color := Color.WHITE
@export var icon: Texture2D
@export var target: Target = Target.WEAPON_EMPTY
@export var directional := false
@export var ap_cost := 1
@export var initial_count := 1
@export var effect: Script
