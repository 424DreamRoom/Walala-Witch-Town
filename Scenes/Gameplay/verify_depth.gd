extends SceneTree
## Actual hierarchy audit plus GPU pixel probes on either side of each ground contact.
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
const Depth = preload("res://Scenes/Gameplay/world_depth.gd")
const OUT := "res://Scenes/Gameplay/Verification/Depth/"
var lane
var loop
var probe: Polygon2D
var capture := false
var checks := 0
var failures := 0
var tested_kinds := {}

func _initialize() -> void:
	Preferences.file_path = "res://output/depth_preferences_test.cfg"
	Saves.directory = "res://output/depth_test_saves"
	Saves.end_session()
	capture = "--capture" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(title: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("DEPTH ",checks," ",title,": ","PASS" if ok else "FAIL")

func frames(count: int = 2) -> void:
	for i in range(count): await process_frame

func pixels() -> Image:
	lane.camera.force_update_scroll()
	await frames()
	await RenderingServer.frame_post_draw
	return lane.viewport.get_texture().get_image()

func world_pixel(image: Image, point: Vector2) -> Color:
	var screen: Vector2 = lane.player.get_global_transform_with_canvas()*(point-lane.player.global_position)
	return image.get_pixelv(Vector2i(screen.floor()).clamp(Vector2i.ZERO,image.get_size()-Vector2i.ONE))

func sprite_of(node: Node) -> Sprite2D:
	if node is Sprite2D: return node
	for child in node.get_children():
		if child is Sprite2D: return child
	return null

func pick_pixel(root_node: Node2D, sprite: Sprite2D) -> Vector2:
	var image := sprite.texture.get_image()
	var rect := sprite.get_rect()
	var cell := Vector2i(rect.size)
	var source := Vector2i(sprite.frame%sprite.hframes,int(sprite.frame/sprite.hframes))*cell
	for y in range(cell.y):
		for x in range(cell.x):
			var world_point := sprite.to_global(rect.position+Vector2(x+0.5,y+0.5))
			var relative := world_point-root_node.global_position
			if absf(relative.x)>18 or relative.y < -28 or relative.y > -6: continue
			if image.get_pixelv(source+Vector2i(x,y)).a>0.999: return world_point
	return Vector2.INF

func pixel_case(title: String, target: Node2D, container: Node2D) -> void:
	if not capture: return
	var visibility := {}
	for child in lane.player.get_children():
		if child is CanvasItem and child!=probe:
			visibility[child]=child.visible
			child.hide()
	# Keep the production ancestors and Y-sort flags, hiding only neighbouring artwork.
	var branch: Node = target
	while branch!=container:
		var parent := branch.get_parent()
		for sibling in parent.get_children():
			if sibling is CanvasItem and sibling!=branch and sibling!=lane.player:
				visibility[sibling] = sibling.visible
				sibling.hide()
		branch = parent
	var anchor: Vector2 = target.global_position
	lane.player.position = anchor+Vector2(0,1)
	probe.hide()
	var baseline: Image = await pixels()
	var sprite := sprite_of(target)
	var point := pick_pixel(target,sprite) if sprite!=null else Vector2.INF
	if not point.is_finite():
		# Native herb crops are self drawn, with opaque leaf/stem pixels.
		var background := baseline.get_pixel(0,0)
		for y in range(-26,-5):
			for x in range(-12,13):
				var candidate := anchor+Vector2(x+0.5,y+0.5)
				if world_pixel(baseline,candidate)!=background: point=candidate; break
			if point.is_finite(): break
	check(title+" opaque probe point",point.is_finite())
	if point.is_finite():
		var expected := world_pixel(baseline,point)
		probe.show()
		lane.player.position = anchor-Vector2(0,1)
		var behind: Image = await pixels()
		check(title+" behind is occluded",world_pixel(behind,point).is_equal_approx(expected))
		lane.player.position = anchor+Vector2(0,1)
		var front: Image = await pixels()
		check(title+" in front is visible",world_pixel(front,point).is_equal_approx(Color.MAGENTA))
	probe.hide()
	for node in visibility:
		if is_instance_valid(node): node.visible=visibility[node]

func audit(container: Node2D, context: String) -> void:
	check(context+" shared feet sort",container.y_sort_enabled and lane.player.get_parent()==container)
	for child in container.get_children():
		if child==lane.player or not child is Node2D or not child.visible: continue
		var sprite := sprite_of(child)
		if sprite==null or sprite.texture==null or child.z_index<Depth.ACTOR: continue
		check(context+" "+child.name+" actor depth",child.z_index==0 and sprite.z_index==0)
		if child.get("status_layer")!=null: check(context+" "+child.name+" resource bar above foliage",child.status_layer.z_index==Depth.LABEL)
		var kind: String = child.get_meta("outdoor_kind",child.name)
		var key := context+":"+kind
		if tested_kinds.has(key): continue
		tested_kinds[key] = true
		await pixel_case(key,child,container)

func enter(target: String) -> void:
	loop.enter(target)
	await frames(3)
	lane.set_physics_process(false)
	loop.campaign_controller._process(0)
	loop.day_night.modulation.color = Color.WHITE
	for animation in get_nodes_in_group("ambient_props"): animation.set_process(false)
	if loop.area!=null: loop.area.set_process(false)

func shot(title: String, position: Vector2) -> void:
	if not capture: return
	lane.player.position = position
	var image: Image = await pixels()
	check("capture "+title,image.save_png(OUT+title+".png")==OK)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lane = load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	await frames(6)
	loop = lane.get_node("GameLoop")
	loop.enter("town")
	lane.automation = true
	lane.set_physics_process(false)
	loop.paused_for_test = true
	loop.set_process(false)
	loop.campaign_controller.set_process(false)
	loop.day_night.modulation.color = Color.WHITE
	lane.weather.clear_weather()
	loop.ui.hide()
	loop.hud.layer.hide()
	for child in lane.player.get_children():
		if child is CanvasItem: child.hide()
	probe = Polygon2D.new()
	probe.name = "DepthProbe"
	probe.polygon = PackedVector2Array([Vector2(-32,-48),Vector2(32,-48),Vector2(32,-2),Vector2(-32,-2)])
	probe.color = Color.MAGENTA
	probe.hide()
	lane.player.add_child(probe)
	for animation in get_nodes_in_group("ambient_props"): animation.set_process(false)
	check("tools inherit player depth",loop.harvest.get_parent()==lane.player and loop.harvest.z_index==0 and loop.harvest.actor.get_parent()==lane.player and loop.harvest.actor.z_index==0)
	check("town labels above world",loop.markers.z_index==Depth.LABEL)
	var residents: Array = loop.campaign_controller.actors
	for i in range(residents.size()):
		check("resident "+str(i)+" feet origin",sprite_of(residents[i]).offset==Vector2(0,-16) and residents[i].z_index==0)
		for j in range(i): check("residents "+str(i)+"/"+str(j)+" distinct stations",residents[i].position.distance_to(residents[j].position)>=16)
	await audit(lane.actors,"town")
	for target in ["field","dock","home","blacksmith","store","farm"]:
		await enter(target)
		await audit(loop.area,target)
		if target=="farm":
			loop.state.farm.plots={"0":{"growth":3,"watered":true},"1":{"growth":4,"watered":true,"crop":"turnip"}}
			loop.area._process(0)
			for key in loop.area.crop_nodes:
				check("crop "+key+" independent ground contact",loop.area.crop_nodes[key].position==loop.area.tile_center(int(key))+Vector2(0,7) and loop.area.crop_nodes[key].z_index==0)
				await pixel_case("farm crop "+key,loop.area.crop_nodes[key],loop.area)
			loop.state.farm.plots.clear()
			loop.area._process(0)
			check("harvest removes crop visuals",loop.area.crop_nodes.is_empty())
	for region in loop.state.Content.DATA.regions:
		await enter(region.id)
		check(region.id+" labels above foliage",loop.area.labels.z_index==Depth.LABEL)
		await audit(loop.area,region.id)
	await enter("home")
	for item in loop.state.Content.DATA.furniture:
		loop.state.campaign.placed=[{"id":item.id,"room":"home","cell":0}]
		loop.campaign_controller._update_decor()
		await frames()
		var decor: Node2D = loop.campaign_controller.decor
		var sprite: Sprite2D = decor.get_child(0)
		check("decor "+item.id+" individually sorted",decor.y_sort_enabled and decor.z_index==0 and sprite.offset==Vector2(0,-32))
		if item.shape=="rug":
			check("rug "+item.id+" lies under actors",sprite.z_index==Depth.FLOOR_DECOR)
		else: await pixel_case("decor "+item.id,sprite,loop.area)
	loop.state.campaign.placed=[]
	await enter("restaurant")
	check("restaurant ground separate",loop.area.get_node("Ground").z_index==Depth.GROUND)
	for level in range(5):
		loop.state.campaign.restaurant=level
		loop.area._process(0)
		var count: int = loop.state.Campaign.restaurant(loop.state).seats
		check("restaurant "+str(level)+" matching table collision",loop.area.solids.size()==6+count)
		for i in range(6): check("table "+str(level)+"/"+str(i)+" visibility and collision",loop.area.tables[i].visible==(i<count) and loop.area.tables[i].collision_layer==(1 if i<count else 0))
	loop.state.customers=[]
	for i in range(6):
		var customer := {"seat":i,"dish":i,"patience":25.0,"variant":i,"status":"waiting","eating_left":0.0}
		if i%2==1: customer.npc=i
		loop.state.customers.append(customer)
	loop.area._process(0)
	await audit(loop.area,"restaurant")
	check("held dish inherits player's feet",loop.area.held_visual.get_parent()==lane.player and loop.area.held_visual.z_index==0)
	check("restaurant orders above actors",loop.area.field_labels.z_index==Depth.LABEL)
	loop.state.customers[0].status="eating"
	loop.state.customers[0].eating_left=1.0
	loop.area._process(0)
	check("eating sprite frame",loop.area.customer_sprites[0].frame>=2 and loop.area.customer_sprites[0].frame<=5)
	loop.state.customers.clear()
	loop.area._process(0)
	check("departed guests disappear",not loop.area.customer_sprites[0].visible)
	# Final production screenshots use the real avatar, HUD and full environment.
	probe.queue_free()
	lane.avatar.show()
	loop.ui.show()
	loop.hud.layer.show()
	await enter("town")
	await shot("town",lane.SPAWN)
	var tree: Node2D
	for object in lane.actors.get_children():
		if object.get_meta("outdoor_kind","")=="outdoor_pine" and object.position==Vector2(351,463): tree=object; break
	if tree!=null:
		await shot("tree_behind",tree.position-Vector2(0,14))
		await shot("tree_front",tree.position+Vector2(0,14))
	await enter("restaurant")
	loop.state.customers=[{"seat":0,"dish":0,"patience":25.0,"variant":0,"status":"waiting","eating_left":0.0},{"seat":1,"dish":1,"patience":25.0,"npc":2,"status":"waiting","eating_left":0.0}]
	loop.area._process(0)
	await shot("restaurant_behind_guest",Vector2(110,220))
	await shot("restaurant_front_guest",Vector2(110,235))
	await enter("farm")
	loop.state.farm.plots={"0":{"growth":3,"watered":true},"1":{"growth":4,"watered":true,"crop":"turnip"}}
	loop.area._process(0)
	await shot("crops_behind",loop.area.tile_center(1)+Vector2(0,3))
	await shot("crops_front",loop.area.tile_center(1)+Vector2(0,15))
	Saves.end_session()
	print("DEPTH COMPLETE checks=",checks," failures=",failures," unique_kinds=",tested_kinds.size())
	lane.queue_free()
	await frames(4)
	loop=null
	lane=null
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
