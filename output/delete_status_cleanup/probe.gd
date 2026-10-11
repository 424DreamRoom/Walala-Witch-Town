extends SceneTree

func _initialize() -> void:
	print("ISOLATED_USER_DATA ", OS.get_user_data_dir())
	quit()
