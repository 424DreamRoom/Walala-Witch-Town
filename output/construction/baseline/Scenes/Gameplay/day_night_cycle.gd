extends Node
## One canvas light controller shared by every gameplay map; UI has its own canvas.
const ART := "res://Art/Environment/Hearthwood/"
const INDOORS := ["restaurant", "home", "blacksmith", "store", "furniture_store"]
const LIGHT_TIMES := [0.0, 360.0, 540.0, 960.0, 1020.0, 1080.0, 1200.0, 1320.0, 1440.0]
const LIGHT_COLORS := [
	Color("68749e"), Color("dfc4ad"), Color.WHITE, Color.WHITE,
	Color("f5d2ac"), Color("dca38e"), Color("8992ba"), Color("68749e"), Color("68749e")
]
var modulation: CanvasModulate
var lights: Node2D
var light_texture: GradientTexture2D
var location := "town"
var time_of_day := "morning"
var minutes := 360.0
var lamp_strength := 0.0

func _ready() -> void:
	modulation = CanvasModulate.new()
	modulation.name = "TimeOfDayModulate"
	add_child(modulation)
	lights = Node2D.new()
	lights.name = "TimeOfDayLights"
	add_child(lights)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	light_texture = GradientTexture2D.new()
	light_texture.width = 128
	light_texture.height = 128
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(1.0, 0.5)
	light_texture.gradient = gradient

func configure(next_location: String) -> void:
	location = next_location
	for light in lights.get_children():
		light.free()
	if location == "town":
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "town_layout.json"))
		for prop in layout.props:
			if prop.kind == "outdoor_lamp":
				# The lantern is offset from the post's feet in the 32x76 sprite.
				_add_light(Vector2(prop.x + 10, prop.y - 55))
	elif location == "farm":
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART + "farm_layout.json"))
		for anchor in layout.get("lights", []):
			_add_light(Vector2(anchor[0], anchor[1]))

func _add_light(anchor: Vector2) -> void:
	var light := PointLight2D.new()
	light.position = anchor
	light.texture = light_texture
	light.texture_scale = 1.25
	light.color = Color("ffce8a")
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.range_z_max = 99
	light.shadow_enabled = false
	lights.add_child(light)

static func outdoor_color(at_minutes: float) -> Color:
	var time := clampf(at_minutes, 0.0, 1440.0)
	for i in range(1, LIGHT_TIMES.size()):
		if time <= LIGHT_TIMES[i]:
			var weight: float = inverse_lerp(LIGHT_TIMES[i - 1], LIGHT_TIMES[i], time)
			return LIGHT_COLORS[i - 1].lerp(LIGHT_COLORS[i], smoothstep(0.0, 1.0, weight))
	return LIGHT_COLORS[-1]

func sync(state) -> void:
	minutes = state.get_time_minutes()
	time_of_day = state.get_time_of_day()
	var tint := outdoor_color(minutes)
	# Interior lamps keep rooms readable while daylight still changes gently.
	if location in INDOORS:
		tint = Color.WHITE.lerp(tint, 0.2).lerp(Color("ffe6c7"), 0.12)
	modulation.color = tint
	lamp_strength = smoothstep(1020.0, 1200.0, minutes)
	for light in lights.get_children():
		light.enabled = lamp_strength > 0.001
		light.energy = lamp_strength * 0.85
