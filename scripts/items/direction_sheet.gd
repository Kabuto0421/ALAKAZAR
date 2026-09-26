extends RefCounted
## Optional four-direction art for placed fairies.
## assets/sprites/spirits/<id>_directions.png is a square split 2x2:
## top-left = up, top-right = right, bottom-left = down, bottom-right = left.
## Without that file the fairy's normal icon is used.

const FRAMES = {Vector2i.UP: Vector2i(0,0), Vector2i.RIGHT: Vector2i(1,0), Vector2i.DOWN: Vector2i(0,1), Vector2i.LEFT: Vector2i(1,1)}
static var _cache := {}

static func path_for(id: String) -> String:
	return "res://assets/sprites/spirits/%s_directions.png" % id

static func texture_for(id: String) -> Texture2D:
	if not _cache.has(id):
		var path := path_for(id)
		_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _cache[id]

static func region(texture: Texture2D, direction: Vector2i) -> Rect2:
	var half := texture.get_size() / 2.0
	return Rect2(Vector2(FRAMES.get(direction, Vector2i.ZERO)) * half, half)

## Draws the frame for `direction` and returns true, or returns false when there is no sheet.
static func paint(canvas: CanvasItem, center: Vector2, id: String, direction: Vector2i, factor: float = 1.0) -> bool:
	var texture := texture_for(id)
	if texture == null or not FRAMES.has(direction):
		return false
	var side := 64.0 * factor
	canvas.draw_texture_rect_region(texture, Rect2(center - Vector2.ONE * side / 2, Vector2.ONE * side), region(texture, direction))
	return true
