extends Resource

## WEAPON_ANY: any tile in weapon range, including one an enemy stands on.
## UNREACHED: an empty tile none of the carried weapons reaches.
## SELF: the player's own tile (the fairy is simply called).
enum Target { WEAPON_EMPTY, ANY_EMPTY, WEAPON_ANY, UNREACHED, SELF }
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
