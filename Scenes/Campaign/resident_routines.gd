extends RefCounted
## Scheduled destinations plus short, purposeful walks at each destination.
## The clock, weather and dialogue pause belong to the existing game loop.
const Actor = preload("res://Scenes/Campaign/resident_actor.gd")
const ActorCollision = preload("res://Scenes/Gameplay/actor_collision.gd")
const CELL := 8.0
const STOPS := {
	"west": [Vector2(310,370), Vector2(370,374), Vector2(412,396)],
	"garden": [Vector2(260,372), Vector2(284,388), Vector2(240,392)],
	"shop": [Vector2(580,388), Vector2(644,400), Vector2(688,384)],
	"square": [Vector2(532,456), Vector2(580,438), Vector2(612,488)],
	"fountain": [Vector2(648,504), Vector2(720,504), Vector2(728,448)],
	"east": [Vector2(760,508), Vector2(792,536), Vector2(840,572)],
	"smith": [Vector2(976,576), Vector2(1020,600), Vector2(1064,576)],
	"river": [Vector2(1128,628), Vector2(1176,652), Vector2(1128,676)],
	"hall": [Vector2(904,292), Vector2(976,292), Vector2(1008,312)],
	"north": [Vector2(408,272), Vector2(416,320), Vector2(448,372)],
	"restaurant": [Vector2(492,728), Vector2(532,760), Vector2(604,736)],
	"south": [Vector2(580,796), Vector2(680,872), Vector2(756,856)]
}
# morning, work, lunch, afternoon, evening; the same local places stay legible.
const PROFILES := {
	"mori": ["west", "garden", "square", "garden", "restaurant"],
	"ember": ["east", "smith", "restaurant", "smith", "fountain"],
	"nagi": ["fountain", "river", "square", "river", "restaurant"],
	"lumi": ["shop", "shop", "restaurant", "hall", "south"],
	"aster": ["north", "hall", "fountain", "hall", "north"],
	"toma": ["square", "restaurant", "shop", "restaurant", "south"],
	"pip": ["east", "smith", "fountain", "north", "restaurant"],
	"reed": ["west", "garden", "fountain", "river", "south"],
	"yuki": ["shop", "north", "restaurant", "shop", "south"],
	"orla": ["square", "hall", "restaurant", "square", "restaurant"]
}
var loop
var actors: Array = []
var visitors: Array[Node2D] = []
var grid := AStarGrid2D.new()
var places: Dictionary = {}
var shelters: Array[Vector2] = []
var shelter_plans: Array = []
var obstacles: Array[Rect2] = []

func configure(game_loop, npcs: Array) -> void:
	loop = game_loop
	_build_grid()
	for key in STOPS:
		var points: Array[Vector2] = []
		for point in STOPS[key]: points.append(safe_point(point))
		places[key] = points
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(loop.lane.ART + "town_layout.json"))
	for building in layout.buildings:
		for side in [-1.0, 1.0]:
			shelters.append(safe_point(Vector2(building.x + side * 48.0, building.y + 12.0)))
	# Reserve distinct awning positions, including when several residents eat together.
	for period in range(5):
		var available := shelters.duplicate()
		var allocation: Dictionary = {}
		for npc in npcs:
			var anchor: Vector2 = places[PROFILES[npc.id][period]][0]
			var best := 0
			for j in range(available.size()):
				if available[j].distance_squared_to(anchor) < available[best].distance_squared_to(anchor): best = j
			allocation[npc.id] = available[best]
			available.remove_at(best)
		shelter_plans.append(allocation)
	for i in range(npcs.size()):
		var actor := Actor.new()
		actor.configure(npcs[i].id, i)
		loop.lane.actors.add_child(actor)
		actors.append(actor)
		var plan := schedule(actor)
		var points: Array = plan.points
		actor.stop_index = (i + loop.state.day) % points.size()
		actor.position = points[actor.stop_index]
		actor.routine_key = plan.key
		actor.activity = plan.activity
		actor.place = plan.place
		actor.visible = loop.state.phase == "day"
		ActorCollision.set_active(actor, actor.visible)
		# Enter an activity already in progress; no row of motionless residents.
		_next_stop(actor, points)
		actor.pause_left = 0.0 if i % 3 != 0 else 0.5 + float(i % 4) * 0.4

