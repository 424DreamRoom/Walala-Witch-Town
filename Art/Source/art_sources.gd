extends Node
## Source loading is registered before game scenes and their themes are loaded.
const Source = preload("res://Art/Source/aseprite_source.gd")

func _init() -> void:
	Source.install()

func _ready() -> void:
	get_tree().root.theme = Source.theme("res://Art/UI/FramewrightLite/themes/walala_theme.tres")
	if DisplayServer.get_name() != "headless":
		DisplayServer.set_icon(Source.texture("res://icon.svg.aseprite").get_image())
