@tool
extends ResourceFormatLoader
## Read editable Aseprite bytes directly; no PNG fallback or source-side imports.
## Format: https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md
static var registered: ResourceFormatLoader
static var layouts: Dictionary = {}

static func install() -> void:
	if registered == null:
		registered = load("res://Art/Source/aseprite_source.gd").new()
		ResourceLoader.add_resource_format_loader(registered, true)
		var path := "res://Art/Source/sheets.json"
		if FileAccess.file_exists(path):
			layouts = JSON.parse_string(FileAccess.get_file_as_string(path))

static func texture(path: String) -> Texture2D:
	install()
	return load(path) as Texture2D

static func theme(path: String) -> Theme:
	install()
	return load(path) as Theme

static func resource(path: String) -> Resource:
	install()
	return load(path)

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["aseprite", "ase"])

func _handles_type(type: StringName) -> bool:
	return type in [&"Texture2D", &"ImageTexture", &"Resource"]

func _recognize_path(path: String, type: StringName) -> bool:
	return path.get_extension().to_lower() in ["aseprite", "ase"] and (type == &"" or _handles_type(type))

func _get_resource_type(path: String) -> String:
	return "ImageTexture" if path.get_extension().to_lower() in ["aseprite", "ase"] else ""

func _get_resource_uid(_path: String) -> int:
	# Declaring custom UID support prevents Godot creating .uid beside originals.
	# Sources use their stable res:// paths; no file or directory is written here.
	return -1

func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
	var decoded := decode(path)
	if decoded.is_empty():
		return ERR_FILE_CORRUPT
	var result := ImageTexture.create_from_image(decoded.image)
	result.set_meta("aseprite_frames", decoded.frames)
	result.set_meta("aseprite_tags", decoded.tags)
	result.set_meta("aseprite_source", path)
	return result