func _build_grid() -> void:
	grid.region = Rect2i(0, 0, 161, 121)
	grid.cell_size = Vector2.ONE * CELL
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	obstacles.assign(loop.town_solids)
	# Door and exit approaches remain free for the player.
	for gate in loop.GATES:
		obstacles.append(Rect2(gate - Vector2(16, 18), Vector2(32, 36)))
	for rect in obstacles:
		var left := maxi(0, floori((rect.position.x - 6.0) / CELL))
		var right := mini(160, ceili((rect.end.x + 6.0) / CELL))
		var top := maxi(0, floori((rect.position.y - 1.0) / CELL))
		var bottom := mini(120, ceili((rect.end.y + 7.0) / CELL))
		for y in range(top, bottom + 1):
			for x in range(left, right + 1): grid.set_point_solid(Vector2i(x, y))
	# Prefer authored paths and the square; grass is available around obstacles.
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(loop.lane.ART + "town_layout.json"))
	var roads: Array = []
	for road in layout.get("paths", []):
		for i in range(1, road.points.size()):
			roads.append([Vector2(road.points[i-1][0], road.points[i-1][1]), Vector2(road.points[i][0], road.points[i][1]), float(road.width) * 0.45])
	var plazas: Array[PackedVector2Array] = []
	for plaza in layout.get("plazas", []):
		var polygon := PackedVector2Array()
		for point in plaza.points: polygon.append(Vector2(point[0], point[1]))
		plazas.append(polygon)
	for y in range(1, 120):
		for x in range(1, 160):
			var cell := Vector2i(x, y)
			if grid.is_point_solid(cell): continue
			var point := Vector2(cell) * CELL
			var on_road := false
			for polygon in plazas:
				if Geometry2D.is_point_in_polygon(point, polygon): on_road = true; break
			if not on_road:
				for road in roads:
					if point.distance_to(Geometry2D.get_closest_point_to_segment(point, road[0], road[1])) <= road[2]: on_road = true; break
			grid.set_point_weight_scale(cell, 1.0 if on_road else 3.5)

func safe_point(point: Vector2) -> Vector2:
	var center := Vector2i((point / CELL).round())
	for radius in range(20):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var cell := Vector2i(x, y)
				if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell): return Vector2(cell) * CELL
	return loop.lane.SPAWN

