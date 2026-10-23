extends RefCounted
## Frame indoor artwork without changing its world coordinates or source files.
const LOCATIONS := ["home", "restaurant", "blacksmith", "store", "furniture_store"]
const Ground = preload("res://Art/Source/tile_ground.gd")
const Depth = preload("res://Scenes/Gameplay/world_depth.gd")
static var measurements := {}

static func prepare(room: Node2D, source_path: String, scene_override: String = "") -> Rect2i:
	var key := source_path + "|" + scene_override
	if not measurements.has(key):
		var image := Ground.preview(source_path, scene_override).get_image()
		var background := image.get_pixel(0, 0)
		# Empty canvas tiles can have different atlas IDs. Measure visible pixels
		# rather than counting occupied tile cells as part of the room.
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y).is_equal_approx(background):
					image.set_pixel(x, y, Color.TRANSPARENT)
		measurements[key] = {"bounds": image.get_used_rect(), "background": background}
	var data: Dictionary = measurements[key]
	var backdrop := Polygon2D.new()
	backdrop.name = "RoomBackdrop"
	backdrop.z_index = Depth.GROUND - 1
	backdrop.color = data.background
	# Cover the space exposed by centering and by the largest house's zoom.
	backdrop.polygon = PackedVector2Array([Vector2(-1280, -720), Vector2(1920, -720), Vector2(1920, 1200), Vector2(-1280, 1200)])
	room.add_child(backdrop)
	return data.bounds

static func play_rect(viewport_size: Vector2i, usable_width: int = 0) -> Rect2:
	var width := usable_width if usable_width > 0 else viewport_size.x
	# Leave room for the clock and bottom hotbar as well as the right sidebar.
	return Rect2(16, 64, width - 32, viewport_size.y - 96)

static func zoom_for(bounds: Rect2i, viewport_size: Vector2i, usable_width: int = 0) -> float:
	var available := play_rect(viewport_size, usable_width).size
	return minf(1.0, minf(available.x / bounds.size.x, available.y / bounds.size.y))

static func view_for(bounds: Rect2i, viewport_size: Vector2i, usable_width: int = 0) -> Rect2i:
	var zoom := zoom_for(bounds, viewport_size, usable_width)
	var center := Vector2(bounds.position) + Vector2(bounds.size) / 2.0
	return Rect2i(Vector2i((center - play_rect(viewport_size, usable_width).get_center() / zoom).round()), Vector2i((Vector2(viewport_size) / zoom).ceil()))

static func frame(camera: Camera2D, bounds: Rect2i, viewport_size: Vector2i, usable_width: int = 0) -> void:
	var zoom := Vector2.ONE * zoom_for(bounds, viewport_size, usable_width)
	var view := view_for(bounds, viewport_size, usable_width)
	if camera.zoom.is_equal_approx(zoom) and camera.limit_left == view.position.x and camera.limit_top == view.position.y and camera.limit_right == view.end.x and camera.limit_bottom == view.end.y:
		return
	camera.zoom = zoom
	camera.limit_left = view.position.x
	camera.limit_top = view.position.y
	camera.limit_right = view.end.x
	camera.limit_bottom = view.end.y
	camera.force_update_scroll()
