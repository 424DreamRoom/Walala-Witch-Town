extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for method in ClassDB.class_get_method_list("FmodSound", true):
		print("FMOD METHOD ", method.name, " ", method.args)
	quit()
