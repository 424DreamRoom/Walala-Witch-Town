extends SceneTree
func _initialize():
	for item in ProjectSettings.get_property_list():
		if String(item.name).begins_with("Fmod/"): print(item.name, "=", ProjectSettings.get_setting(item.name))
	quit()
