extends Node
## Hardware cursor: independent of the pixel canvas, pause and scene changes.
static var HAT = preload("res://Art/Source/aseprite_source.gd").texture("res://Art/UI/WitchCursor/witch_hat.aseprite")
const HOTSPOT := Vector2(4, 4)

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Map destinations request POINTING_HAND; keep the decorated arrow there.
	Input.set_custom_mouse_cursor(HAT, Input.CURSOR_ARROW, HOTSPOT)
	Input.set_custom_mouse_cursor(HAT, Input.CURSOR_POINTING_HAND, HOTSPOT)

func _exit_tree() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Release Input's texture references while the rendering server is still alive.
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
