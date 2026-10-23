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
var tracked_player: Node2D
var player_light: PointLight2D
var flicker_phase := 0.0
var lamp_flicker := 1.0

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
	player_light = PointLight2D.new()
	player_light.name = "WitchLanternLight"
	player_light.texture = light_texture
	player_light.texture_scale = 0.8
	player_light.color = Color("f2c17e")
	player_light.energy = 0.0
	player_light.range_z_max = 99
	player_light.shadow_enabled = false
	lights.add_child(player_light)
	set_process(true)

func _process(delta: float) -> void:
	# A shared, deterministic phase keeps every lantern in the same visual
	# language while avoiding the perfectly static light that makes dusk feel
	# flat.  This only changes light energy; it never touches the clock or save
	# state.
	flicker_phase = fposmod(flicker_phase + delta, TAU * 4.0)
	var pulse := sin(flicker_phase * 1.7) * 0.018 + sin(flicker_phase * 3.9 + 0.7) * 0.012
	lamp_flicker = clampf(1.0 + pulse, 0.94, 1.06)
	if not is_instance_valid(lights): return
	for light in lights.get_children():
		if not is_instance_valid(light) or light == player_light: continue
		light.energy = lamp_strength * 0.85 * lamp_flicker
	if is_instance_valid(player_light):
		player_light.energy = lamp_strength * 0.58 * (0.98 + sin(flicker_phase * 2.4) * 0.02)

func bind_player(next_player: Node2D) -> void:
	tracked_player = next_player
	if is_instance_valid(player_light) and is_instance_valid(tracked_player):
		player_light.global_position = tracked_player.global_position

func configure(next_location: String) -> void:
	location = next_location
	for light in lights.get_children():
		if light != player_light:
			light.free()
	if is_instance_valid(player_light):
		player_light.position = Vector2.ZERO
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
		light.energy = lamp_strength * (0.85 if light != player_light else 0.58)
	if is_instance_valid(tracked_player) and is_instance_valid(player_light):
		player_light.global_position = tracked_player.global_position
		player_light.enabled = lamp_strength > 0.12
		player_light.energy = lamp_strength * 0.58
		player_light.color = Color("f4c680") if time_of_day in ["evening", "night"] else Color("f2d6a4")
