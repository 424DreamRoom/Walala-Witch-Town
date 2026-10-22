extends SceneTree
## Exercises the actual CSV reader and TranslationServer in isolated files.
const CsvCatalog = preload("res://Localization/csv_catalog.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
var failures := 0
var directory := "user://csv_catalog_%d" % OS.get_process_id()

func _initialize() -> void:
	Preferences.file_path = directory + "/preferences.cfg"
	run.call_deferred()

func check(title: String, passed: bool) -> void:
	print("CSV CATALOG TEST ", title, ": ", "PASS" if passed else "FAIL")
	if not passed:
		failures += 1

func write_csv(filename: String, rows: Array) -> void:
	var file := FileAccess.open(directory.path_join(filename), FileAccess.WRITE)
	for row in rows:
		file.store_csv_line(PackedStringArray(row))
	file.close()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var service = root.get_node("Localization")
	check("shipped CSV is loaded", not service.catalog_rows.is_empty() and not service.catalog_files.is_empty())
	var expected := "[b]译文，\"引号\"[/b]\n第二行 %s"
	# Deliberately change the column order and include a UTF-8 BOM.
	var headers := ["\ufeffEnglish", "LanguageKey", "Traditional Chinese", "Japanese", "Simplified Chinese"]
	var row := ["[b]English, \"quote\"[/b]\nSecond line %s", "CSV_VERIFY_KEY", "[b]譯文[/b]\n第二行 %s", "[b]日本語[/b]\n二行目 %s", expected]
	write_csv("table.csv", [headers, row])
	var catalog := CsvCatalog.read_catalog(directory)
	check("BOM and reordered named columns", catalog.error.is_empty() and catalog.rows[0][0] == "CSV_VERIFY_KEY")
	check("CSV quotes commas BBCode and embedded newline survive", catalog.error.is_empty() and catalog.rows[0][1] == expected)
	var notifications := [0]
	var listener := func(_locale): notifications[0] += 1
	service.language_changed.connect(listener)
	check("reload registers CSV instead of generated script", service.reload_catalog(directory))
	for index in range(service.LOCALES.size()):
		service.set_language(service.LOCALES[index], false)
		check("symbolic LanguageKey resolves " + service.language, String(TranslationServer.translate("CSV_VERIFY_KEY")) == catalog.rows[0][index + 1])
		check("Chinese source alias resolves " + service.language, String(TranslationServer.translate(expected)) == catalog.rows[0][index + 1])
	row[0] = "Changed in CSV %s"
	write_csv("table.csv", [headers, row])
	service.set_language("en", false)
	var before: int = notifications[0]
	check("CSV edit refreshes the same language", service.reload_catalog(directory) and String(TranslationServer.translate("CSV_VERIFY_KEY")) == row[0] and notifications[0] > before)
	write_csv("duplicate.csv", [headers, row])
	check("duplicate keys across tables rejected", not CsvCatalog.read_catalog(directory).error.is_empty())
	check("invalid reload preserves previous valid translation", not service.reload_catalog(directory) and String(TranslationServer.translate("CSV_VERIFY_KEY")) == row[0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join("duplicate.csv")))
	var incomplete := row.duplicate()
	incomplete[3] = ""
	write_csv("table.csv", [headers, incomplete])
	check("empty language cells rejected", not CsvCatalog.read_catalog(directory).error.is_empty())
	write_csv("table.csv", [["LanguageKey", "English"], ["KEY", "Text"]])
	check("missing columns rejected", not CsvCatalog.read_catalog(directory).error.is_empty())
	service.language_changed.disconnect(listener)
	check("restore shipped CSV", service.reload_catalog())
	service.set_language("zh_CN", false)
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("CSV CATALOG VERIFY END failures=", failures)
	quit(failures)
