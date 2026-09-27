extends Resource

## WEAPON_ANY: any tile in weapon range, including one an enemy stands on.
enum Target { WEAPON_EMPTY, ANY_EMPTY, WEAPON_ANY }
@export var id: String
@export var title: String
@export_multiline var description: String
## One short line for the battle hand (the full text lives in `description`).
@export var summary: String
@export var color := Color.WHITE
@export var icon: Texture2D
@export var target: Target = Target.WEAPON_EMPTY
@export var directional := false
@export var ap_cost := 1
@export var initial_count := 1
@export var effect: Script
