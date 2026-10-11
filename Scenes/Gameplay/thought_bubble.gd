extends Panel
## Short-lived character thoughts, drawn and positioned on the native pixel canvas.
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const I18n = preload("res://Localization/localized_text.gd")
const MAX_TEXT_WIDTH := 168.0
const INK := Color("573d35")
const PAPER := Color("fff1d2")
const THOUGHTS := {
	"储水已补满。": "水装满啦。",
	"储水已满。": "已经满满的啦。",
	"夜间无法耕作。": "天黑了，田地也睡了。",
	"需要法杖。": "我的法杖没带着呢。",
	"储水已空。": "哎呀，水用光了。",
	"土地已翻好。": "这块地松软多了。",
	"已翻好 %d 格土地。": "翻好了 %d 格，真不错。",
	"已播下香草种子。": "小种子，好好长大吧。",
	"香草种子不足。": "种子用完了呀。",
	"背包已满，无法收获。": "唔，背包放不下了。",
	"收获香草 ×1、种子 ×2！": "香草 ×1，种子 ×2，收好啦！",
	"浇水完成，香草会在进入次日时生长。": "喝饱水，慢慢长吧。",
	"今天已经浇过水。": "今天已经浇过啦。",
}
var loop
var caption: Label
var dots_below := true
var dot_x := 0.0

func _init() -> void:
	name = "WitchThought"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	caption = Label.new()
	caption.name = "ThoughtText"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", INK)
	UIFont.apply_control(caption)
	add_child(caption)
	hide()

static func message_text(state) -> String:
	if state.message == "仅白天持有法杖时可补水。":
		return I18n.prompt("我的法杖没带着呢。" if not state.has_tool("wand") else "天黑了，没法补水呢。")
	var formatted: bool = state.message == state.formatted_message and not state.message_source.is_empty()
	var source: String = state.message_source if formatted else state.message
	return I18n.format(THOUGHTS.get(source, source), state.message_arguments if formatted else [])

func set_message(text: String) -> void:
	if caption.text == text:
		return
	var font := UIFont.get_font()
	var width := clampf(ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.BASE_SIZE).x), 32.0, MAX_TEXT_WIDTH)
	# Clear the previous wrap height before changing width, then use Label's
	# own font and line-spacing metrics rather than an estimated text height.
	caption.text = ""
	caption.size = Vector2(width, 0)
	caption.text = text
	caption.size = Vector2(width, ceilf(caption.get_minimum_size().y))
	size = caption.size + Vector2(16, 12)
	caption.position = Vector2(8, 6)
	queue_redraw()

func _process(_delta: float) -> void:
	if get_tree().paused:
		hide()
		return
	if not visible or loop == null:
		return
	var feet: Vector2 = loop.lane.player.get_global_transform_with_canvas().origin.round()
	var head: Vector2 = feet - Vector2(0, loop.lane.CHARACTER_SIZE.y)
	var top: float = head.y - size.y - 12.0
	dots_below = top >= 68.0
	if not dots_below:
		top = feet.y + 12.0
	position = Vector2(clampf(head.x - size.x / 2.0, 8.0, 632.0 - size.x), clampf(top, 68.0, 304.0 - size.y)).round()
	dot_x = roundf(clampf(head.x - position.x, 8.0, size.x - 8.0))
	modulate.a = clampf(loop.message_left / 0.3, 0.0, 1.0)
	queue_redraw()

func _outline(rect: Rect2) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([
		Vector2(p.x + 3, p.y), Vector2(e.x - 3, p.y),
		Vector2(e.x, p.y + 3), Vector2(e.x, e.y - 3),
		Vector2(e.x - 3, e.y), Vector2(p.x + 3, e.y),
		Vector2(p.x, e.y - 3), Vector2(p.x, p.y + 3),
	])

func _draw() -> void:
	draw_colored_polygon(_outline(Rect2(Vector2(2, 2), size)), Color(0.15, 0.1, 0.12, 0.22))
	draw_colored_polygon(_outline(Rect2(Vector2.ZERO, size)), INK)
	draw_colored_polygon(_outline(Rect2(Vector2.ONE, size - Vector2(2, 2))), PAPER)
	draw_line(Vector2(6, 2), Vector2(size.x - 6, 2), Color("fff8e8"))
	var direction := 1.0 if dots_below else -1.0
	var edge := size.y if dots_below else 0.0
	for index in range(2):
		var extent := 4.0 if index == 0 else 2.0
		var center := Vector2(dot_x + index * 2.0, edge + direction * (4.0 + index * 6.0))
		var dot := Rect2((center - Vector2.ONE * extent / 2.0).round(), Vector2.ONE * extent)
		draw_rect(dot.grow(1), INK)
		draw_rect(dot, PAPER)
