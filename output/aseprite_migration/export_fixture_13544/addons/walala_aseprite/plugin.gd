@tool
extends EditorPlugin
const Source = preload("res://Art/Source/aseprite_source.gd")

func _enter_tree() -> void:
	Source.install()

func _exit_tree() -> void:
	if Source.registered != null:
		if "aseprite" in ResourceLoader.get_recognized_extensions_for_type("Texture2D"):
			ResourceLoader.remove_resource_format_loader(Source.registered)
		Source.registered = null
