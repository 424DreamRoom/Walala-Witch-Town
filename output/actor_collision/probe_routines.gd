extends SceneTree
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const Routines = preload("res://Scenes/Campaign/resident_routines.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
class Weather extends RefCounted:
	var value := "clear"
	func get_weather() -> String: return value
class Lane extends Node2D:
	const ART := "res://Art/Environment/Hearthwood/"
	const SPAWN := Vector2(408, 364)
	var actors := Node2D.new()
	var player := CharacterBody2D.new()
	var weather := Weather.new()
class Loop extends Node:
	var lane := Lane.new()
	var state := State.new()
	var location := "town"
	var town_solids: Array[Rect2] = []
	var GATES: Array = []
func _initialize() -> void:
	Preferences.file_path = "res://output/actor_collision/probe_preferences.cfg"
	Saves.directory = "res://output/actor_collision/probe_saves"
	Saves.end_session()
	run.call_deferred()
func run() -> void:
	var loop := Loop.new()
	root.add_child(loop)
	loop.add_child(loop.lane)
	loop.lane.add_child(loop.lane.actors)
	loop.lane.add_child(loop.lane.player)
	loop.lane.player.position = loop.lane.SPAWN
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(loop.lane.ART + "town_layout.json"))
	for item in layout.buildings + layout.props:
		if item.get("solid", true): loop.town_solids.append(Rect2(item.x-item.w/2.0, item.y-item.h, item.w, item.h))
	for rect in layout.barriers: loop.town_solids.append(Rect2(rect[0], rect[1], rect[2], rect[3]))
	for rect in [Rect2(-16,-16,1312,16), Rect2(-16,960,1312,16), Rect2(-16,0,16,960), Rect2(1280,0,16,960)]: loop.town_solids.append(rect)
	for value in layout.gates.values(): loop.GATES.append(Vector2(value[0], value[1]))
	var routines := Routines.new()
	routines.configure(loop, loop.state.Content.DATA.npcs)
	var hits := 0
	var overlaps := 0
	var walked := {}
	for actor in routines.actors: walked[actor.resident_id] = 0.0
	for frame in range(8100):
		var before := {}
		for actor in routines.actors: before[actor] = actor.position
		loop.state.tick(1.0 / 12.0)
		routines.advance(1.0 / 12.0)
		for i in range(routines.actors.size()):
			var actor = routines.actors[i]
			walked[actor.resident_id] += actor.position.distance_to(before[actor])
			var feet := Rect2(actor.position-Vector2(5,6), Vector2(10,6))
			for obstacle in routines.obstacles:
				if obstacle.intersects(feet): hits += 1
			for j in range(i):
				var gap: Vector2 = (actor.position - routines.actors[j].position) / Vector2(10,6)
				if actor.visible and gap.length_squared() < 0.99:
					overlaps += 1
					if overlaps < 5: print("OVERLAP ", actor.resident_id, " ", routines.actors[j].resident_id, " ", actor.position)
	print("PROBE FULL DAY hits=", hits, " overlaps=", overlaps, " walked=", walked)
	loop.state.phase = "day"
	loop.state.remaining = State.DAY_SECONDS * 360.0 / 720.0
	loop.lane.weather.value = "rain"
	for frame in range(1800): routines.advance(1.0/12.0)
	var arrived := true
	for actor in routines.actors:
		if actor.position.distance_to(actor.destination) > 1.0:
			arrived = false
			print("SHELTER BLOCKED ", actor.resident_id, " ", actor.position, " target ", actor.destination, " route ", actor.path_index, "/", actor.path.size())
	print("PROBE SHELTER arrived=", arrived)
	quit(0 if hits == 0 and overlaps == 0 and arrived else 1)
