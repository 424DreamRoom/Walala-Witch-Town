extends RefCounted
## Cached in-memory colour variants; source artwork and pixel geometry stay intact.
const Source = preload("res://Art/Source/aseprite_source.gd")
const WitchAnimation = preload("res://Art/Character/Storybook/WalalaWitchAseprite32/witch_animation.gd")
const NAMES := {"blue": "蓝色法杖", "red": "红色法杖"}
const PALETTES := {
	"blue": [Color("438dcc"), Color("73baff"), Color("e1f3ff")],
	"red": [Color("c64c58"), Color("f17a80"), Color("ffe4e4")]
}
static var icons: Dictionary = {}
static var actions: Dictionary = {}

static func color(mode: String) -> Color:
	return PALETTES[mode][1]

static func icon_texture(mode: String) -> Texture2D:
	if not icons.has(mode):
		var pixels := Source.texture("res://Art/UI/NativeIcons/wand.aseprite").get_image().duplicate() as Image
		_replace_colors(pixels, [Color("8977ad"), Color("b39dcf"), Color("ede1f3")], PALETTES[mode])
		icons[mode] = ImageTexture.create_from_image(pixels)
	return icons[mode]

static func action_texture(mode: String) -> Texture2D:
	if not actions.has(mode):
		var pixels := Source.texture(WitchAnimation.SHEET).get_image().duplicate() as Image
		var palette: Array = PALETTES[mode]
		# Keys m/n/z of draw_witch.lua; keep in sync with the witch palette.
		_replace_colors(pixels, [Color("78c8cf"), Color("b4efe0"), Color("edfffa")], palette)
		# Change only the two wand-tip pixels, never gold in the player's clothes.
		for facing in range(4):
			for animation in ["cast", "fish-cast", "fish-wait", "fish-reel"]:
				var tag := WitchAnimation.tag_for(animation, facing)
				for frame in range(int(tag.from), int(tag.to) + 1):
					var origin := Vector2i(frame % WitchAnimation.COLUMNS, frame / WitchAnimation.COLUMNS) * 32
					var tip := origin + WitchAnimation.wand_tip(animation, facing, frame - int(tag.from))
					for offset in range(2):
						var point := tip + Vector2i(-offset if facing == 3 else offset, 0)
						if pixels.get_pixelv(point) in [Color("fdf0d6"), Color("ffdda0")]:
							pixels.set_pixelv(point, palette[2 if offset == 0 else 1])
		actions[mode] = ImageTexture.create_from_image(pixels)
	return actions[mode]

static func _replace_colors(pixels: Image, original: Array, replacement: Array) -> void:
	for y in range(pixels.get_height()):
		for x in range(pixels.get_width()):
			var index := original.find(pixels.get_pixel(x, y))
			if index >= 0: pixels.set_pixel(x, y, replacement[index])
