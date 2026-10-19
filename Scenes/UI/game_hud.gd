extends Node
## The HUD uses the same 640 x 360 pixel canvas as the world.
const UIFont = preload("res://Scenes/Gameplay/ui_font.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const Art = preload("res://Scenes/UI/hud_art.gd")
const Preferences = preload("res://Scenes/MainMenu/menu_preferences.gd")
const I18n = preload("res://Localization/localized_text.gd")
const TextMotion = preload("res://Scenes/UI/rich_text_motion.gd")
const GameMap = preload("res://Scenes/Map/game_map.gd")
const ChestUI = preload("res://Scenes/Storage/chest_ui.gd")
const Items = preload("res://Scenes/Storage/inventory_items.gd")
const Onboarding = preload("res://Scenes/Campaign/onboarding.gd")
static var HOTBAR_DIGITS: Font = preload("res://Art/Source/aseprite_source.gd").resource("res://Art/Fonts/HudDigits8/digits8.tres")
const HOTBAR_SLOTS := Items.HOTBAR_SLOTS
const HOTBAR_SHORTCUTS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const HOTBAR_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
const HOTBAR_CELL_WIDTH := 26
const HOTBAR_SIZE := Vector2(HOTBAR_SLOTS * HOTBAR_CELL_WIDTH + 8, 32)
const DIALOGUE_CHOICE_SIZE := Vector2(111,20)
const DIALOGUE_CHOICE_GAP := 3
const PLACES := {"town": "哗啦啦魔女镇", "farm": "月芽农场", "field": "微光采集地", "restaurant": "小镇餐厅", "home": "小女巫的家", "dock": "潮汐码头", "blacksmith": "余烬铁匠铺", "store": "橡果杂货店", "furniture_store": "榛木家具店"}
const ITEM_IDS := ["wand", "mushroom", "berry", "herb", "wood", "ore", "fish", "iron"]
const ITEM_NAMES := ["法杖", "蘑菇", "莓果", "香草", "木材", "矿石", "鱼", "铁锭"]
var loop
var base: Control
var layer: CanvasLayer
var clock_art: Control
var weather_art: Control
var hotbar_art: Control
var hotbar_selection: Panel
var date_label: Label
var time_label: Label
var period_label: Label
var objective_panel: Panel
var objective_title: Label
var objective_text: Label
var slot_counts: Array[Label] = []
var modal: Control
var mode := ""
var paused_before := false
var dialogue_text: RichTextLabel
var dialogue_speaker: Label
var dialogue_portrait: TextureRect
var default_speaker := ""
var default_portrait := ""
var default_portrait_region := Rect2()
var choices_root: Control
var lines: Array = []
var line_index := 0
var reveal := 0.0
var choices: Array = []
var history: Array[String] = []
var history_panel: Panel
var history_label: RichTextLabel
var bag_info: Label
var map_view
var chest_view

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	base = Control.new()
	base.name = "WalalaHUD"
	base.size = Vector2(640,360)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loop.ui.add_child(base)
	layer = CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	loop.lane.viewport.add_child(layer)
	_build_hud()
	refresh()
	Localization.language_changed.connect(_refresh_language)
	InputBindings.bindings_changed.connect(func(): _refresh_language(Localization.language))

func _refresh_language(_locale: String) -> void:
	refresh()
	match mode:
		"chest", "bag":
			chest_view.refresh_language()
		"map":
			map_view.refresh_language()
		"dialogue":
			var complete := dialogue_text.visible_characters < 0 or dialogue_text.visible_characters >= dialogue_text.get_total_character_count()
			_refresh_dialogue_speaker()
			dialogue_text.text = _dialogue_line(line_index)
			dialogue_text.visible_characters = dialogue_text.get_total_character_count() if complete else 0
			reveal = float(dialogue_text.visible_characters)
			history.clear()
			for index in range(line_index + 1): history.append(_history_line(index))
			history_label.text = tr("对话回看\n") + "\n".join(history)
			if complete: _line_complete()

func label(text: String, rect: Rect2, parent: Node, color: Color = UISkin.INK, font_size: int = 12) -> Label:
	var result := Label.new()
	result.text = text
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_theme_color_override("font_color", color)
	UIFont.apply_control(result, font_size)
	parent.add_child(result)
	return result

func panel(rect: Rect2, parent: Node, compact: bool = false) -> Panel:
	var result := Panel.new()
	result.position = rect.position
	result.size = rect.size
	result.add_theme_stylebox_override("panel", UISkin.panel_style(compact))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

func rich_label(source: String, rect: Rect2, parent: Node, color: Color = UISkin.INK, font_size: int = 12) -> RichTextLabel:
	var result := RichTextLabel.new()
	# Translate the complete source before parsing its BBCode.
	result.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	result.bbcode_enabled = true
	result.install_effect(TextMotion.new("jump"))
	result.install_effect(TextMotion.new("sway"))
	result.text = tr(source)
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.focus_mode = Control.FOCUS_NONE
	result.scroll_active = false
	result.selection_enabled = false
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	result.add_theme_color_override("default_color", color)
	UIFont.apply_rich_text(result, font_size)
	parent.add_child(result)
	return result

func button(text: String, rect: Rect2, parent: Node, callback: Callable, cue: String = "ui_click") -> Button:
	var result := Button.new()
	result.text = text
	result.position = rect.position
	result.size = rect.size
	UIFont.apply_control(result)
	UISkin.compact_button(result)
	result.focus_mode = Control.FOCUS_ALL
	loop.audio.ui_audio.bind_button(result)
	result.pressed.connect(func():
		if not cue.is_empty(): loop.audio.play_event(cue)
		callback.call())
	parent.add_child(result)
	return result

func ornament(kind: String, pos: Vector2, parent: Node, dimensions: Vector2 = Vector2(24,24)) -> Control:
	var result := Art.new()
	result.kind = kind
	result.position = pos
	result.size = dimensions
	parent.add_child(result)
	return result

func _build_hud() -> void:
	var watch := panel(Rect2(8,8,164,52),base)
	clock_art = ornament("clock",Vector2(8,10),watch,Vector2(32,32))
	date_label = label("",Rect2(48,5,74,16),watch)
	date_label.clip_text = true
	time_label = label("",Rect2(48,22,70,22),watch,UISkin.INK,18)
	period_label = label("",Rect2(116,5,36,16),watch,UISkin.MUTED_INK)
	period_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weather_art = ornament("weather",Vector2(130,23),watch)
	objective_panel = panel(Rect2(374,8,258,52),base)
	objective_panel.name = "CurrentObjective"
	objective_title = label("",Rect2(8,5,242,18),objective_panel)
	objective_text = label("",Rect2(8,27,242,18),objective_panel,UISkin.MUTED_INK)
	for part in [objective_title, objective_text]:
		part.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		part.clip_text = true
	var bar_position := Vector2((base.size.x - HOTBAR_SIZE.x) / 2, base.size.y - HOTBAR_SIZE.y)
	hotbar_art = ornament("hotbar", bar_position, base, HOTBAR_SIZE)
	hotbar_art.name = "InventoryBar"
	hotbar_art.divisions = HOTBAR_SLOTS
	hotbar_selection = Panel.new()
	hotbar_selection.name = "InventorySelection"
	hotbar_selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color(1.0, 0.88, 0.63, 0.16)
	selected_style.border_color = Color("ffe5a0")
	selected_style.set_border_width_all(1)
	selected_style.shadow_color = UISkin.INK
	selected_style.shadow_size = 1
	hotbar_selection.add_theme_stylebox_override("panel", selected_style)
	base.add_child(hotbar_selection)
	for i in range(HOTBAR_SLOTS):
		var slot := button("",Rect2(bar_position + Vector2(4 + i * HOTBAR_CELL_WIDTH, 4), Vector2(HOTBAR_CELL_WIDTH, 24)),base,open_bag,"")
		slot.name = "InventorySlot" + str(i)
		_style_hotbar_slot(slot)
		var icon := ornament("",Vector2(1,0),slot)
		icon.name = "Icon"
		var shortcut := label(HOTBAR_SHORTCUTS[i],Rect2(2,0,9,9),slot,Color("e5c28c"),8)
		shortcut.name = "Shortcut"
		shortcut.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		shortcut.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_style_hotbar_number(shortcut)
		var count := label("0",Rect2(5,11,19,13),slot,Color("fff0cf"),8)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_style_hotbar_number(count)
		slot_counts.append(count)
	# Keep gameplay controls bound to the existing state/controller.
	# Restaurant preparation owns opening; settlement owns the next-day action.
	loop.end_button.position = Vector2(270,230)
	loop.end_button.size = Vector2(100,26)
	UISkin.compact_button(loop.end_button)
	loop.ui.move_child(loop.end_button, -1)
	loop.discard_button.position = Vector2(488,275)
	loop.discard_button.size = Vector2(144,24)
	loop.summary.position = Vector2(158,112)
	loop.summary.size = Vector2(324,144)
	loop.summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _style_hotbar_number(number: Label) -> void:
	number.add_theme_font_override("font", HOTBAR_DIGITS)
	number.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	number.add_theme_constant_override("outline_size", 0)
	number.add_theme_color_override("font_shadow_color", UISkin.INK)
	number.add_theme_constant_override("shadow_offset_x", 1)
	number.add_theme_constant_override("shadow_offset_y", 1)

func _style_hotbar_slot(slot: Button) -> void:
	# The shared wooden frame owns the borders; cells only tint on interaction.
	for state in ["normal", "disabled"]:
		slot.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["hover", "hover_pressed", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.24, 0.14, 0.08, 0.3) if state == "pressed" else Color(1.0, 0.88, 0.63, 0.18)
		slot.add_theme_stylebox_override(state, style)

func item_counts() -> Array:
	var s = loop.state
	return [s.tools.wand,s.raw[0],s.raw[1],s.raw[2],s.resources.wood,s.resources.ore,s.resources.fish,s.resources.iron]

func refresh() -> void:
	var s = loop.state
	var goal := Onboarding.current(s)
	objective_panel.visible = not goal.is_empty() and s.campaign.guide_met and s.campaign.introduced and mode.is_empty() and s.phase != "result" and not (loop.campaign_controller != null and loop.campaign_controller.opening_active())
	if objective_panel.visible:
		objective_title.text = I18n.format("%s · %d/%d",[goal.objective,goal.progress,goal.goal])
		objective_text.text = tr(goal.place)
	var minutes: int = s.get_clock_minutes()
	var night_time: bool = s.get_time_of_day() == "night"
	date_label.text = I18n.format("第%d天·周%s", [s.day,["一","二","三","四","五","六","日"][(s.day-1)%7]])
	time_label.text = s.get_time_text()
	period_label.text = s.get_time_of_day_name()
	time_label.tooltip_text = "时钟每半小时更新 · 早上 06–09 · 白天 09–17 · 傍晚 17–20 · 夜晚 20–06"
	clock_art.progress = float(minutes%720)/720.0
	clock_art.night = night_time
	clock_art.queue_redraw()
	weather_art.weather = loop.lane.weather.get_weather()
	weather_art.night = night_time
	weather_art.queue_redraw()
	Items.ensure_bag(s)
	for i in range(HOTBAR_SLOTS):
		var slot: Dictionary = s.bag_slots[i]
		var id: String = slot.get("id", "")
		var count: int = slot.get("count", 0)
		slot_counts[i].text = str(count) if count > 1 else ""
		var cell := slot_counts[i].get_parent()
		cell.tooltip_text = tr("空格子") if id.is_empty() else tr(Items.NAMES[id])
		if id == "wand": cell.tooltip_text = tr(Art.WandVisuals.NAMES[s.wand_mode])
		cell.get_node("Icon").kind = id
		cell.get_node("Icon").wand_mode = s.wand_mode
		cell.get_node("Icon").queue_redraw()
	loop.header.hide()
	loop.inventory.hide()
	loop.backgrounds[0].hide()
	hotbar_art.visible = s.phase != "result" and bool(Preferences.value("game", "show_hotbar", true))
	for count in slot_counts:
		count.get_parent().visible = hotbar_art.visible
	_refresh_hotbar_selection()
	var preparation: bool = loop.location == "restaurant" and s.phase == "day"
	loop.end_button.visible = s.phase == "result" or preparation
	loop.end_button.position = Vector2(450, 250) if preparation else Vector2(270, 230)
	loop.end_button.size = Vector2(180, 26) if preparation else Vector2(100, 26)

func _refresh_hotbar_selection() -> void:
	var index: int = loop.state.selected_hotbar_slot
	hotbar_selection.visible = hotbar_art.visible and index >= 0 and index < slot_counts.size()
	if not hotbar_selection.visible: return
	var cell: Control = slot_counts[index].get_parent()
	hotbar_selection.position = cell.position
	hotbar_selection.size = cell.size

func _select_hotbar_slot(index: int) -> void:
	if not loop.state.select_hotbar_slot(index): return
	loop.harvest.cancel()
	loop.audio.play_event("ui_click")
	_refresh_hotbar_selection()

func _begin_modal(new_mode: String) -> bool:
	if loop.campaign_controller != null and loop.campaign_controller.opening_active(): return false
	if loop.builder != null and loop.builder.active(): return false
	if loop.save_menu.open or loop.save_menu.leaving:
		return false
	if is_instance_valid(modal):
		close_modal()
	loop.harvest.cancel()
	loop.audio.reset_footsteps()
	loop.audio.panel.hide()
	loop.audio.credits.hide()
	if loop.location in ["blacksmith","store"]:
		loop.area.service_panel.hide()
	paused_before = get_tree().paused
	get_tree().paused = true
	mode = new_mode
	objective_panel.hide()
	loop.audio.play_event("ui_book_open" if new_mode == "journal" else "ui_open")
	modal = ColorRect.new()
	modal.name = "HUDModal"
	modal.size = Vector2(640,360)
	modal.color = Color(0.12,0.08,0.15,0.66)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(modal)
	return true

func close_modal() -> void:
	if not is_instance_valid(modal):
		return
	if mode in ["bag", "chest"] and is_instance_valid(chest_view): chest_view.finish()
	loop.audio.play_event("ui_book_close" if mode == "journal" else "ui_close")
	modal.hide()
	modal.queue_free()
	modal = null
	mode = ""
	get_tree().paused = paused_before
	refresh()

func open_journal() -> void:
	if loop.campaign_controller != null:
		loop.campaign_controller.open("故事")

func open_bag() -> void:
	if not _begin_modal("bag"):
		return
	chest_view = ChestUI.new()
	chest_view.hud = self
	modal.add_child(chest_view)
	bag_info = chest_view.bag_heading

func open_chest(id: int) -> void:
	if loop.location not in ["home", "farm"] or loop.state.phase == "result" or not mode.is_empty(): return
	var chest: Dictionary = loop.area.nearest_chest()
	if chest.is_empty() or chest.id != id or not _begin_modal("chest"): return
	chest_view = ChestUI.new()
	chest_view.hud = self
	chest_view.chest_id = id
	modal.add_child(chest_view)

func open_equipment_upgrades(provider: Node, equipment_id: String = "wand") -> void:
	if equipment_id not in ["wand", "bag"] or not is_instance_valid(provider): return
	if loop.location != "blacksmith" or provider != loop.area or not loop.near(provider.stations.service) or loop.state.phase != "day": return
	if not _begin_modal("upgrades"): return
	var view := preload("res://Scenes/Equipment/upgrade_panel.gd").new()
	view.loop = loop
	view.provider = weakref(provider)
	view.selected = equipment_id
	modal.add_child(view)

func open_house_upgrades(provider: Node) -> void:
	if loop.location != "furniture_store" or provider != loop.area or not loop.near(provider.stations.service) or loop.state.phase != "day": return
	if not _begin_modal("housing"): return
	var view := preload("res://Scenes/Building/house_upgrade_panel.gd").new()
	view.loop = loop
	view.provider = weakref(provider)
	modal.add_child(view)

func open_map() -> void:
	if loop.state.phase == "result" or not _begin_modal("map"):
		return
	map_view = GameMap.new()
	map_view.hud = self
	modal.add_child(map_view)

func open_guide() -> void:
	if loop.campaign_controller != null: loop.campaign_controller.show_guide()

func start_dialogue(speaker: String, portrait_path: String, dialogue_lines: Array, dialogue_choices: Array = [], portrait_region: Rect2 = Rect2(0,0,32,48)) -> void:
	if dialogue_lines.is_empty() or not _begin_modal("dialogue"):
		return
	lines = dialogue_lines.duplicate()
	choices = dialogue_choices.duplicate()
	line_index = 0
	history.clear()
	default_speaker = speaker
	default_portrait = portrait_path
	default_portrait_region = portrait_region
	var dialogue_layout := Control.new()
	dialogue_layout.name = "DialogueLayout"
	dialogue_layout.size = Vector2(640,310)
	# Align the portrait and text frames with the bottom edge of the item bar.
	dialogue_layout.position.y = hotbar_art.get_rect().end.y - dialogue_layout.size.y
	dialogue_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(dialogue_layout)
	# Portrait stamp and name plate echo the journal's wood and parchment.
	var portrait := panel(Rect2(56,206,88,104),dialogue_layout)
	var stamp := TextureRect.new()
	stamp.name = "DialoguePortrait"
	var texture: Texture2D = load(portrait_path)
	if portrait_region.has_area():
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = portrait_region
		stamp.texture = atlas
	else:
		stamp.texture = texture
	stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stamp.position = Vector2(20,8)
	stamp.size = Vector2(48,72)
	stamp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(stamp)
	dialogue_portrait = stamp
	label("小镇来信",Rect2(8,82,72,16),portrait,UISkin.MUTED_INK)
	var name_plate := button("",Rect2(152,200,110,26),dialogue_layout,func(): pass)
	name_plate.name = "DialogueNamePlate"
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var speaker_label := label(speaker,Rect2(4,0,102,26),name_plate,name_plate.get_theme_color("font_color"))
	speaker_label.name = "DialogueSpeaker"
	speaker_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	dialogue_speaker = speaker_label
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speaker_label.add_theme_constant_override("line_spacing", 0)
	var speaker_font := FontVariation.new()
	speaker_font.base_font = UIFont.get_font()
	speaker_font.spacing_top = -2
	speaker_font.spacing_bottom = -2
	speaker_label.add_theme_font_override("font", speaker_font)
	speaker_label.size = Vector2(102,26)
	var text_panel := panel(Rect2(152,226,432,84),dialogue_layout)
	dialogue_text = rich_label("",Rect2(14,10,404,64),text_panel)
	dialogue_text.name = "DialogueText"
	choices_root = Control.new()
	choices_root.name = "DialogueChoices"
	# Keep choices just above the body and inside its right frame; extra rows grow upward.
	var choices_height := maxi(0, choices.size() * int(DIALOGUE_CHOICE_SIZE.y + DIALOGUE_CHOICE_GAP) - DIALOGUE_CHOICE_GAP)
	choices_root.position = Vector2(text_panel.get_rect().end.x - 4 - DIALOGUE_CHOICE_SIZE.x, text_panel.position.y - 2 - choices_height)
	choices_root.size = Vector2(DIALOGUE_CHOICE_SIZE.x,choices_height)
	dialogue_layout.add_child(choices_root)
	history_panel = panel(Rect2(152,72,432,120),dialogue_layout)
	history_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	history_label = rich_label("",Rect2(14,10,404,100),history_panel)
	history_label.name = "DialogueHistory"
	history_label.mouse_filter = Control.MOUSE_FILTER_STOP
	history_label.scroll_active = true
	history_panel.hide()
	_show_line()

func _dialogue_line(index: int) -> String:
	var line: Variant = lines[index]
	if line is Dictionary: return I18n.format(line.source, line.args)
	return tr(str(line))

func _history_line(index: int) -> String:
	var line: Variant = lines[index]
	if line is Dictionary and line.has("speaker"):
		var speaker: String = tr(line.speaker) if line.get("translate_speaker", true) else line.speaker
		return speaker + "：" + _dialogue_line(index)
	return _dialogue_line(index)

func _refresh_dialogue_speaker() -> void:
	var line: Variant = lines[line_index]
	var beat: Dictionary = line if line is Dictionary else {}
	var speaker: String = beat.get("speaker", default_speaker)
	dialogue_speaker.text = tr(speaker) if beat.get("translate_speaker", true) else speaker
	var portrait_path: String = beat.get("portrait", default_portrait)
	var region: Rect2 = beat.get("portrait_region", default_portrait_region)
	var texture: Texture2D = load(portrait_path)
	if region.has_area():
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		dialogue_portrait.texture = atlas
	else:
		dialogue_portrait.texture = texture

func _show_line() -> void:
	_refresh_dialogue_speaker()
	dialogue_text.text = _dialogue_line(line_index)
	dialogue_text.visible_characters = 0
	reveal = 0.0
	history.append(_history_line(line_index))
	history_label.text = tr("对话回看\n") + "\n".join(history)
	choices_root.hide()
	if dialogue_text.get_total_character_count() == 0: _line_complete()

func advance_dialogue() -> void:
	if history_panel.visible:
		history_panel.hide()
		loop.audio.play_event("ui_page")
		return
	var length := dialogue_text.get_total_character_count()
	if dialogue_text.visible_characters >= 0 and dialogue_text.visible_characters < length:
		loop.audio.play_event("ui_page")
		dialogue_text.visible_characters = length
		reveal = float(length)
		_line_complete()
	elif line_index + 1 < lines.size():
		loop.audio.play_event("ui_page")
		line_index += 1
		_show_line()
	elif choices.is_empty():
		close_modal()

func _line_complete() -> void:
	if line_index + 1 == lines.size() and not choices.is_empty() and choices_root.get_child_count() == 0:
		for i in range(choices.size()):
			var choice: Dictionary = choices[i]
			var entry := button(choice.text,Rect2(Vector2(0,i*(DIALOGUE_CHOICE_SIZE.y + DIALOGUE_CHOICE_GAP)),DIALOGUE_CHOICE_SIZE),choices_root,func(): choice.action.call(),"")
			entry.clip_text = true
			entry.size = DIALOGUE_CHOICE_SIZE
			entry.name = "DialogueChoice" + str(i)
		choices_root.show()
		if ControllerInput.using_controller: choices_root.get_child(0).grab_focus()

func toggle_history() -> void:
	if mode == "dialogue":
		history_panel.visible = not history_panel.visible
		loop.audio.play_event("ui_page")

func _process(delta: float) -> void:
	if mode != "dialogue": return
	var length := dialogue_text.get_total_character_count()
	if dialogue_text.visible_characters >= 0 and dialogue_text.visible_characters < length:
		var speed := Preferences.dialogue_speed()
		reveal = float(length) if speed == 0.0 else reveal + delta * speed
		dialogue_text.visible_characters = mini(length,floori(reveal))
		if dialogue_text.visible_characters == length:
			_line_complete()

func _input(event: InputEvent) -> void:
	if SceneTransition.active: return
	if loop.campaign_controller != null and loop.campaign_controller.opening_active(): return
	loop.audio.ui_audio.navigation_input(event)
	if InputBindings.capture_active: return
	if loop.builder != null and loop.builder.active(): return
	if loop.save_menu.open or loop.save_menu.leaving:
		return
	if event is InputEventMouseButton:
		if not event.pressed or event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: return
		if not mode.is_empty() or get_tree().paused or loop.state.phase == "result": return
		if event.alt_pressed or event.ctrl_pressed or event.meta_pressed or event.shift_pressed: return
		var direction := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		_select_hotbar_slot(posmod(loop.state.selected_hotbar_slot + direction, HOTBAR_SLOTS))
		get_viewport().set_input_as_handled()
		return
	if not InputBindings.is_action_press(event): return
	if event is InputEventKey and mode.is_empty() and not get_tree().paused and loop.state.phase != "result":
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var index := HOTBAR_KEYS.find(code)
		if index >= 0 and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed and not event.shift_pressed and not InputBindings.is_bound_event(event):
			_select_hotbar_slot(index)
			get_viewport().set_input_as_handled()
			return
	# Controller confirmation belongs to the focused inventory cell or choice.
	if mode in ["bag", "chest"] and event.is_action_pressed("ui_accept"): return
	if mode == "chest" and ((event is InputEventKey and event.is_action_pressed("interact")) or event.is_action_pressed("bag")):
		close_modal()
	elif mode == "dialogue":
		if event.is_action_pressed("interact") or event.is_action_pressed("dialogue_next"):
			if event.is_action_pressed("ui_accept") and choices_root.visible and not history_panel.visible:
				return
			advance_dialogue()
		elif event.is_action_pressed("history"):
			toggle_history()
		elif event.is_action_pressed("ui_cancel"):
			close_modal()
		elif (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")) and choices_root.visible:
			var focused: Control = loop.lane.viewport.gui_get_focus_owner()
			var entries := choices_root.get_children()
			var index := entries.find(focused)
			entries[posmod(index + (1 if event.is_action_pressed("ui_down") else -1),entries.size())].grab_focus()
		else:
			return
	elif event.is_action_pressed("journal") or event.is_action_pressed("bag") or event.is_action_pressed("guide") or event.is_action_pressed("map"):
		if (event.is_action_pressed("journal") and mode == "campaign") or (event.is_action_pressed("bag") and mode == "bag") or (event.is_action_pressed("map") and mode == "map"):
			close_modal()
		elif mode.is_empty():
			if event.is_action_pressed("journal"): open_journal()
			elif event.is_action_pressed("bag"): open_bag()
			elif event.is_action_pressed("map"): open_map()
			else: open_guide()
		else:
			return
	elif event.is_action_pressed("ui_cancel") and not mode.is_empty():
		close_modal()
	else:
		return
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if not mode.is_empty():
		get_tree().paused = paused_before
	if is_instance_valid(layer):
		layer.queue_free()
