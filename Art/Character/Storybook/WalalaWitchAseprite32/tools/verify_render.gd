extends SceneTree
const WitchAnimation = preload("res://Art/Character/Storybook/WalalaWitchAseprite32/witch_animation.gd")
const OUT := "res://output/witch-aseprite32/"
var lane
var failures := 0
var checks := 0

func _initialize() -> void:
	preload("res://Scenes/MainMenu/menu_preferences.gd").file_path = OUT + "profile/render/preferences.cfg"
	preload("res://Scenes/Save/save_store.gd").directory = OUT + "profile/render/saves"
	preload("res://Scenes/Save/save_store.gd").end_session()
	run.call_deferred()

func frames(count := 2) -> void:
	for i in range(count): await process_frame

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("ASEPRITE 32 TEST ", label, ": ", "PASS" if ok else "FAIL")

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(5)
	lane.set_process(false)
	lane.set_physics_process(false)
	lane.player.position = Vector2(620, 500)
	lane.avatar.position = lane.WITCH_FOOT_OFFSET
	lane.weather.clear_weather()
	await frames(4)
	check("native 32x32", lane.avatar.get_rect().size == Vector2(32,32))
	check("feet pivot 16,32", lane.avatar.position == Vector2(0,-16))
	for index in range(152):
		lane.avatar.frame = index
		await frames()
		RenderingServer.force_draw(false)
		var image: Image = lane.viewport.get_texture().get_image()
		var source: Image = lane.avatar.texture.get_image().get_region(Rect2i(index % 8 * 32, index / 8 * 32, 32,32))
		var corner := Vector2i((lane.avatar.get_global_transform_with_canvas() * Vector2(-16,-16)).round())
		var matching := 0
		var opaque := 0
		for y in range(32):
			for x in range(32):
				var color := source.get_pixel(x,y)
				if color.a == 1.0:
					opaque += 1
					if image.get_pixel(corner.x+x,corner.y+y) == color: matching += 1
		check("frame " + str(index) + " exact " + str(matching) + "/" + str(opaque), opaque > 0 and matching == opaque)
		if index % 38 in [0,4,14,24]:
			image.save_png(OUT + "frame-" + str(index) + ".png")
			image.get_region(Rect2i(corner - Vector2i(8,8), Vector2i(48,48))).save_png(OUT + "frame-" + str(index) + "-crop.png")
	for direction in range(4):
		for action in ["idle", "walk", "run", "cast"]:
			var tag := WitchAnimation.tag_for(action, direction)
			check(action + " starts " + str(direction), WitchAnimation.frame_for(action,direction,0.0) == int(tag.from))
			if action == "cast":
				check("cast ends without wrapping " + str(direction), WitchAnimation.frame_for(action,direction,10.0,0.8) == int(tag.to))
			else:
				var duration := 0.0
				for ms in tag.durations_ms: duration += float(ms)/1000.0
				check(action + " loops " + str(direction), WitchAnimation.frame_for(action,direction,duration+0.001) == int(tag.from))
	lane.was_moving = false
	lane._animate(true,false,0.0)
	lane.clock = 0.31
	lane._animate(true,true,0.0)
	check("run transition resets phase", lane.clock == 0.0 and lane.avatar.frame == int(WitchAnimation.tag_for("run",lane.facing).from))
	var menu = preload("res://Scenes/MainMenu/menu_backdrop.gd").new()
	root.add_child(menu)
	await frames()
	menu.set_process(false)
	check("menu shares character", menu.witch.texture.resource_path == lane.WITCH_TEXTURE and menu.witch.get_rect().size == Vector2(32,32))
	for phase in [0.0,5.0,8.0,11.0]:
		menu.elapsed = phase
		menu._update_witch()
		var action := "walk" if phase in [5.0,11.0] else "idle"
		var direction := 2 if phase==5.0 else 3 if phase==11.0 else 0
		check("menu phase " + str(phase), menu.witch.frame == WitchAnimation.frame_for(action,direction,0.0))
	var report := {"status":"PASS" if failures==0 else "FAIL","rendered_frames":152,"checks":checks,"failures":failures,"exact_source_pixels":failures==0,"isolated_profile":true}
	var file := FileAccess.open("res://Art/Character/Storybook/WalalaWitchAseprite32/runtime-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	menu.queue_free()
	lane.queue_free()
	await frames(5)
	print("ASEPRITE 32 RENDER END checks=", checks, " failures=",failures)
	quit(0 if failures==0 else 1)
