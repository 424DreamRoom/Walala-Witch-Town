extends Node
## Native Godot translations, populated directly from Excel's CSV exports.
signal language_changed(locale: String)
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const CsvCatalog = preload("res://Localization/csv_catalog.gd")
const LOCALES := ["zh_CN", "en", "ja", "zh_TW"]
const LANGUAGE_NAMES := ["简体中文", "English", "日本語", "繁體中文"]
var language := "zh_CN"
var catalog_rows: Array = []
var catalog_files := PackedStringArray()
var _translations: Array[Translation] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not reload_catalog():
		push_error("Localization CSV could not be loaded.")
	apply_saved_language()

func reload_catalog(directory: String = CsvCatalog.DIRECTORY) -> bool:
	var catalog := CsvCatalog.read_catalog(directory)
	if not catalog.error.is_empty():
		push_warning(catalog.error)
		return false
	var translations: Array[Translation] = []
	for index in range(LOCALES.size()):
		var translation := Translation.new()
		translation.locale = LOCALES[index]
		for row in catalog.rows:
			translation.add_message(row[0], row[index + 1])
			if row[0] != row[1]:
				translation.add_message(row[1], row[index + 1])
		translations.append(translation)
	# A malformed update leaves the previous valid translations registered.
	for translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations = translations
	catalog_rows = catalog.rows
	catalog_files = catalog.files
	for translation in _translations:
		TranslationServer.add_translation(translation)
	get_tree().root.title = TranslationServer.translate("哗啦啦魔女镇")
	language_changed.emit(language)
	return true

func apply_saved_language() -> void:
	set_language(str(Preferences.value("game", "language", "zh_CN")), false)

func set_language(locale: String, persist: bool = true) -> void:
	if locale not in LOCALES:
		locale = "zh_CN"
	if persist:
		Preferences.set_value("game", "language", locale)
	var changed := language != locale or TranslationServer.get_locale() != locale
	language = locale
	TranslationServer.set_locale(locale)
	get_tree().root.title = TranslationServer.translate("哗啦啦魔女镇")
	if changed:
		language_changed.emit(locale)
