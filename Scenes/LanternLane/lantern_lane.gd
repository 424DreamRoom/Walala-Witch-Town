extends Node2D
signal player_moved(distance: float, running: bool)
## Orthogonal top-down town, self-contained input and pixel viewport.
const ART := "res://Art/Environment/Hearthwood/"
const Ambient = preload("res://Scenes/Gameplay/ambient_animation.gd")
const ActorCollision = preload("res://Scenes/Gameplay/actor_collision.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const SPAWN := Vector2(408, 364)
var verify_path := "res://Scenes/LanternLane/Verification/topdown/"
const WitchAnimation = preload("res://Art/Character/Storybook/WalalaWitchAseprite32/witch_animation.gd")
const PlayerFX = preload("res://Scenes/Gameplay/player_fx.gd")
const WITCH_TEXTURE := WitchAnimation.SHEET
const CHARACTER_SIZE := Vector2(32, 32)
const WITCH_FOOT_OFFSET := Vector2(0, -CHARACTER_SIZE.y / 2)
# A few authored house sprites contain transparent scanlines between the eave
# and facade. Keep the source pixels untouched and close only those seams at
# runtime. Values are [roof_end, facade_start, roof_shift] in source rows.
const BUILDING_SEAMS := {
	"shop_7": [117, 120, 3],
	"shop_8": [109, 109, 4],
}
var world: Node2D
var world_size := Vector2i.ZERO
var actors: Node2D
var player: CharacterBody2D
var avatar: Sprite2D
var player_fx: Node2D
var harvest
var viewport: SubViewport
var camera: Camera2D
var weather: WeatherEffect
var clock := 0.0
var facing := 0
var automation := false
var test_direction := Vector2.ZERO
var test_running := false
var was_moving := false
var was_running := false
var solid_rects: Array[Rect2] = []
var failures := 0

func _ready() -> void:
	Localization.apply_saved_language()
	InputBindings.apply_saved_bindings()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	automation = "--lane-test" in OS.get_cmdline_user_args() or "--lane-capture" in OS.get_cmdline_user_args() or "--witch-capture" in OS.get_cmdline_user_args()
	if "--witch-capture" in OS.get_cmdline_user_args():
		verify_path = "res://Art/Character/Storybook/Verification/"
	var container := SubViewportContainer.new()
	add_child(container)
	Preferences.attach_brightness(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(viewport)
	get_viewport().size_changed.connect(_fit_canvas.bind(container))
	_fit_canvas(container)
	world = Node2D.new()
	viewport.add_child(world)
	var ground := preload("res://Art/Source/tile_ground.gd").create(ART + "town_ground.aseprite")
	world.add_child(ground)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	world.add_child(actors)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "town_layout.json"))
	world_size = Vector2i(layout.size[0], layout.size[1])
	for entry in layout.buildings + layout.props:
		_add_object(entry)
	for values in layout.get("barriers", []):
		var rect := Rect2(values[0], values[1], values[2], values[3])
		var bank := StaticBody2D.new()
		bank.position = rect.get_center()
		world.add_child(bank)
		_collision(bank, rect.size, Vector2.ZERO)
		solid_rects.append(rect)
	for rect in [Rect2(-16,-16,world_size.x + 32,16), Rect2(-16,world_size.y,world_size.x + 32,16), Rect2(-16,0,16,world_size.y), Rect2(world_size.x,0,16,world_size.y)]:
		var body := StaticBody2D.new()
		world.add_child(body)
		body.position = rect.get_center()
		_collision(body, rect.size, Vector2.ZERO)
		solid_rects.append(rect)
	player = CharacterBody2D.new()
	player.name = "WalalaWitch"
	player.position = SPAWN
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	actors.add_child(player)
	ActorCollision.attach(player)
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-10,-3),Vector2(-6,-7),Vector2(6,-7),Vector2(10,-3),Vector2(6,0),Vector2(-6,0)])
	shadow.color = Color(0.12,0.2,0.18,0.4)
	player.add_child(shadow)
	avatar = Sprite2D.new()
	WitchAnimation.configure(avatar)
	# Native 32x32 art shares the feet origin used by movement and Y sorting.
	avatar.position = WITCH_FOOT_OFFSET
	player.add_child(avatar)
	player_fx = PlayerFX.new()
	player_fx.name = "WitchMagicFX"
	player.add_child(player_fx)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = world_size.x
	camera.limit_bottom = world_size.y
	player.add_child(camera)
	weather = preload("res://Scenes/LanternLane/Effect/Weather/weather.tscn").instantiate()
	weather.name = "WeatherEffect"
	weather.z_index = 100
	viewport.add_child(weather)
	var weather_blockers: Array[Rect2] = []
	for building in layout.buildings:
		var texture: Texture2D = load(ART + building.kind + ".aseprite")
		var seam: Array = BUILDING_SEAMS.get(building.kind, [])
		var roof_shift := int(seam[2]) if seam.size() >= 3 else 0
		weather_blockers.append(Rect2(Vector2(building.x - texture.get_width() / 2.0, building.y - texture.get_height() + roof_shift), texture.get_size()))
	weather.configure(camera, player, weather_blockers)
	player_fx.configure(weather.get_weather())
	for object in actors.get_children():
		if object.has_meta("outdoor_kind"):
			for child in object.get_children():
				if child is Sprite2D:
					Ambient.attach(child, object.get_meta("outdoor_kind"), weather)
	# Additive gameplay entry; legacy capture/regression paths remain isolated.
	if not automation and not "--no-loop" in OS.get_cmdline_user_args():
		var gameplay := preload("res://Scenes/Gameplay/game_loop.gd").new()
		gameplay.name = "GameLoop"
		add_child(gameplay)
	if "--lane-test" in OS.get_cmdline_user_args():
		_run_tests.call_deferred()
	elif "--lane-capture" in OS.get_cmdline_user_args() or "--witch-capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _fit_canvas(container: SubViewportContainer) -> void:
	var available := get_viewport_rect().size
	var factor := maxf(1.0, floorf(minf(available.x / 640.0, available.y / 360.0)))
	container.scale = Vector2.ONE * factor
	container.position = ((available - Vector2(640,360) * factor) / 2.0).floor()

