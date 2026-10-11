extends RefCounted
## Shared settings; gameplay reads the cache rather than loading a file every frame.
const BRIGHTNESS_SHADER = preload("res://Scenes/UI/brightness.gdshader")
const BRIGHTNESS_GROUP := "display_brightness"
static var file_path := "user://preferences.cfg"
static var cached_path := ""
static var cached: ConfigFile

static func read() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(file_path)
	cached = config
	cached_path = file_path
	return config

static func value(section: String, key: String, fallback: Variant) -> Variant:
	if cached == null or cached_path != file_path:
		read()
	return cached.get_value(section, key, fallback)

static func set_value(section: String, key: String, setting: Variant) -> void:
	var config := read()
	config.set_value(section, key, setting)
	if config.save(file_path) != OK:
		push_warning("无法保存设置。")

static func dialogue_speed() -> float:
	return clampf(float(value("game", "dialogue_speed", 30.0)), 0.0, 60.0)

static func text_jump_enabled() -> bool:
	return bool(value("game", "text_jump", true))

static func text_sway_enabled() -> bool:
	return bool(value("game", "text_sway", true))

static func brightness() -> float:
	return clampf(float(value("display", "brightness", 0.0)), -50.0, 50.0)

static func attach_brightness(canvas: SubViewportContainer) -> void:
	var material := ShaderMaterial.new()
	material.shader = BRIGHTNESS_SHADER
	material.set_shader_parameter("brightness", brightness())
	canvas.material = material
	canvas.add_to_group(BRIGHTNESS_GROUP)

static func apply_brightness() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null: return
	for canvas in tree.get_nodes_in_group(BRIGHTNESS_GROUP):
		(canvas.material as ShaderMaterial).set_shader_parameter("brightness", brightness())

static func set_brightness(setting: float) -> void:
	set_value("display", "brightness", clampf(setting, -50.0, 50.0))
	apply_brightness()

static func apply_display() -> void:
	var config := read()
	Engine.max_fps = int(config.get_value("display", "frame_limit", 60))
	apply_brightness()
	if DisplayServer.get_name() == "headless":
		return
	var fullscreen := bool(config.get_value("display", "fullscreen", false))
	var previous_mode := DisplayServer.window_get_mode()
	var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if previous_mode != target_mode:
		DisplayServer.window_set_mode(target_mode)
	if not fullscreen:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		var window_size: Vector2i = config.get_value("display", "window_size", Vector2i(1280, 720))
		if DisplayServer.window_get_size() != window_size or previous_mode != target_mode:
			DisplayServer.window_set_size(window_size)
			var usable := DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(usable.position + (usable.size - window_size) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if config.get_value("display", "vsync", true) else DisplayServer.VSYNC_DISABLED)

static func set_display(key: String, setting: Variant) -> void:
	set_value("display", key, setting)
	apply_display()

static func save_audio(settings: Dictionary) -> void:
	var config := read()
	for key in settings:
		config.set_value("audio", key, settings[key])
	if config.save(file_path) != OK:
		push_warning("无法保存声音设置。")

static func set_fullscreen(enabled: bool) -> void:
	set_display("fullscreen", enabled)

static func save_bindings(bindings: Dictionary) -> Error:
	var config := read()
	for action in bindings: config.set_value("input", action, bindings[action])
	var error := config.save(file_path)
	if error != OK: read()
	return error
