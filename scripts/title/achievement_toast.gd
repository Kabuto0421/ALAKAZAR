extends CanvasLayer
## The "achievement unlocked" banner that slides down from the top of the screen for a few
## seconds. One node per screen (BattleView and RunView each add one); `show_new(ids)`
## queues the achievements to announce, one after another.

const Achievements = preload("res://scripts/title/achievements.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const GOLD := Color("f4d56f")
const SHOW_TIME := 4.0

## The id being shown, "" when idle.
var current := ""
var _queue: Array[String] = []
var _left := 0.0
var _banner: Panel
var _icon: TextureRect
var _name: Label

func _init() -> void:
	layer = 80
	# The game's 1152x720 design space, scaled to the 1728x1080 window.
	var holder := Control.new()
	holder.scale = Vector2.ONE * 1.5
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_banner = Panel.new()
	_banner.size = Vector2(480, 84)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b1218")
	style.border_color = GOLD
	style.set_border_width_all(3)
	_banner.add_theme_stylebox_override("panel", style)
	holder.add_child(_banner)
	_icon = TextureRect.new()
	_icon.position = Vector2(8, 8)
	_icon.size = Vector2(68, 68)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_banner.add_child(_icon)
	var head := _label("実績解除！", 20, GOLD)
	head.position = Vector2(92, 8)
	_banner.add_child(head)
	_name = _label("", 26, Color("fff6e0"))
	_name.position = Vector2(92, 36)
	_name.size = Vector2(376, 40)
	_banner.add_child(_name)
	_banner.visible = false

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _process(delta: float) -> void:
	if current != "":
		_left -= delta
		if _left <= 0.0:
			current = ""
	if current == "" and not _queue.is_empty():
		_start(_queue.pop_front())
	_banner.visible = current != ""
	if current != "":
		var rise := clampf((SHOW_TIME - _left) / 0.3, 0.0, 1.0) * clampf(_left / 0.4, 0.0, 1.0)
		_banner.position = Vector2(336, -90 + 110 * rise)

## Announce achievements (ids as Achievements.check returns them).
func show_new(ids: Array) -> void:
	for id in ids:
		_queue.append(str(id))
	if current == "" and not _queue.is_empty():
		_start(_queue.pop_front())

func _start(id: String) -> void:
	current = id
	_left = SHOW_TIME
	var entry: Dictionary = Achievements.all().filter(func(e: Dictionary) -> bool: return e.id == id)[0]
	_icon.texture = load(entry.icon)
	_name.text = str(entry.title)
	_name.add_theme_color_override("font_color", Color(str(entry.get("title_color", "fff6e0"))))
	# Long names get a smaller type so they fit the banner.
	_name.add_theme_font_size_override("font_size", 26 if str(entry.title).length() <= 14 else 19)
