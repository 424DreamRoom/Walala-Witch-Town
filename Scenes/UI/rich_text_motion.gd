extends RichTextEffect
## Pixel-aligned character motion; preferences are read without reparsing text.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
var bbcode: String

func _init(effect: String = "jump") -> void:
	bbcode = effect

static func _number(environment: Dictionary, key: String, fallback: float, minimum: float, maximum: float) -> float:
	var value: Variant = environment.get(key, fallback)
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value), minimum, maximum)

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	if not char_fx.visible: return true
	if bbcode == "jump":
		if not Preferences.text_jump_enabled(): return true
		var height := _number(char_fx.env, "height", 2.0, 0.0, 4.0)
		var speed := _number(char_fx.env, "speed", 1.8, 0.0, 6.0)
		var phase := char_fx.elapsed_time * TAU * speed + char_fx.relative_index * 0.55
		char_fx.offset.y -= roundf(height * (1.0 - cos(phase)) * 0.5)
	elif bbcode == "sway":
		if not Preferences.text_sway_enabled(): return true
		var strength := _number(char_fx.env, "strength", 2.0, 0.0, 3.0)
		var speed := _number(char_fx.env, "speed", 1.2, 0.0, 4.0)
		# A shared phase moves the whole span gently left/right without changing
		# its baseline or spacing. Speed is measured in complete cycles/second.
		var phase := char_fx.elapsed_time * TAU * speed
		char_fx.offset.x += roundf(sin(phase) * strength)
	return true
