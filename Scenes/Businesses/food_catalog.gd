extends RefCounted
## Runtime exports of the user's read-only MyArt originals.
static var DATA := {
	"bread": {"name": "面包", "price": 6, "texture": preload("res://Art/Source/aseprite_source.gd").texture("res://MyArt/Icon/Food/bread.aseprite")},
	"egg": {"name": "鸡蛋", "price": 4, "texture": preload("res://Art/Source/aseprite_source.gd").texture("res://MyArt/Icon/Food/egg.aseprite")},
	"tomato": {"name": "番茄", "price": 5, "texture": preload("res://Art/Source/aseprite_source.gd").texture("res://MyArt/Icon/Food/tomato.aseprite")}
}
