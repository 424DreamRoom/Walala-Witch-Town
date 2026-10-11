extends RefCounted
## Shared pixel-font configuration for the 640x360 UI canvas.
const FONT_PATH := "res://Art/Fonts/FusionPixel/FusionPixel12Proportional.ttf"
const PIXEL_FONT: Font = preload(FONT_PATH)
const BASE_SIZE := 12
static var bold_font: Font = _styled_font(0.7, false)
static var italic_font: Font = _styled_font(0.0, true)
static var bold_italic_font: Font = _styled_font(0.7, true)

static func _styled_font(weight: float, italic: bool) -> FontVariation:
	var variant := FontVariation.new()
	variant.base_font = PIXEL_FONT
	variant.variation_embolden = weight
	if italic: variant.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.2, 1), Vector2.ZERO)
	return variant

static func get_font() -> Font:
	return PIXEL_FONT

static func apply_control(control: Control, size: int = BASE_SIZE) -> void:
	control.add_theme_font_override("font", get_font())
	control.add_theme_font_size_override("font_size", size)

static func apply_rich_text(control: RichTextLabel, size: int = BASE_SIZE) -> void:
	control.add_theme_font_override("normal_font", get_font())
	control.add_theme_font_override("mono_font", get_font())
	control.add_theme_font_override("bold_font", bold_font)
	control.add_theme_font_override("italics_font", italic_font)
	control.add_theme_font_override("bold_italics_font", bold_italic_font)
	for name in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		control.add_theme_font_size_override(name, size)
