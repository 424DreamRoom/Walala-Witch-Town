extends AnimatedSprite2D
## Visual state follows the storage modal, including while the world is paused.
static var FRAMES: Array[Texture2D] = [
	preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Props/KarsioriChest/closed.aseprite"),
	preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Props/KarsioriChest/opening_1.aseprite"),
	preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Props/KarsioriChest/opening_2.aseprite"),
	preload("res://Art/Source/aseprite_source.gd").texture("res://Art/Props/KarsioriChest/open.aseprite"),
]
var home: Node2D
var chest_id := -1
var opened := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position.y = -FRAMES[0].get_height() / 2.0
	sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	for state in ["closed", "open", "opening", "closing"]:
		sprite_frames.add_animation(state)
		sprite_frames.set_animation_loop(state, false)
		sprite_frames.set_animation_speed(state, 10.0)
	sprite_frames.add_frame("closed", FRAMES[0])
	sprite_frames.add_frame("open", FRAMES[3])
	for index in range(FRAMES.size()):
		sprite_frames.add_frame("opening", FRAMES[index])
		sprite_frames.add_frame("closing", FRAMES[FRAMES.size() - 1 - index])
	animation_finished.connect(_settle)
	play("closed")

func _settle() -> void:
	if animation in ["opening", "closing"]: play("open" if opened else "closed")

func _process(_delta: float) -> void:
	if not is_instance_valid(home) or home.loop.hud == null: return
	var hud = home.loop.hud
	var active: bool = hud.mode == "chest" and is_instance_valid(hud.chest_view) and hud.chest_view.chest_id == chest_id
	if active == opened: return
	opened = active
	play("opening" if opened else "closing")
