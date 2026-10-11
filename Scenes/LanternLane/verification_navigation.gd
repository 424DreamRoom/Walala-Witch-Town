extends RefCounted
## Verification helper: find routes, then exercise the real player physics.
static func route(lane, target: Vector2) -> PackedVector2Array:
	var grid := AStarGrid2D.new()
	var dimensions: Vector2i = lane.world_size
	var loop = lane.get_node_or_null("GameLoop")
	if loop != null and loop.location != "town":
		dimensions = Vector2i(lane.camera.limit_right, lane.camera.limit_bottom)
	var last_cell := Vector2i(ceili(dimensions.x / 4.0), ceili(dimensions.y / 4.0))
	grid.region = Rect2i(Vector2i.ZERO, last_cell + Vector2i.ONE)
	grid.cell_size = Vector2(4, 4)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var obstacles: Array = lane.solid_rects.duplicate()
	if loop != null:
		for exit in loop._scene_exits():
			if exit.has("door"): continue
			if not exit.rect.has_point(target) and not exit.rect.grow(4.0).has_point(lane.player.position):
				obstacles.append(exit.rect)
	for rect in obstacles:
		var left := maxi(0, ceili((rect.position.x - 6) / 4.0))
		var right := mini(last_cell.x, floori((rect.end.x + 6) / 4.0))
		var top := maxi(0, ceili((rect.position.y - 1) / 4.0))
		var bottom := mini(last_cell.y, floori((rect.end.y + 7) / 4.0))
		for y in range(top, bottom + 1):
			for x in range(left, right + 1):
				grid.set_point_solid(Vector2i(x, y))
	var start := Vector2i((lane.player.position / 4.0).round())
	var finish := Vector2i((target / 4.0).round())
	# The conservative grid margin can include safe positions beside an edge.
	# Keep real feet collision authoritative for the route endpoints.
	for pair in [[start, lane.player.position], [finish, target]]:
		if grid.is_point_solid(pair[0]):
			var feet := Rect2(pair[1] - Vector2(5, 6), Vector2(10, 6))
			for rect in obstacles:
				if rect.intersects(feet):
					return PackedVector2Array()
			grid.set_point_solid(pair[0], false)
	var raw := grid.get_point_path(start, finish)
	if raw.is_empty():
		print("NAVIGATION no safe route from ", lane.player.position, " to ", target)
		return raw
	var turns := PackedVector2Array()
	for i in range(1, raw.size()):
		if i == raw.size() - 1 or (raw[i] - raw[i - 1]).normalized() != (raw[i + 1] - raw[i]).normalized():
			turns.append(raw[i])
	turns.append(target)
	return turns

static func walk(lane, target: Vector2) -> bool:
	var loop = lane.get_node_or_null("GameLoop")
	var source: String = loop.location if loop != null else ""
	var expected := ""
	if loop != null:
		for exit in loop._scene_exits():
			if exit.has("door"): continue
			if exit.rect.has_point(target):
				expected = exit.target
				target = exit.rect.get_center()
				var approach: Vector2 = exit.rect.get_center() - exit.direction * 36.0
				if lane.player.position.distance_to(approach) > 3.0:
					if not await walk(lane, approach):
						return false
				break
	var points := route(lane, target)
	if points.is_empty():
		return false
	for point in points:
		var count := 0
		while lane.player.position.distance_to(point) > 1.9 and count < 600:
			var diff: Vector2 = point - lane.player.position
			# Running advances 2.33px per frame; the axis tolerance must exceed
			# half a running step to avoid oscillating either side of a turn.
			lane.test_direction = Vector2(signf(diff.x), 0) if absf(diff.x) > 1.5 else Vector2(0, signf(diff.y))
			await lane.get_tree().physics_frame
			if loop != null and loop.location != source:
				lane.test_direction = Vector2.ZERO
				if lane.get_tree().root.get_node("SceneTransition").active:
					await lane.get_tree().root.get_node("SceneTransition").finished
				return loop.location == expected
			count += 1
		lane.test_direction = Vector2.ZERO
		if lane.player.position.distance_to(point) > 3.0:
			print("NAVIGATION BLOCKED at ", lane.player.position, " toward ", point)
			return false
	await lane.get_tree().physics_frame
	if not expected.is_empty():
		if lane.get_tree().root.get_node("SceneTransition").active:
			await lane.get_tree().root.get_node("SceneTransition").finished
		# Exit changes are deferred until physics is finished, so allow the
		# queued change to complete before reporting arrival to the caller.
		for i in range(3):
			await lane.get_tree().process_frame
			if loop.location != source:
				return loop.location == expected
	if loop != null and loop.location != source:
		return loop.location == expected
	return lane.player.position.distance_to(target) < 3.0
