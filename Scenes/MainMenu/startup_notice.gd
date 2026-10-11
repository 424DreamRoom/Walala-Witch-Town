extends Node
## One launch-only notice; gameplay returns directly to the title scene.
const MENU_SCENE := "res://Scenes/MainMenu/main_menu.tscn"
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const SavingIndicator = preload("res://Scenes/Save/saving_indicator.gd")
const AUTO_CONTINUE_TIME := 6.5
const MIN_READ_TIME := 1.2
const FADE_TIME := 0.35
const COPY := [
	"游戏支持自动保存",
	"当屏幕右下角出现该图标时，表示正在保存进度",
	"保存中断可能导致进度丢失。",
]
var viewport: SubViewport
var container: SubViewportContainer
var canvas: Control
var content: Control
var icon
var heading: Label
var paragraphs: Array[Label] = []
var continue_button: Button
var error_label: Label
var elapsed := 0.0
var transitioning := false

func _ready() -> void:
	Localization.apply_saved_language()
	InputBindings.apply_saved_bindings()
	# Preserve the existing direct-to-game command-line verification routes.
	for argument in OS.get_cmdline_user_args():
		if argument in ["--lane-test", "--lane-capture", "--witch-capture", "--no-loop"]:
			get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
			set_process(false)
			return
	container = SubViewportContainer.new()
	container.name = "PixelCanvas"
	container.size = Vector2(640, 360)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)
	Preferences.attach_brightness(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.disable_3d = true
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(viewport)
	canvas = Control.new()
	canvas.name = "SaveNotice"
	canvas.size = Vector2(640, 360)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(canvas)
	var background := ColorRect.new()
	background.size = canvas.size
	background.color = Color("211b29")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	content = Control.new()
	content.size = canvas.size
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(content)
	_label("哗啦啦魔女镇", Rect2(110, 68, 420, 18), UIFont.BASE_SIZE, Color("b7a3b3"))
	icon = SavingIndicator.new()
	icon.name = "SaveIconDemo"
	content.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	icon.position = Vector2(288, 92)
	icon.size = Vector2(64, 60)
	icon.scale = Vector2.ONE
	# Demonstration only: this animation never reads or writes a save slot.
	icon.begin_save()
	icon.caption.hide()
	# Fusion Pixel's 12px glyphs stay intact at native size and whole multiples.
	heading = _label("关于保存", Rect2(110, 140, 420, 30), UIFont.BASE_SIZE * 2)
	var rule := ColorRect.new()
	rule.position = Vector2(260, 174)
	rule.size = Vector2(120, 1)
	rule.color = Color("796476")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rule)
	for index in range(COPY.size()):
		var paragraph := _label(COPY[index], Rect2(80, 184 + index * 24, 480, 24))
		paragraph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		paragraphs.append(paragraph)
	continue_button = Button.new()
	continue_button.name = "Continue"
	continue_button.position = Vector2(278, 272)
	continue_button.size = Vector2(84, 24)
	continue_button.text = tr("继续")
	continue_button.disabled = true
	UIFont.apply_control(continue_button)
	continue_button.pressed.connect(_enter_menu)
	content.add_child(continue_button)
	error_label = _label("", Rect2(80, 307, 480, 16), UIFont.BASE_SIZE, Color("efb294"))
	Localization.language_changed.connect(_refresh_language)
	get_viewport().size_changed.connect(_fit_canvas)
	Preferences.apply_display()
	_fit_canvas()
	content.modulate.a = 0.0
	create_tween().tween_property(content, "modulate:a", 1.0, FADE_TIME)

func _label(text: String, rect: Rect2, font_size: int = UIFont.BASE_SIZE, color: Color = Color("f7e8ca")) -> Label:
	var label := Label.new()
	label.text = tr(text)
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	UIFont.apply_control(label, font_size)
	content.add_child(label)
	return label

func _fit_canvas() -> void:
	var available := get_viewport().get_visible_rect().size
	var factor := minf(available.x / 640.0, available.y / 360.0)
	if factor >= 1.0: factor = floorf(factor)
	container.scale = Vector2.ONE * maxf(factor, 0.1)
	container.position = ((available - Vector2(640, 360) * factor) / 2.0).floor()

func _refresh_language(_locale: String) -> void:
	heading.text = tr("关于保存")
	continue_button.text = tr("继续")
	for index in range(COPY.size()): paragraphs[index].text = tr(COPY[index])

func _process(delta: float) -> void:
	if transitioning: return
	elapsed += delta
	if elapsed >= MIN_READ_TIME and continue_button.disabled:
		continue_button.disabled = false
		continue_button.grab_focus()
	if elapsed >= AUTO_CONTINUE_TIME:
		_enter_menu()

func _enter_menu() -> void:
	if transitioning or elapsed < MIN_READ_TIME: return
	transitioning = true
	continue_button.disabled = true
	set_process(false)
	var error := await SceneTransition.change_scene(MENU_SCENE)
	if error != OK:
		transitioning = false
		content.modulate.a = 1.0
		continue_button.disabled = false
		continue_button.grab_focus()
		error_label.text = tr("无法进入主菜单。")
