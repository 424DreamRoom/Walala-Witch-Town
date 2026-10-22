extends RefCounted
## Raw, UTF-8 CSV; named columns may be reordered in the workbook.
const HEADERS := ["LanguageKey", "Simplified Chinese", "English", "Japanese", "Traditional Chinese"]
const DIRECTORY := "res://Excel/Localization"

static func csv_paths(directory: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension().to_lower() == "csv":
			paths.append(directory.path_join(filename))
	for folder in DirAccess.get_directories_at(directory):
		paths.append_array(csv_paths(directory.path_join(folder)))
	paths.sort()
	return paths

static func read_catalog(directory: String = DIRECTORY) -> Dictionary:
	var paths := csv_paths(directory)
	if paths.is_empty():
		return {"error": "No localization CSV found in " + directory}
	var rows: Array = []
	var keys := {}
	var aliases := {}
	for path in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"error": "Cannot open localization CSV: " + path}
		var headers := file.get_csv_line()
		var order: Array[int] = []
		for index in range(headers.size()):
			headers[index] = headers[index].trim_prefix("\ufeff").strip_edges()
		for header in HEADERS:
			if headers.count(header) != 1:
				return {"error": "Missing or duplicate column " + header + " in " + path}
			order.append(headers.find(header))
		if headers.size() != HEADERS.size():
			return {"error": "Unexpected localization columns in " + path}
		var number := 1
		while not file.eof_reached():
			var fields := file.get_csv_line()
			number += 1
			if fields.size() == 1 and fields[0].strip_edges().is_empty():
				continue
			if fields.size() != HEADERS.size():
				return {"error": "Invalid localization row %d in %s" % [number, path]}
			var row: Array[String] = []
			for column in order:
				if fields[column].strip_edges().is_empty():
					return {"error": "Incomplete localization row %d in %s" % [number, path]}
				row.append(fields[column])
			if keys.has(row[0]):
				return {"error": "Duplicate LanguageKey: " + row[0]}
			keys[row[0]] = true
			for alias in [row[0], row[1]]:
				if aliases.has(alias) and aliases[alias] != row[0]:
					return {"error": "Conflicting localization alias: " + alias}
				aliases[alias] = row[0]
			rows.append(row)
	if rows.is_empty():
		return {"error": "Localization CSV contains no entries"}
	return {"error": "", "rows": rows, "files": paths}
