extends "res://Scenes/Campaign/verify_guide.gd"
## Reuse the isolated guide verification; save visual evidence in this task's folder.
const CAPTURE_OUT := "res://output/dialogue_bottom_align/"
var geometry: Dictionary = {}

func shot(filename: String) -> void:
	if not capture or not (filename.begins_with("welcome_") or filename == "topics_zh_TW"):
		return
	await frames(4)
	await RenderingServer.frame_post_draw
	var pixels: Image = lane.viewport.get_texture().get_image()
	pixels.resize(1920,1080,Image.INTERPOLATE_NEAREST)
	check("capture " + filename, pixels.save_png(CAPTURE_OUT + filename + ".png") == OK)
	var portrait: TextureRect = loop.hud.modal.find_child("DialoguePortrait", true, false)
	geometry[filename] = {
		"hotbar_bottom": loop.hud.hotbar_art.get_global_rect().end.y,
		"portrait_frame_bottom": portrait.get_parent().get_global_rect().end.y,
		"text_frame_bottom": loop.hud.dialogue_text.get_parent().get_global_rect().end.y,
		"dialogue_offset_y": loop.hud.modal.get_node("DialogueLayout").position.y,
		"canvas_height": lane.viewport.size.y
	}
	var report := FileAccess.open(CAPTURE_OUT + "geometry.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(geometry,"\t"))