func route(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var first := Vector2i((safe_point(start) / CELL).round())
	var last := Vector2i((safe_point(finish) / CELL).round())
	var raw := grid.get_point_path(first, last)
	var turns := PackedVector2Array()
	# Keep the initial cell: a turn must not cut across a solid corner.
	for i in range(raw.size()):
		if i == 0 or i == raw.size()-1 or (raw[i]-raw[i-1]).normalized() != (raw[i+1]-raw[i]).normalized(): turns.append(raw[i])
	return turns

func schedule(actor) -> Dictionary:
	var offset: float = float(actor.index % 5) * 4.0
	var minutes: float = loop.state.get_time_minutes() - offset
	var period := 0 if minutes < 480.0 else 1 if minutes < 690.0 else 2 if minutes < 810.0 else 3 if minutes < 975.0 else 4
	var place: String = PROFILES[actor.resident_id][period]
	var activity: String = ["morning", "work", "lunch", "work", "evening"][period]
	var points: Array = places[place]
	if loop.lane.weather.get_weather() != "clear":
		# Choose a stable shelter near this period's destination, not a moving target.
		points = [shelter_plans[period][actor.resident_id]]
		activity = "shelter"
	return {"key": "%d:%d:%s" % [loop.state.day, period, activity], "activity": activity, "place": place, "points": points}

func _travel(actor, target: Vector2) -> void:
	# Local stops are reserved so a conversation group does not stack on one pixel.
	if actor.activity != "shelter":
		for offset in [Vector2.ZERO, Vector2(24,0), Vector2(-24,0), Vector2(0,24), Vector2(0,-24)]:
			var candidate := safe_point(target + offset)
			var occupied := false
			for other in actors:
				if other != actor and (other.destination.distance_to(candidate) < 20.0 or other.position.distance_to(candidate) < 20.0): occupied = true; break
			if not occupied:
				target = candidate
				break
	actor.destination = target
	actor.path = route(actor.position, target)
	actor.path_index = 0
	actor.blocked_left = 0.0
	# Missing routes retry after a bounded pause, without teleporting to spawn.
	if actor.path.is_empty(): actor.pause_left = 2.0

func _next_stop(actor, points: Array) -> void:
	actor.stop_index = (actor.stop_index + 1) % points.size()
	_travel(actor, points[actor.stop_index])

func advance(delta: float) -> void:
	if loop.get_tree().paused: return
	for actor in actors:
		actor.visible = loop.state.phase == "day"
		ActorCollision.set_active(actor, actor.visible)
	for actor in actors:
		if not actor.visible: continue
		var plan := schedule(actor)
		if actor.routine_key != plan.key:
			actor.routine_key = plan.key
			actor.activity = plan.activity
			actor.place = plan.place
			actor.stop_index = actor.index % plan.points.size()
			actor.pause_left = 0.0
			_travel(actor, plan.points[actor.stop_index])
		_step(actor, plan.points, delta)

func _step(actor, points: Array, delta: float) -> void:
	if actor.pause_left > 0.0:
		actor.pause_left = maxf(0.0, actor.pause_left - delta)
		if actor.activity in ["morning", "lunch", "evening"]:
			for other in actors:
				if other != actor and not other.moving and actor.position.distance_to(other.position) < 64.0:
					actor.face(other.position - actor.position)
					break
		elif actor.activity == "work":
			var focus: Vector2 = {"garden": Vector2(281,339), "smith": Vector2(1020,530), "river": Vector2(1232,652), "hall": Vector2(948,260), "shop": Vector2(620,350), "north": Vector2(454,24), "restaurant": Vector2(570,692), "square": Vector2(682,482)}[actor.place]
			actor.face(focus - actor.position)
		actor.pose(delta, false)
		return
	if actor.path_index >= actor.path.size():
		_next_stop(actor, points)
		actor.pose(delta, false)
		return
	var budget: float = actor.speed * delta
	var before: Vector2 = actor.position
	while budget > 0.0 and actor.path_index < actor.path.size():
		var point: Vector2 = actor.path[actor.path_index]
		var direction: Vector2 = point - actor.position
		if direction.length() <= 0.01:
			actor.path_index += 1
			continue
		var distance: float = minf(budget, direction.length())
		var next: Vector2 = actor.position + direction.normalized() * distance
		if _yield_to_actors(actor, next, delta): break
		actor.face(direction)
		# Use the same sweep on and off screen; detached worlds have no physics
		# space. Cardinal A* segments keep this conservative rectangle exact.
		var swept := ActorCollision.footprint(actor.position).merge(ActorCollision.footprint(next))
		var wall := false
		for obstacle in obstacles:
			if obstacle.intersects(swept): wall = true; break
		if wall:
			actor.path_index = actor.path.size()
			actor.pause_left = 0.5
			break
		actor.position = next
		if actor.is_inside_tree(): actor.force_update_transform()
		budget -= distance
		if actor.position.distance_to(point) <= 0.01: actor.path_index += 1
	actor.pose(delta, actor.position.distance_squared_to(before) > 0.001)
	if actor.path_index >= actor.path.size():
		actor.pause_left = 4.0 + float((actor.index * 3 + actor.stop_index * 7 + loop.state.day) % 7)
		if actor.activity == "work": actor.pause_left += 3.0
		actor.facing = 0

func _actor_blockers(actor) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if loop.location == "town": positions.append(loop.lane.player.position)
	for other in actors:
		if other != actor and other.visible: positions.append(other.position)
	for visitor in visitors:
		if is_instance_valid(visitor) and visitor.visible: positions.append(visitor.position)
	return positions

func _yield_to_actors(actor, next: Vector2, delta: float) -> bool:
	var blockers := _actor_blockers(actor)
	var blocked := false
	for point in blockers:
		if ActorCollision.blocks_motion(actor.position, next, point):
			actor.face(point - actor.position)
			blocked = true
			break
	if not blocked:
		actor.blocked_left = 0.0
		return false
	actor.blocked_left += delta
	# A small stagger lets oncoming residents yield without choosing the same
	# detour simultaneously. Dialogue still pauses this through the game tree.
	if actor.blocked_left < 0.5 + float(actor.index % 3) * 0.15: return true
	var reserved: Array[Vector2i] = []
	for point in blockers:
		var center := Vector2i((point / CELL).round())
		for y in range(center.y - 2, center.y + 3):
			for x in range(center.x - 3, center.x + 4):
				var cell := Vector2i(x, y)
				var relative := (Vector2(cell) * CELL - point).abs()
				if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell) and relative.x < 18.0 and relative.y < 14.0:
					grid.set_point_solid(cell)
					reserved.append(cell)
	# safe_point chooses an unreserved starting cell beside the resident. Keeping
	# a single cell open inside the margin would isolate it from all neighbours.
	var detour := route(actor.position, actor.destination)
	for cell in reserved: grid.set_point_solid(cell, false)
	var clear_start := not detour.is_empty()
	if clear_start:
		for point in blockers:
			if ActorCollision.blocks_motion(actor.position, detour[0], point): clear_start = false; break
	if clear_start:
		actor.path = detour
		actor.path_index = 0
		actor.blocked_left = 0.0
		return true
	# An occupied destination retries another local stop after a short pause.
	actor.path_index = actor.path.size()
	actor.pause_left = 1.0
	return true

func nearest(point: Vector2, radius: float = 27.0):
	var found = null
	var distance := radius
	for actor in actors:
		if not actor.visible: continue
		var candidate: float = actor.position.distance_to(point)
		if candidate <= distance:
			found = actor
			distance = candidate
	return found
