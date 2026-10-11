extends Control
## Original pixel art on the shared 640x360 canvas; no imported game assets.
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const MIN_SAVING_TIME := 0.9
const SUCCESS_HOLD := 0.4
const ERROR_HOLD := 1.8
const FADE_TIME := 0.2
const PALETTE := {
	"o": Color("443345"), "H": Color("ded0ea"),
	"L": Color("ac92c3"), "S": Color("786389"),
	"G": Color("dfb66f"), "R": Color("b38758"), "C": Color("fff0c2"),
}
const HAT := [
	"                     oooo",
	"                   ooHHHo",
	"                 ooHHHoo",
	"                oHHLLLo",
	"               oHHLLLLo",
	"              oHHLLLLo",
	"             oHHLLLLLo",
	"            oHHLLLLLLo",
	"           oHHLLLLLLLo",
	"          oHHLLLLLLLLo",
	"         oHHLLLLLLLLLLo",
	"        oHHLLLLLLLLLLLo",
	"        oHLLLLLLLLLLLSo",
	"       oHLLLLLLLLLLSSSo",
	"       oLLLLLLLLLSSSSSo",
	"      oLLLLLLLLSSSSSSSo",
	"      ooooooooooooooooo",
	"     oGGGGGGGCCCGRRRRRo",
	"     oGGGGGGGCoCGRRRRRo",
	"    ooGGGGGGGCCCGRRRRRoo",
	"  ooHHLLLLLLLLLLLLSSSSSSoo",
	"ooHHLLLLLLLLLLLLLSSSSSSSSoo",
	"oHHLLLLLLLLLLLLSSSSSSSSSSSSo",
	"ooLLLLLLLLSSSSSSSSSSSSSSSSoo",
	"  ooooSSSSSSSSSSSSSSSSoooo",
	"      oooooooooooooooo",
]
var caption: Label
var elapsed := 0.0
var motion_time := 0.0
var saving_until := MIN_SAVING_TIME
var hide_at := 0.0
var result_received := false
var succeeded := false
var phase := "saving"
var last_frame := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -76
	offset_top = -72
	offset_right = -12
	offset_bottom = -12
	caption = Label.new()
	caption.position = Vector2(0, 42)
	caption.size = Vector2(64, 18)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color", Color("fff0d0"))
	caption.add_theme_color_override("font_shadow_color", Color("302235"))
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 1)
	UIFont.apply_control(caption)
	add_child(caption)
	Localization.language_changed.connect(_refresh_language)
	hide()
	set_process(false)

func begin_save() -> void:
	if not visible:
		motion_time = 0.0
	elapsed = 0.0
	saving_until = MIN_SAVING_TIME
	result_received = false
	phase = "saving"
	modulate.a = 1.0
	_refresh_language()
	show()
	set_process(true)
	queue_redraw()

func finish_save(success: bool) -> void:
	succeeded = success
	result_received = true
	saving_until = maxf(elapsed, MIN_SAVING_TIME)
	hide_at = saving_until + (SUCCESS_HOLD if success else ERROR_HOLD) + FADE_TIME

func remaining_time() -> float:
	return maxf(0.0, hide_at - elapsed) if visible and result_received else 0.0

func _refresh_language(_locale: String = "") -> void:
	caption.text = tr({"saving": "保存中", "success": "已保存", "error": "保存失败"}[phase])

func _process(delta: float) -> void:
	elapsed += delta
	motion_time += delta
	if result_received and elapsed >= saving_until and phase == "saving":
		phase = "success" if succeeded else "error"
		_refresh_language()
	if result_received and elapsed >= hide_at:
		hide()
		set_process(false)
		return
	modulate.a = clampf((hide_at - elapsed) / FADE_TIME, 0.0, 1.0) if result_received else 1.0
	var frame := int(motion_time * 12.0)
	if frame != last_frame:
		last_frame = frame
		queue_redraw()

func _box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)

func _star(center: Vector2, radius: int, color: Color) -> void:
	_box(center.x - radius, center.y, radius * 2 + 1, 1, Color("443345"))
	_box(center.x, center.y - radius, 1, radius * 2 + 1, Color("443345"))
	if radius > 1:
		_box(center.x - radius + 1, center.y, radius * 2 - 1, 1, color)
		_box(center.x, center.y - radius + 1, 1, radius * 2 - 1, color)

func _draw() -> void:
	var beat := floorf(motion_time * 12.0) / 12.0
	var bob := roundf(sin(beat * TAU / MIN_SAVING_TIME) * 2.0) if phase == "saving" else 0.0
	var tip := roundf(sin(beat * TAU / MIN_SAVING_TIME)) if phase == "saving" else 0.0
	_box(24, 35, 19, 2, Color(0.12, 0.08, 0.16, 0.45))
	_box(27, 37, 13, 1, Color(0.12, 0.08, 0.16, 0.25))
	# Draw horizontal pixel runs; only the soft tip bends, keeping the brim crisp.
	for y in range(HAT.size()):
		var row: String = HAT[y]
		var x := 0
		while x < row.length():
			var pixel := row[x]
			var end := x + 1
			while end < row.length() and row[end] == pixel:
				end += 1
			if PALETTE.has(pixel):
				_box(18 + x + (tip if y < 9 else 0.0), 6 + y + bob, end - x, 1, PALETTE[pixel])
			x = end
	if phase == "saving":
		for i in range(3):
			var cycle := fposmod(beat / MIN_SAVING_TIME + i / 3.0, 1.0)
			var point: Vector2 = [Vector2(12, 24), Vector2(52, 13), Vector2(35, 2)][i]
			point.y -= roundf(cycle * 4.0)
			_star(point, 3 if cycle < 0.5 else 2, Color("ffe4a2"))
		for i in range(3):
			_box(28 + i * 4, 39, 2, 2, Color("ffe4a2") if int(beat * 6.0) % 3 == i else Color("786389"))
	elif phase == "success":
		_star(Vector2(51, 10), 3, Color("fff0c2"))
		_box(48, 29, 11, 9, Color("443345"))
		_box(50, 32, 2, 2, Color("b9d599"))
		_box(52, 34, 2, 2, Color("b9d599"))
		_box(54, 30, 2, 4, Color("b9d599"))
		_box(56, 28, 2, 3, Color("b9d599"))
	else:
		_box(49, 27, 8, 12, Color("443345"))
		_box(52, 28, 2, 6, Color("f0ad83"))
		_box(52, 36, 2, 2, Color("f0ad83"))
