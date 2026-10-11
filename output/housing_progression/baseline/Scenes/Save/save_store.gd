extends RefCounted
## Six independent JSON slots. Writes use a verified temporary file and backup.
const State = preload("res://Scenes/Gameplay/loop_state.gd")
const SLOT_COUNT := 6
const VERSION := 1
const GAME_ID := "walala_witch_town"
const LOCATION_NAMES = {"town": "小镇", "farm": "月芽农场", "field": "野外", "restaurant": "餐厅", "home": "魔女之家", "dock": "潮汐码头", "blacksmith": "铁匠铺", "store": "杂货店"}
const WORLD_SIZES = {"town": Vector2(1280, 960), "farm": Vector2(960, 720), "field": Vector2(640, 360), "restaurant": Vector2(640, 360), "home": Vector2(640, 480), "dock": Vector2(640, 360), "blacksmith": Vector2(640, 480), "store": Vector2(640, 480)}
static var directory := "user://saves"
static var active_slot := 0
static var pending: Dictionary = {}
static var play_seconds := 0.0
static var created_at := 0

static func slot_path(slot: int) -> String:
	return directory.path_join("slot_%02d.json" % slot)

static func end_session() -> void:
	active_slot = 0
	pending = {}
	play_seconds = 0.0
	created_at = 0

static func _failure(message: String, code: String = "invalid") -> Dictionary:
	return {"ok": false, "error": message, "code": code}

static func _point(value: Variant, bounds: Vector2) -> bool:
	return value is Array and value.size() == 2 and State._number(value[0], 0, bounds.x) and State._number(value[1], 0, bounds.y)

static func normalize_snapshot(data: Variant) -> Dictionary:
	if not data is Dictionary or not data.get("world") is Dictionary:
		return {}
	var state := State.normalize_save_data(data.get("state"))
	var world: Dictionary = data.world
	if state.is_empty() or world.get("location") not in LOCATION_NAMES:
		return {}
	if not _point(world.get("position"), WORLD_SIZES[world.location]) or not _point(world.get("town_position"), WORLD_SIZES.town):
		return {}
	if not _point(world.get("farm_position", [270, 310]), WORLD_SIZES.farm):
		return {}
	if world.get("weather") not in ["clear", "rain", "snow"] or not State._number(world.get("facing"), 0, 3, true):
		return {}
	if state.phase != "day" and world.location in ["field", "dock"]:
		return {}
	if not State._number(data.get("play_seconds"), 0, 10000000000) or not State._number(data.get("created_at"), 1, 99999999999, true) or not State._number(data.get("saved_at"), data.created_at, 99999999999, true):
		return {}
	if not data.get("saved_at_text") is String or data.saved_at_text.length() > 40:
		return {}
	var normalized: Dictionary = data.duplicate(true)
	normalized.state = state
	normalized.world.facing = int(world.facing)
	normalized.world.farm_position = world.get("farm_position", [270, 310]).duplicate()
	return normalized

static func _read_file(file_path: String, slot: int) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return _failure("无法读取存档文件。", "io")
	if file.get_length() > 524288:
		return _failure("存档文件过大，无法读取。")
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return _failure("存档内容损坏。")
	var envelope = json.data
	if not envelope is Dictionary or envelope.get("game") != GAME_ID:
		return _failure("存档内容损坏。")
	if envelope.get("version") != VERSION:
		return _failure("存档版本不兼容，请使用对应的游戏版本。", "version")
	if envelope.get("slot") != slot or not envelope.get("payload") is String or not envelope.get("digest") is String:
		return _failure("存档信息不完整。")
	if envelope.payload.sha256_text() != envelope.digest:
		return _failure("存档校验失败。")
	if json.parse(envelope.payload) != OK:
		return _failure("存档内容损坏。")
	var snapshot := normalize_snapshot(json.data)
	if snapshot.is_empty():
		return _failure("存档数据无效。")
	return {"ok": true, "empty": false, "data": snapshot, "recovered": false}

