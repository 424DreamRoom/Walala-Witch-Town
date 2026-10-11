extends Node
## Native Godot translations, registered from an export-safe generated resource.
signal language_changed(locale: String)
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const Catalog = preload("res://Localization/catalog.gd")
const LOCALES := ["zh_CN", "en", "ja", "zh_TW"]
const LANGUAGE_NAMES := ["简体中文", "English", "日本語", "繁體中文"]
var language := "zh_CN"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for locale in LOCALES:
		var translation := Translation.new()
		translation.locale = locale
		# The source Chinese is also the default translation.
		var column: int = {"zh_CN": 0, "en": 1, "ja": 2, "zh_TW": 3}[locale]
		for row in Catalog.ROWS:
			translation.add_message(row[0], row[column])
		TranslationServer.add_translation(translation)
	apply_saved_language()

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
