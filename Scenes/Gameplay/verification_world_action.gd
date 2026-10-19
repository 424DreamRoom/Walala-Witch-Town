extends RefCounted
## Verification helper: the real left-click world action used by the player.
## Kept in one place so every older suite exercises the same input path.

static func press(tree: SceneTree) -> void:
	var screen: Vector2 = tree.root.get_visible_rect().size / 2.0
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = screen
		event.global_position = screen
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame
