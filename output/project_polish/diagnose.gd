extends SceneTree
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Saves = preload("res://Scenes/Save/save_store.gd")
func _initialize():
	Preferences.file_path = "res://output/project_polish/diagnose_preferences.cfg"
	Saves.directory = "res://output/project_polish/diagnose_saves"
	Saves.end_session()
	run.call_deferred()
func run():
	var lane=load("res://Scenes/LanternLane/lantern_lane.tscn").instantiate()
	root.add_child(lane)
	for i in range(5): await process_frame
	var loop=lane.get_node("GameLoop")
	loop.paused_for_test=true
	loop.enter("town")
	for i in range(5): await process_frame
	var kinds={}
	for node in get_nodes_in_group("ambient_props"): kinds[node.kind]=int(kinds.get(node.kind,0))+1
	print("DIAG town ambient ",kinds," actors=",lane.actors.get_child_count()," location=",loop.location)
	print("DIAG shelters ",loop.campaign_controller.routines.shelters)
	loop.enter("blacksmith")
	lane.player.position=loop.area.stations.service
	loop.area.interact()
	for i in range(5): await process_frame
	var button=loop.area.service_panel.get_node("WandUpgrades")
	print("DIAG button ",button.visible," ",button.disabled," ",button.get_global_rect()," root=",root.get_visible_rect()," container=",lane.viewport.get_parent().scale)
	var at=lane.viewport.get_parent().position+button.get_global_rect().get_center()*lane.viewport.get_parent().scale
	button.pressed.connect(func(): print("DIAG pressed at ",lane.player.position," service ",loop.area.stations.service," modal=",loop.hud.mode," paused=",paused))
	button.button_down.connect(func(): print("DIAG down"))
	button.button_up.connect(func(): print("DIAG up"))
	var motion=InputEventMouseMotion.new()
	motion.position=at
	root.push_input(motion,true)
	for i in range(3): await process_frame
	print("DIAG hovered ",lane.viewport.gui_get_hovered_control()," root_hover ",root.gui_get_hovered_control()," at=",at)
	for down in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=at
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		root.push_input(event,true)
		for i in range(3): await process_frame
	print("DIAG upgrades ",loop.hud.mode," ",paused," at_service ",loop.area._at_service()," panel ",loop.area.service_panel.visible)
	quit()
