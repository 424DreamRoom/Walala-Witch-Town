extends RefCounted
## Read the timings and ranges exported from the editable Aseprite source.
const SHEET := "res://Art/Character/Storybook/WalalaWitchAseprite32/walala-witch.aseprite"
const MANIFEST := "res://Art/Character/Storybook/WalalaWitchAseprite32/character-manifest.json"
const COLUMNS := 8
const ROWS := 19
const DIRECTIONS := ["down", "up", "right", "left"]
static var catalog: Dictionary = {}

static func animations() -> Dictionary:
	if catalog.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		var source_tags: Dictionary = preload("res://Art/Source/aseprite_source.gd").texture(SHEET).get_meta("aseprite_tags")
		for tag in data.animations:
			if source_tags.has(tag.name):
				for key in ["from", "to", "durations_ms"]: tag[key] = source_tags[tag.name][key]
			catalog[tag.name] = tag
	return catalog

static func tag_for(action: String, facing: int) -> Dictionary:
	return animations()[action + "-" + DIRECTIONS[clampi(facing, 0, 3)]]

static func configure(sprite: Sprite2D) -> void:
	sprite.texture = load(SHEET)
	sprite.hframes = COLUMNS
	sprite.vframes = ROWS

static func frame_for(action: String, facing: int, elapsed: float, duration_override: float = 0.0) -> int:
	var tag := tag_for(action, facing)
	var total := 0.0
	for ms in tag.durations_ms:
		total += float(ms) / 1000.0
	var time := maxf(0.0, elapsed)
	if duration_override > 0.0:
		time = minf(time / duration_override, 0.999999) * total
	elif tag.loop:
		time = fposmod(time, total)
	else:
		time = minf(time, total - 0.000001)
	for offset in range(tag.durations_ms.size()):
		var duration := float(tag.durations_ms[offset]) / 1000.0
		if time < duration:
			return int(tag.from) + offset
		time -= duration
	return int(tag.to)

static func fishing_tip(animation: String, facing: int, elapsed: float, duration: float = 0.0) -> Vector2:
	var tag := tag_for(animation, facing)
	var step := frame_for(animation, facing, elapsed, duration) - int(tag.from)
	var pose := step + 2 if animation == "fish-cast" else 6 - step if animation == "fish-reel" else 4 + step
	var tips := [Vector2(24,19), Vector2(23,15), Vector2(23,13), Vector2(25,15), Vector2(26,22), Vector2(26,23), Vector2(25,23), Vector2(24,20)]
	if facing == 1:
		tips = [Vector2(24,17), Vector2(23,13), Vector2(23,9), Vector2(25,10), Vector2(26,12), Vector2(26,13), Vector2(25,14), Vector2(24,17)]
	elif facing >= 2:
		tips = [Vector2(23,18), Vector2(22,14), Vector2(24,12), Vector2(27,14), Vector2(28,19), Vector2(28,20), Vector2(26,19), Vector2(24,19)]
	var tip: Vector2 = tips[pose]
	if facing == 3:
		tip.x = 31.0 - tip.x
	return tip - Vector2(16, 32)
