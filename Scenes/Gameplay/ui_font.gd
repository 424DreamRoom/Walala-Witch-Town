extends RefCounted
## Shared pixel-font configuration for the 640x360 UI canvas.
const FONT_PATH := "res://Art/Fonts/FusionPixel/FusionPixel12Proportional.ttf"
const PIXEL_FONT: Font = preload(FONT_PATH)
const BASE_SIZE := 12

static func get_font() -> Font:
	return PIXEL_FONT

static func apply_control(control: Control, size: int = BASE_SIZE) -> void:
	control.add_theme_font_override("font", get_font())
	control.add_theme_font_size_override("font_size", size)

static func apply_rich_text(control: RichTextLabel, size: int = BASE_SIZE) -> void:
	for name in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
		control.add_theme_font_override(name, get_font())
	control.add_theme_font_size_override("normal_font_size", size)
