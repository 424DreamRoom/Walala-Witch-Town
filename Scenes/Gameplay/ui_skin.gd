extends RefCounted
## Framewright's original 1x artwork, paired with the project's Chinese font.
static var THEME: Theme = preload("res://Art/Source/aseprite_source.gd").theme("res://Art/UI/FramewrightLite/themes/walala_theme.tres")
const INK := Color("3a2418")
const MUTED_INK := Color("70543a")

static func panel_style(compact: bool = false) -> StyleBox:
	return THEME.get_stylebox("panel", "PopupPanel" if compact else "Panel")

static func compact_button(button: Button) -> void:
	for state in ["normal", "hover", "hover_pressed", "pressed", "disabled", "focus"]:
		var style: StyleBox = THEME.get_stylebox(state, "Button").duplicate()
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		button.add_theme_stylebox_override(state, style)
