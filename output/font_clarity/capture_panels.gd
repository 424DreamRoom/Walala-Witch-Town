extends SceneTree

const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Business = preload("res://Scenes/Businesses/business_interior.gd")
const OUT := "res://output/font_clarity/"
var failures := 0

class SilentBindings extends RefCounted:
	func bind_button(_button: Button) -> void:
		pass

class SilentAudio extends RefCounted:
	var ui_audio = SilentBindings.new()

class PanelContext extends RefCounted:
	var audio = SilentAudio.new()

func _initialize() -> void:
	Preferences.file_path = OUT + "preferences.cfg"
	Saves.directory = OUT + "saves"
	Saves.end_session()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	print("FONT CLARITY ", title, ": ", "PASS" if ok else "FAIL")
	if not ok: failures += 1

func frames() -> void:
	for tick in range(4): await process_frame

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var container := SubViewportContainer.new()
	container.size = Vector2(640, 360)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(viewport)
	for kind in ["store", "blacksmith"]:
		var business = Business.new()
		business.kind = kind
		business.staff_caption = "店主 · 露米" if kind == "store" else "铁匠 · 余烬"
		business.loop = PanelContext.new()
		# Use the production panel builder without loading world/HUD resources.
		business._make_panel()
		var layer: CanvasLayer = business.get_child(0)
		layer.reparent(viewport)
		business.service_panel.show()
		for button in business.buttons: button.disabled = true
		for locale in ["zh_CN", "en", "ja", "zh_TW"]:
			root.get_node("Localization").set_language(locale, false)
			var stock_copy := "蘑菇%d  莓果%d  香草%d\n背包 %d/%d · %d金" if kind == "store" else "木%d  矿%d  铁%d  鱼%d\n背包 %d/%d · %d金"
			business.stock.text = tr(stock_copy) % ([0, 0, 0, 2, 12, 0] if kind == "store" else [0, 0, 0, 0, 2, 12, 0])
			await frames()
			var clean := true
			var fits := true
			for control in business.service_panel.get_children():
				if control is Label:
					clean = clean and control.get_theme_font_size("font_size") == 12 and control.get_theme_color("font_shadow_color").a == 0.0 and control.get_theme_constant("shadow_outline_size") == 0
				if control is Label or control is Button:
					fits = fits and control.position.x + control.size.x <= business.service_panel.size.x + 1 and control.position.y + control.size.y <= business.service_panel.size.y + 1
			check(kind + " clean native pixel labels " + locale, clean)
			check(kind + " translated controls fit " + locale, fits)
			for scale_factor in [2, 3]:
				root.size = Vector2i(640, 360) * scale_factor
				container.scale = Vector2.ONE * scale_factor
				await frames()
				RenderingServer.force_draw(false)
				var rect := Rect2i(business.service_panel.position, business.service_panel.size)
				var pixels := viewport.get_texture().get_image().get_region(rect)
				pixels.resize(rect.size.x * scale_factor, rect.size.y * scale_factor, Image.INTERPOLATE_NEAREST)
				check(kind + " capture " + locale + " " + str(scale_factor), pixels.save_png(OUT + kind + "_" + locale + "_" + str(scale_factor) + "x.png") == OK)
		layer.queue_free()
		business.free()
		await frames()
	print("FONT CLARITY END failures=", failures)
	quit(0 if failures == 0 else 1)
