extends "res://Scenes/MainMenu/verify_save_deletion.gd"

func shot(name: String) -> void:
	if not capture or name != "deleted_slot":
		return
	await frames()
	RenderingServer.force_draw(false)
	var pixels: Image = menu.viewport.get_texture().get_image()
	pixels.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	check("screenshot without deletion status", pixels.save_png("res://output/delete_status_cleanup/deleted_slot.png") == OK)
