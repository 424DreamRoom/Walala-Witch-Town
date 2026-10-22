extends "res://output/layer_audit_20261022/audit.gd"

const Furniture = preload("res://Scenes/Building/furniture_catalog.gd")
var anchor_records: Array = []

func alpha_anchor(context: String, target: Node2D, sprite: Sprite2D) -> void:
	if sprite == null or sprite.texture == null: return
	var rect := sprite.get_rect()
	var picture := sprite.texture.get_image()
	var origin := Vector2i(sprite.frame % sprite.hframes, sprite.frame / sprite.hframes) * Vector2i(rect.size)
	if sprite.region_enabled: origin += Vector2i(sprite.region_rect.position)
	var bottom := -INF
	for y in range(int(rect.size.y)):
		for x in range(int(rect.size.x)):
			var source := origin + Vector2i(x,y)
			if source.x < 0 or source.y < 0 or source.x >= picture.get_width() or source.y >= picture.get_height(): continue
			if picture.get_pixelv(source).a > 0.95:
				bottom = maxf(bottom, sprite.to_global(rect.position + Vector2(x+0.5,y+0.5)).y - target.global_position.y)
	anchor_records.append({"scene":context,"node":str(target.name),"sort_position":str(target.global_position),"opaque_bottom_from_sort":bottom,"sprite":str(sprite.texture.resource_path)})

func run() -> void:
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(6)
	loop = lane.get_node("GameLoop")
	lane.automation = true
	lane.set_physics_process(false)
	loop.paused_for_test = true
	loop.set_process(false)
	loop.campaign_controller.set_process(false)
	loop.state.restaurant_leased = true
	loop.state.campaign.chapter = 99
	loop.state.campaign.legacy_chapter = 99
	lane.weather.clear_weather()
	loop.ui.hide()
	loop.hud.layer.hide()
	for child in lane.player.get_children():
		if child is CanvasItem: child.hide()
	probe = Polygon2D.new()
	probe.polygon = PackedVector2Array([Vector2(-32,-48),Vector2(32,-48),Vector2(32,-2),Vector2(-32,-2)])
	probe.color = Color.MAGENTA
	probe.hide()
	lane.player.add_child(probe)
	for context in ["town","field","dock","restaurant","blacksmith","store","furniture_store","farm","home"]:
		await enter(context)
		var container: Node2D = lane.actors if context == "town" else loop.area
		for child in container.get_children():
			if child is Node2D and child != lane.player:
				alpha_anchor(context, child, sprite_of(child))
		if context in ["blacksmith","store","furniture_store"]:
			await pixel_case(context+" nested staff", loop.area.staff, loop.area)
			alpha_anchor(context+" staff",loop.area.staff,loop.area.staff.sprite)
		if context == "restaurant":
			loop.state.campaign.restaurant = 4
			loop.state.customers = [{"seat":0,"dish":0,"patience":25.0,"variant":0,"status":"waiting","eating_left":0.0}]
			loop.area.arrival_clock[0] = 0.0
			loop.area._process(0)
			await pixel_case("restaurant seated guest",loop.area.customer_sprites[0],loop.area)
			loop.state.customers.clear()
		if context in ["blacksmith","store","furniture_store","dock","home"]:
			lane.avatar.show()
			await shot(context+"_overview",loop.area.spawn)
			lane.avatar.hide()
	for kind in Furniture.IDS:
		var context: String = "farm" if Furniture.RECIPES[kind].area == "farm" else "home"
		if loop.location != context: await enter(context)
		loop.state.furniture.placed = [{"id":1,"kind":kind,"x":320,"y":350,"area":context,"items":{},"slots":[]}]
		loop.area.refresh_furniture()
		for body in loop.area.furniture_bodies:
			for child in body.get_children():
				if child is PointLight2D:
					child.enabled = false
					child.set_process(false)
		var body: Node2D = loop.area.furniture_bodies[0]
		check("built "+kind+" depth matches floor/actor",body.z_index == (0 if Furniture.RECIPES[kind].solid else -1))
		alpha_anchor("built "+context,body,sprite_of(body))
		if Furniture.RECIPES[kind].solid: await pixel_case("built "+kind,body,loop.area)
	var file := FileAccess.open(OUT+"anchors.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(anchor_records,"\t"))
	file.close()
	print("SUPPLEMENT COMPLETE checks=",checks," failures=",failures," anchors=",anchor_records.size())
	Saves.end_session()
	lane.queue_free()
	await frames(4)
	quit(1 if failures else 0)
