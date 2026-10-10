class_name AmbientAnimation
extends Node

const ART := "res://Art/Environment/Hearthwood/Ambient/"
static var registry: Dictionary = {}
var sprite: Sprite2D
var kind := ""
var weather
var spec: Dictionary
var atlas: Texture2D
var original: Texture2D
var enabled := true
var elapsed := 0.0
var frames_per_bank := 12

static func attach(target: Sprite2D, asset_kind: String, weather_effect = null) -> AmbientAnimation:
	if registry.is_empty():
		registry = JSON.parse_string(FileAccess.get_file_as_string(ART + "manifest.json"))
	if not registry.assets.has(asset_kind):
		return null
	var animation := AmbientAnimation.new()
	animation.name = "AmbientMotion"
	animation.sprite = target
	animation.original = target.texture
	animation.kind = asset_kind
	animation.weather = weather_effect
	animation.spec = registry.assets[asset_kind]
	animation.frames_per_bank = int(registry.frames_per_bank)
	animation.atlas = load(ART + asset_kind + ".png")
	var feet: Vector2 = target.get_parent().position
	animation.elapsed = fposmod(feet.x * 0.019 + feet.y * 0.023, animation.frames_per_bank / float(animation.spec.fps))
	target.add_child(animation)
	animation.set_enabled(true)
	return animation

func _ready() -> void:
	add_to_group("ambient_props")

func set_enabled(value: bool) -> void:
	enabled = value
	set_process(value)
	if value:
		sprite.texture = atlas
		sprite.hframes = frames_per_bank
		sprite.vframes = int(spec.banks)
		update_frame()
	else:
		sprite.frame = 0
		sprite.hframes = 1
		sprite.vframes = 1

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not enabled:
		return
	var windy: bool = spec.motion == "wind" and is_instance_valid(weather) and weather.get_weather() != "clear"
	var speed := 1.35 if windy else 1.0
	elapsed = fposmod(elapsed + delta * speed, frames_per_bank / float(spec.fps))
	update_frame()

func update_frame() -> void:
	var windy: bool = spec.motion == "wind" and is_instance_valid(weather) and weather.get_weather() != "clear"
	var bank := 1 if windy and int(spec.banks) > 1 else 0
	var index := mini(frames_per_bank - 1, int(elapsed * float(spec.fps))) + bank * frames_per_bank
	if sprite.frame != index:
		sprite.frame = index
