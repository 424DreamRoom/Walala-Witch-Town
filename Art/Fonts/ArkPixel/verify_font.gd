extends SceneTree

const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const OUT = "res://Art/Fonts/FusionPixel/Verification/"
var failures := 0
var capture := false
var lane
var loop

func _initialize() -> void:
	capture = "--font-capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("FONT TEST ", title, ": ", "PASS" if ok else "FAIL")
	if not ok:
		failures += 1

func frames() -> void:
	for i in range(3):
		await process_frame

func check_text(text: String) -> void:
	for character in text:
		if character.unicode_at(0) > 32 and not UIFont.get_font().has_char(character.unicode_at(0)):
			check("missing glyph U+%04X" % character.unicode_at(0), false)

func check_controls(node: Node) -> void:
	if node is Label or node is Button:
		check("pixel font: " + node.text.left(20), node.get_theme_font("font") == UIFont.get_font())
		check("12px text: " + node.text.left(20), node.get_theme_font_size("font_size") == UIFont.BASE_SIZE)
		check_text(node.text)
		if node is Button and not node is CheckButton:
			var width = UIFont.get_font().get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.BASE_SIZE).x
			check("button text fits: " + node.text, width + node.get_theme_stylebox("normal").get_minimum_size().x <= node.size.x)
	if node is RichTextLabel:
		for key in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
			check("rich text " + key, node.get_theme_font(key) == UIFont.get_font())
		check_text(node.text)
	if node is Control and node.get_parent() is Control and node.is_visible_in_tree():
		var parent: Control = node.get_parent()
		check("panel contains " + node.get_class(), node.position.x >= 0 and node.position.y >= 0 and node.position.x + node.size.x <= parent.size.x and node.position.y + node.size.y <= parent.size.y)
	for child in node.get_children():
		check_controls(child)

func shot(title: String) -> void:
	if not capture:
		return
	await frames()
	RenderingServer.force_draw(false)
	check("capture " + title, lane.viewport.get_texture().get_image().save_png(OUT + title + ".png") == OK)
	check("capture window " + title, root.get_texture().get_image().save_png(OUT + title + "_window.png") == OK)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var font: FontFile = UIFont.get_font()
	print("FONT FAMILY ", font.get_font_name(), " STYLE ", font.get_font_style_name())
	check("bundled font", font.resource_path == UIFont.FONT_PATH)
	check("simplified Chinese pixel font", "Fusion Pixel" in font.get_font_name() and "zh-Hans" in font.get_font_name())
	check("no antialiasing", font.antialiasing == TextServer.FONT_ANTIALIASING_NONE)
	check("no MSDF", not font.multichannel_signed_distance_field)
	check("no system fallback", not font.allow_system_fallback)
	check("no subpixel positioning", font.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_DISABLED)
	check("no hinting", font.hinting == TextServer.HINTING_NONE)
	check("native oversampling", is_equal_approx(font.oversampling, 1.0))
	# Check CJK in all gameplay strings, including currently hidden error/settlement states.
	var missing := {}
	for path in ["res://Scenes/Gameplay/game_loop.gd", "res://Scenes/Gameplay/loop_state.gd", "res://Scenes/Gameplay/play_area.gd", "res://Sounds/Walala/audio_manager.gd", "res://Sounds/Walala/CREDITS.txt"]:
		for character in FileAccess.get_file_as_string(path):
			var code = character.unicode_at(0)
			if code >= 0x3000 and code <= 0x9fff and not font.has_char(code):
				missing[character] = true
	print("MISSING CJK ", missing.keys())
	check("all current CJK glyphs", missing.is_empty())
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames()
	lane.automation = true
	loop = lane.get_node("GameLoop")
	loop.paused_for_test = true
	loop.audio.music_muted = true
	loop.audio.effects_muted = true
	loop.audio.apply_volume()
	var inherited := Label.new()
	loop.ui.add_child(inherited)
	check("new controls inherit font", inherited.get_theme_font("font") == font)
	check("new controls inherit 12px", inherited.get_theme_font_size("font_size") == UIFont.BASE_SIZE)
	check("tooltips inherit font", inherited.get_theme_font("font", "TooltipLabel") == font)
	check("tooltips inherit 12px", inherited.get_theme_font_size("font_size", "TooltipLabel") == UIFont.BASE_SIZE)
	inherited.queue_free()
	await frames()
	check_controls(loop.ui)
	await shot("town")
	loop.enter("field")
	await shot("field")
	loop.enter("restaurant")
	loop.state.phase = "night"
	loop.state.materials = [6, 6, 6]
	loop.state.admit()
	loop._refresh()
	await shot("restaurant")
	loop.state.end_phase()
	loop._refresh()
	await frames()
	check_controls(loop.ui)
	await shot("settlement")
	loop.audio.panel.show()
	await frames()
	check_controls(loop.audio.panel)
	await shot("settings")
	loop.audio.credits.show()
	await frames()
	check_controls(loop.audio.credits)
	await shot("credits")
	if capture:
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		await frames()
		loop.audio.panel.hide()
		loop.audio.credits.hide()
		loop.state.next_day()
		loop.enter("town")
		await shot("town_1920")
	lane.queue_free()
	await frames()
	print("FONT VERIFY END failures=", failures)
	quit(0 if failures == 0 else 1)