static func read_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return _failure("不存在这个存档栏位。")
	var file_path := slot_path(slot)
	if not FileAccess.file_exists(file_path) and not FileAccess.file_exists(file_path + ".bak"):
		return {"ok": true, "empty": true}
	var result := _read_file(file_path, slot) if FileAccess.file_exists(file_path) else _failure("主存档缺失。")
	if result.ok or result.get("code") == "version":
		return result
	if FileAccess.file_exists(file_path + ".bak"):
		var backup := _read_file(file_path + ".bak", slot)
		if backup.ok:
			backup.recovered = true
			return backup
	return result

static func delete_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return _failure("不存在这个存档栏位。")
	if slot == active_slot:
		return _failure("当前存档正在使用中。", "busy")
	var file_path := ProjectSettings.globalize_path(slot_path(slot))
	# Preflight all exact filenames; never recurse into a directory.
	for suffix in [".tmp", ".bak", ""]:
		if DirAccess.dir_exists_absolute(file_path + suffix):
			return _failure("无法删除存档文件。", "io")
	# Keep the primary until its backup and any unfinished write are removed.
	for suffix in [".tmp", ".bak", ""]:
		var target: String = file_path + suffix
		if FileAccess.file_exists(target) and DirAccess.remove_absolute(target) != OK:
			return _failure("无法删除存档文件。", "io")
	return {"ok": true}

static func write_slot(slot: int, snapshot: Dictionary) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return _failure("不存在这个存档栏位。")
	var validated := normalize_snapshot(snapshot)
	if validated.is_empty():
		return _failure("当前进度无法保存。")
	var absolute_dir := ProjectSettings.globalize_path(directory)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return _failure("无法创建存档目录，请检查磁盘权限。", "io")
	var file_path := slot_path(slot)
	var temporary := file_path + ".tmp"
	if FileAccess.file_exists(file_path) and _read_file(file_path, slot).get("code") == "version":
		return _failure("存档版本不兼容，已保留原文件。", "version")
	var payload := JSON.stringify(validated)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("写入失败，请检查磁盘空间和权限。", "io")
	file.store_string(JSON.stringify({"game": GAME_ID, "version": VERSION, "slot": slot, "payload": payload, "digest": payload.sha256_text()}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or not _read_file(temporary, slot).ok:
		return _failure("存档写入未完成，原存档已保留。", "io")
	# Never replace a good backup with a corrupt primary file.
	if FileAccess.file_exists(file_path) and _read_file(file_path, slot).ok:
		error = DirAccess.copy_absolute(ProjectSettings.globalize_path(file_path), ProjectSettings.globalize_path(file_path + ".bak"))
		if error != OK:
			return _failure("无法备份旧存档，原存档已保留。", "io")
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(file_path))
	if error != OK:
		return _failure("无法更新存档，原存档已保留。", "io")
	return {"ok": true}

static func begin_slot(slot: int) -> Dictionary:
	var result := read_slot(slot)
	if not result.ok:
		return result
	var now := int(Time.get_unix_time_from_system())
	var snapshot: Dictionary
	if result.empty:
		snapshot = {"state": State.new().to_save_data(), "world": {"location": "home", "position": [320, 405], "town_position": [408, 364], "facing": 0, "weather": "clear"}, "play_seconds": 0.0, "created_at": now, "saved_at": now, "saved_at_text": Time.get_datetime_string_from_system(false, true)}
		var written := write_slot(slot, snapshot)
		if not written.ok:
			return written
	else:
		snapshot = result.data
	active_slot = slot
	pending = snapshot.duplicate(true)
	play_seconds = float(snapshot.play_seconds)
	created_at = int(snapshot.created_at)
	return {"ok": true, "new": result.empty, "recovered": result.get("recovered", false)}

static func consume_pending() -> Dictionary:
	var snapshot := pending
	pending = {}
	return snapshot