func _collision(body: Node2D, size: Vector2, offset: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = offset
	body.add_child(collision)

func _add_object(entry: Dictionary) -> void:
	var solid: bool = entry.get("solid", true)
	var body: Node2D = StaticBody2D.new() if solid else Node2D.new()
	body.position = Vector2(entry.x,entry.y)
	body.set_meta("outdoor_kind", entry.kind)
	actors.add_child(body)
	var texture: Texture2D = load(ART + entry.kind + ".aseprite")
	_add_building_sprite(body, entry.kind, texture)
	if solid:
		var size := Vector2(entry.w,entry.h)
		_collision(body,size,Vector2(0,-size.y/2))
		solid_rects.append(Rect2(body.position-Vector2(size.x/2,size.y),size))

func _add_building_sprite(body: Node2D, kind: String, texture: Texture2D) -> void:
	var width := float(texture.get_width())
	var height := float(texture.get_height())
	var seam: Array = BUILDING_SEAMS.get(kind, [])
	if seam.size() < 2:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		# Building sprite bottom and trunk/prop feet define painter's order.
		sprite.position = Vector2(0, -height / 2.0)
		if kind in ["planter", "menu"]:
			sprite.position.y += 6
		body.add_child(sprite)
		return
	var roof_end := int(seam[0])
	var facade_start := int(seam[1])
	var gap := int(seam[2]) if seam.size() >= 3 else facade_start - roof_end
	if roof_end <= 0 or facade_start < roof_end or facade_start > int(height) or gap < 0:
		var fallback := Sprite2D.new()
		fallback.texture = texture
		fallback.position = Vector2(0, -height / 2.0)
		if kind in ["planter", "menu"]:
			fallback.position.y += 6
		body.add_child(fallback)
		return
	# Draw two regions from the same source texture. The lower region keeps its
	# original baseline; the roof region moves down by only the transparent gap.
	var roof := Sprite2D.new()
	roof.texture = texture
	roof.region_enabled = true
	roof.region_rect = Rect2(0, 0, width, roof_end)
	roof.centered = false
	roof.position = Vector2(-width / 2.0, -height + gap)
	body.add_child(roof)
	var facade := Sprite2D.new()
	facade.texture = texture
	facade.region_enabled = true
	facade.region_rect = Rect2(0, facade_start, width, height - facade_start)
	facade.centered = false
	facade.position = Vector2(-width / 2.0, -height + facade_start)
	body.add_child(facade)

func _physics_process(delta: float) -> void:
	var raw := test_direction
	if not automation:
		raw = Input.get_vector("move_left", "move_right", "move_up", "move_down") if not InputBindings.capture_active else Vector2.ZERO
	var running := test_running if automation else Input.is_action_pressed("run") != bool(Preferences.value("game", "auto_run", false))
	if harvest != null and harvest.busy():
		if harvest.fishing() and raw != Vector2.ZERO:
			harvest.cancel()
		else:
			raw = Vector2.ZERO
	# Keep both axes and normalize so diagonal movement has the same speed.
	player.velocity = raw.limit_length() * (140.0 if running else 90.0)
	var previous_position := player.position
	player.move_and_slide()
	player_moved.emit(player.position.distance_to(previous_position), running)
	if player.velocity.length() > 1:
		if player.velocity.x != 0:
			facing = 2 if player.velocity.x > 0 else 3
		else:
			facing = 0 if player.velocity.y > 0 else 1
	_animate(player.velocity.length() > 1, running, delta)
	if player_fx != null:
		player_fx.set_motion(player.velocity.length() > 1, running, facing)
	avatar.position = WITCH_FOOT_OFFSET + player.position.round() - player.position
	if harvest != null and harvest.busy():
		harvest.update_pose()
	camera.position = player.position.round() - player.position

func _animate(moving: bool, running: bool, delta: float) -> void:
	if moving != was_moving or (moving and running != was_running):
		clock = 0.0
	else:
		clock += delta
	was_moving = moving
	was_running = running
	avatar.frame = WitchAnimation.frame_for(("run" if running else "walk") if moving else "idle", facing, clock)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if InputBindings.capture_active or InputBindings.is_bound_event(event): return
		if event.physical_keycode == KEY_R:
			player.position = SPAWN
		if event.physical_keycode == KEY_F6:
			weather.clear_weather()
		if event.physical_keycode == KEY_F7:
			weather.set_weather("rain")
		if event.physical_keycode == KEY_F8:
			weather.set_weather("snow")
		if event.physical_keycode == KEY_F3:
			var overlay := world.get_node_or_null("CollisionOverlay")
			if overlay:
				overlay.queue_free()
			else:
				overlay = Node2D.new()
				overlay.name = "CollisionOverlay"
				overlay.z_index = 50
				world.add_child(overlay)
				for rect in solid_rects:
					var polygon := Polygon2D.new()
					polygon.polygon = PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
					polygon.color = Color(0.3,0.95,0.75,0.35)
					overlay.add_child(polygon)

func _check(title: String, ok: bool) -> void:
	print("TOWN TEST ",title,": ","PASS" if ok else "FAIL")
	if not ok:
		failures += 1

func _walk(start: Vector2, direction: Vector2, frames: int) -> Vector2:
	test_direction = Vector2.ZERO
	player.position = start
	await get_tree().physics_frame
	test_direction = direction
	for i in range(frames):
		await get_tree().physics_frame
	test_direction = Vector2.ZERO
	return player.position

func _run_tests() -> void:
	await get_tree().physics_frame
	_check("witch texture native grid", avatar.texture.get_size() == Vector2(256,608) and avatar.hframes == WitchAnimation.COLUMNS and avatar.vframes == WitchAnimation.ROWS)
	_check("witch display size", avatar.get_rect().size * avatar.scale == CHARACTER_SIZE)
	_check("witch foot anchor", avatar.position + Vector2(avatar.get_rect().get_center().x, avatar.get_rect().end.y) * avatar.scale == Vector2.ZERO)
	for row in range(4):
		facing = row
		_animate(false, false, 0.0)
		_check("witch idle row " + str(row), avatar.frame == int(WitchAnimation.tag_for("idle", row).from))
		for step in range(8):
			was_moving = true
			was_running = false
			clock = float(step) * 0.1 + 0.001
			_animate(true, false, 0.0)
			_check("witch walk row/step " + str(row) + "/" + str(step), avatar.frame == int(WitchAnimation.tag_for("walk", row).from) + step)
		was_running = true
		clock = 0.066
		_animate(true, true, 0.0)
		_check("witch independent run " + str(row), avatar.frame == int(WitchAnimation.tag_for("run", row).from) + 1)
	facing = 0
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		var end: Vector2 = await _walk(SPAWN,direction,40)
		_check("cardinal " + str(direction), end.distance_to(SPAWN + direction*60) < 3)
		test_direction = Vector2.ZERO
		await get_tree().physics_frame
		var expected_row := 0 if direction == Vector2.DOWN else 1 if direction == Vector2.UP else 2 if direction == Vector2.RIGHT else 3
		_check("witch stop keeps facing " + str(direction), facing == expected_row and avatar.frame == int(WitchAnimation.tag_for("idle", expected_row).from))
	test_running = true
	var run_end: Vector2 = await _walk(SPAWN, Vector2.RIGHT, 30)
	_check("witch run speed", absf(run_end.x - SPAWN.x - 70.0) < 3)
	test_running = false
	var diagonal_end: Vector2 = await _walk(SPAWN, Vector2.ONE, 20)
	_check("diagonal movement keeps walking speed", diagonal_end.distance_to(SPAWN + Vector2.ONE.normalized() * 30.0) < 3)
	var p: Vector2 = await _walk(Vector2(620,402),Vector2.UP,60)
	_check("building front collision",p.y >= 355.9 and p.y < 358)
	p = await _walk(Vector2(620,222),Vector2.DOWN,60)
	_check("building rear collision",p.y > 252 and p.y <= 254.1)
	p = await _walk(Vector2(516,302),Vector2.RIGHT,60)
	_check("building left collision",p.x > 533 and p.x <= 535.1)
	p = await _walk(Vector2(736,302),Vector2.LEFT,60)
	_check("building right collision",p.x >= 704.9 and p.x < 707)
	p = await _walk(SPAWN,Vector2.DOWN,210)
	_check("multi-screen north-south route",p.y > 675)
	camera.force_update_scroll()
	_check("camera follows vertical route",camera.get_screen_center_position().distance_to(player.position.round()) < 2)
	player.position = SPAWN
	var crossed: bool = await preload("res://Scenes/LanternLane/verification_navigation.gd").walk(self, Vector2(904, 610))
	p = player.position
	_check("multi-screen east-west route", crossed and p.x > 895)
	camera.force_update_scroll()
	_check("camera follows horizontal route",camera.get_screen_center_position().distance_to(player.position.round()) < 2)
	player.position = Vector2(24,24)
	camera.force_update_scroll()
	_check("camera clamps map edge",camera.get_screen_center_position().distance_to(Vector2(320,180)) < 2)
	_check("common Y-sort parent",actors.y_sort_enabled and player.get_parent()==actors)
	_check("weather starts clear", weather.get_weather() == "clear")
	weather.set_weather("rain")
	_check("weather rain API", weather.get_weather() == "rain")
	weather.set_weather("snow")
	_check("weather snow API", weather.get_weather() == "snow")
	weather.clear_weather()
	_check("weather clear API", weather.get_weather() == "clear")
	get_tree().quit(0 if failures == 0 else 1)

func _shot(title: String, pos: Vector2) -> void:
	player.position = pos
	camera.force_update_scroll()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png(verify_path + title + ".png")
	_check("capture " + title,result == OK)

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(verify_path))
	await _shot("runtime",SPAWN)
	await _shot("south_market",Vector2(808,684))
	await _shot("behind_roof",Vector2(624,185))
	await _shot("front_shop",Vector2(624,298))
	await _shot("behind_tree",Vector2(330,451))
	await _shot("front_tree",Vector2(330,485))
	await _shot("clear",SPAWN)
	weather.set_weather("rain")
	await _shot("rain",SPAWN)
	weather.set_weather("snow")
	await _shot("snow",Vector2(808,684))
	weather.clear_weather()
	await _shot("clear_after_weather",Vector2(408,364))
	if "--witch-capture" in OS.get_cmdline_user_args():
		for row in range(4):
			facing = row
			_animate(false, false, 0.0)
			await _shot("idle_" + ["down","up","right","left"][row], SPAWN)
			for step in range(8):
				# Freeze only the screenshot's animation; movement tests use physics above.
				set_physics_process(false)
				avatar.frame = int(WitchAnimation.tag_for("walk", row).from) + step
				await _shot("walk_" + ["down","up","right","left"][row] + "_" + str(step + 1), SPAWN)
				set_physics_process(true)
	get_tree().quit(0 if failures == 0 else 1)
