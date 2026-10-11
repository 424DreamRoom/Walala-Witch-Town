extends PointLight2D
var loop

func _ready() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	var glow := GradientTexture2D.new()
	glow.width = 128
	glow.height = 128
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.gradient = gradient
	texture = glow
	color = Color("ffce8a")
	blend_mode = Light2D.BLEND_MODE_ADD
	range_z_max = 99
	shadow_enabled = false

func _process(_delta: float) -> void:
	energy = 0.45 if loop.location == "home" else smoothstep(1020.0, 1200.0, loop.state.get_time_minutes()) * 0.85
	enabled = energy > 0.001