static func decode(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 128 or bytes.decode_u16(4) != 0xa5e0:
		push_error("Invalid Aseprite source: " + path)
		return {}
	var count := bytes.decode_u16(6)
	var width := bytes.decode_u16(8)
	var height := bytes.decode_u16(10)
	var depth := bytes.decode_u16(12)
	var columns := int(layouts.get(path, {}).get("columns", count))
	var rows := int(layouts.get(path, {}).get("rows", ceili(float(count) / columns)))
	var sheet := Image.create(width * columns, height * rows, false, Image.FORMAT_RGBA8)
	var layers: Array[Dictionary] = []
	var history: Array[Dictionary] = []
	var timings: Array[int] = []
	var tags: Dictionary = {}
	var palette := PackedColorArray()
	palette.resize(256)
	var position := 128
	for frame in count:
		var frame_end := position + bytes.decode_u32(position)
		var chunks := bytes.decode_u32(position + 12)
		if chunks == 0: chunks = bytes.decode_u16(position + 6)
		timings.append(bytes.decode_u16(position + 8))
		position += 16
		var cels: Dictionary = {}
		for _chunk in chunks:
			var end := position + bytes.decode_u32(position)
			var kind := bytes.decode_u16(position + 4)
			var p := position + 6
			match kind:
				0x2004:
					if bytes.decode_u16(p + 10) != 0:
						push_error("Unsupported Aseprite blend mode: " + path)
						return {}
					layers.append({"visible": bool(bytes.decode_u16(p) & 1), "level": bytes.decode_u16(p + 4), "opacity": bytes[p + 12]})
				0x2019:
					var first := bytes.decode_u32(p + 4)
					var last := bytes.decode_u32(p + 8)
					palette.resize(maxi(palette.size(), last + 1))
					p += 20
					for index in range(first, last + 1):
						var flags := bytes.decode_u16(p)
						palette[index] = Color8(bytes[p + 2], bytes[p + 3], bytes[p + 4], bytes[p + 5])
						p += 6
						if flags & 1: p += 2 + bytes.decode_u16(p)
				0x2018:
					var tag_count := bytes.decode_u16(p)
					p += 10
					for _tag in tag_count:
						var first := bytes.decode_u16(p)
						var last := bytes.decode_u16(p + 2)
						var direction := bytes[p + 4]
						var length := bytes.decode_u16(p + 17)
						var name := bytes.slice(p + 19, p + 19 + length).get_string_from_utf8()
						tags[name] = {"from": first, "to": last, "direction": direction}
						p += 19 + length
				0x2005:
					var layer := bytes.decode_u16(p)
					var origin := Vector2i(bytes.decode_s16(p + 2), bytes.decode_s16(p + 4))
					var opacity := bytes[p + 6]
					var cel_type := bytes.decode_u16(p + 7)
					var cel: Image
					if cel_type == 1:
						cel = history[bytes.decode_u16(p + 16)][layer].image
					elif cel_type in [0, 2]:
						var cw := bytes.decode_u16(p + 16)
						var ch := bytes.decode_u16(p + 18)
						var pixels := bytes.slice(p + 20, end)
						if cel_type == 2: pixels = pixels.decompress(cw * ch * (depth / 8), FileAccess.COMPRESSION_DEFLATE)
						if depth == 32:
							cel = Image.create_from_data(cw, ch, false, Image.FORMAT_RGBA8, pixels)
						else:
							cel = Image.create(cw, ch, false, Image.FORMAT_RGBA8)
							for y in ch:
								for x in cw:
									var i := y * cw + x
									var color := Color8(pixels[i * 2], pixels[i * 2], pixels[i * 2], pixels[i * 2 + 1]) if depth == 16 else palette[pixels[i]]
									if depth == 8 and pixels[i] == bytes[28]: color.a = 0
									cel.set_pixel(x, y, color)
					else:
						push_error("Unsupported Aseprite cel type: " + path)
						return {}
					cels[layer] = {"image": cel, "origin": origin, "opacity": opacity, "z": bytes.decode_s16(p + 9)}
			position = end
		position = frame_end
		history.append(cels)
		var composite := Image.create(width, height, false, Image.FORMAT_RGBA8)
		var order := cels.keys()
		order.sort_custom(func(a: int, b: int) -> bool: return a + cels[a].z < b + cels[b].z if a + cels[a].z != b + cels[b].z else a < b)
		var first_cel := true
		for index in order:
			var layer: Dictionary = layers[index]
			var visible: bool = layer.visible
			var ancestor_level: int = layer.level
			for parent in range(index - 1, -1, -1):
				if layers[parent].level < ancestor_level:
					visible = visible and layers[parent].visible
					ancestor_level = layers[parent].level
			if not visible: continue
			var cel: Image = cels[index].image
			var opacity := int(cels[index].opacity) * int(layer.opacity) / 255.0
			if opacity < 255:
				cel = cel.duplicate()
				for y in cel.get_height():
					for x in cel.get_width():
						var color := cel.get_pixel(x, y)
						color.a *= opacity / 255.0
						cel.set_pixel(x, y, color)
			if first_cel:
				composite.blit_rect(cel, Rect2i(Vector2i.ZERO, cel.get_size()), cels[index].origin)
				first_cel = false
			else:
				blend(composite, cel, cels[index].origin)
		sheet.blit_rect(composite, Rect2i(0, 0, width, height), Vector2i(frame % columns * width, frame / columns * height))
	for tag in tags.values(): tag["durations_ms"] = timings.slice(tag.from, tag.to + 1)
	return {"image": sheet, "frames": timings, "tags": tags}

static func blend(destination: Image, source: Image, origin: Vector2i) -> void:
	# Integer straight-alpha composition matches the project's Pillow authors.
	# Godot Image.blend_rect rounds partially transparent RGB differently.
	var dst := destination.get_data()
	var src := source.get_data()
	var width := destination.get_width()
	var sw := source.get_width()
	for y in range(maxi(0, -origin.y), mini(source.get_height(), destination.get_height() - origin.y)):
		for x in range(maxi(0, -origin.x), mini(sw, width - origin.x)):
			var s := (y * sw + x) * 4
			var d := ((y + origin.y) * width + x + origin.x) * 4
			var alpha := int(src[s + 3])
			if alpha == 0: continue
			if alpha == 255 or dst[d + 3] == 0:
				for channel in 4: dst[d + channel] = src[s + channel]
				continue
			var out_alpha := alpha * 255 + int(dst[d + 3]) * (255 - alpha)
			var coefficient := alpha * 255 * 255 * 128 / out_alpha
			var other := 255 * 128 - coefficient
			for channel in 3:
				var value := int(src[s + channel]) * coefficient + int(dst[d + channel]) * other + 16384
				dst[d + channel] = ((value >> 8) + value) >> 15
			var rounded := out_alpha + 128
			dst[d + 3] = ((rounded >> 8) + rounded) >> 8
	destination.set_data(destination.get_width(), destination.get_height(), false, Image.FORMAT_RGBA8, dst)
