extends Control
## Native pixel ornaments, with shared food textures preferring MyArt.
var kind := "clock"
var wand_mode := "red"
var progress := 0.0
var night := false
var weather := "clear"
var divisions := 12
var bake_base := false
static var native_textures: Dictionary = {}
const NATIVE_IDS := ["seed", "wand", "mushroom", "berry", "herb", "journal", "bag", "help", "book", "clock_day", "clock_night", "weather_clear_day", "weather_clear_night", "weather_rain_day", "weather_rain_night", "weather_snow_day", "weather_snow_night"]
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const FoodIcons = preload("res://Scenes/UI/food_icons.gd")
const ShopFood = preload("res://Scenes/Businesses/food_catalog.gd")
const WandVisuals = preload("res://Scenes/Equipment/wand_visuals.gd")
const INK := Color("422b32")
const GOLD := Color("dfb66f")
const PAPER := Color("f4e5bf")
static var RESOURCE_TEXTURES := {
	"wood": preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Icon/Resources16_Original/wood.aseprite"),
	"stone": preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Icon/Resources16_Original/stone.aseprite"),
	"gold": preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Icon/Resources16_Original/gold.aseprite"),
	"ore": preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Icon/Resources16_Original/iron_ore.aseprite"),
	"iron": preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Icon/Resources16_Original/iron.aseprite"),
	"fish": preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Icon/Resources16_Original/fish.aseprite"),
	"coin": preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Icon/Resources16_Original/witch_coin.aseprite")
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)

func _draw() -> void:
	if kind == "wand":
		draw_texture(WandVisuals.icon_texture(wand_mode), Vector2.ZERO)
		return
	if kind in ShopFood.DATA:
		var texture: Texture2D = ShopFood.DATA[kind].texture
		draw_texture(texture, ((size - texture.get_size()) / 2.0).floor())
		return
	if kind == "hotbar":
		draw_style_box(UISkin.THEME.get_stylebox("normal", "Button"), Rect2(Vector2.ZERO, size))
		var cell_width := (size.x - 8) / divisions
		for i in range(1, divisions):
			var x := 4 + i * cell_width
			box(x - 1, 5, 1, size.y - 10, Color("74482f"))
			box(x, 5, 1, size.y - 10, Color("b9824e"))
		return
	if kind == "rhythm":
		# A two-tone timeline makes the day/evening handoff legible at a glance.
		var width := maxf(1.0, size.x)
		var progress_width := clampf(progress, 0.0, 1.0) * width
		box(0, 1, width, 2, Color("513d35", 0.72))
		box(0, 1, progress_width, 2, Color("9cbe8d") if not night else Color("e4b36e"))
		for tick in [0.25, 0.5, 0.75]:
			var x := roundf(width * tick)
			box(x, 0, 1, 4, Color("ead3a0", 0.62))
		box(progress_width - 1, 0, 2, 4, Color("fff0c8"))
		return
	if kind in RESOURCE_TEXTURES:
		# Native 16x16 content centered on the existing UI ornament canvas.
		draw_texture(RESOURCE_TEXTURES[kind], ((size - Vector2(16, 16)) / 2.0).floor())
		return
	var food: Texture2D = FoodIcons.texture(kind)
	if food != null:
		draw_texture(food, ((size - food.get_size()) / 2.0).floor())
		return
	var key := kind
	if kind == "clock": key = "clock_night" if night else "clock_day"
	elif kind == "weather": key = "weather_" + weather + ("_night" if night else "_day")
	if key not in NATIVE_IDS: return
	if not native_textures.has(key):
		native_textures[key] = preload("res://Art/Source/aseprite_source.gd").texture("res://Art/UI/NativeIcons/" + key + ".aseprite")
	if kind == "book": draw_texture_rect(native_textures[key], Rect2(Vector2.ZERO, size), false)
	else: draw_texture(native_textures[key], Vector2.ZERO)
	if kind == "clock" and not bake_base:
		var hour_angle := (-PI / 2) + progress * TAU
		var minute_angle := (-PI / 2) + fposmod(progress * 12.0, 1.0) * TAU
		draw_line(Vector2(16,16), (Vector2(16,16) + Vector2(cos(minute_angle), sin(minute_angle)) * 9).round(), GOLD if night else INK, 1, false)
		draw_line(Vector2(16,16), (Vector2(16,16) + Vector2(cos(hour_angle), sin(hour_angle)) * 6).round(), GOLD if night else INK, 2, false)
		box(15,15,3,3,Color("bb745d"))
