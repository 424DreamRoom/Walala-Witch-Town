extends Control
## A paused atlas; inspecting a destination never changes gameplay state.
const Canvas = preload("res://Scenes/Map/map_canvas.gd")
const I18n = preload("res://Localization/localized_text.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
var hud
var canvas
var title: Label
var location_label: Label
var region_buttons := {}
var selected := "world"

func _ready() -> void:
	name = "GameMap"
	position = Vector2(20, 14)
	size = Vector2(600, 332)
	var paper: Panel = hud.panel(Rect2(Vector2.ZERO, size), self)
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	title = hud.label("", Rect2(16, 10, 508, 25), self, UISkin.INK, 18)
	location_label = hud.label("", Rect2(16, 39, 378, 20), self, UISkin.MUTED_INK)
	var close: Button = hud.button("×", Rect2(550, 10, 32, 25), self, hud.close_modal, "")
	close.name = "CloseMap"
	canvas = Canvas.new()
	canvas.name = "MapCanvas"
	canvas.loop = hud.loop
	canvas.position = Vector2(16, 66)
	canvas.size = Vector2(392, 230)
	canvas.region_selected.connect(show_region)
	add_child(canvas)
	var keys: Array = ["world"]
	keys.append_array(Canvas.PLACES.keys())
	for index in range(keys.size()):
		var key: String = keys[index]
		var text: String = "全镇总览" if key == "world" else Canvas.PLACES[key]
		var entry: Button = hud.button(text, Rect2(424, 66 + index * 25, 160, 23), self, show_region.bind(key), "")
		entry.name = "Region_" + key
		entry.toggle_mode = true
		region_buttons[key] = entry
	refresh_language()
	show_region("world", false)
	region_buttons.world.grab_focus()

func refresh_language() -> void:
	location_label.text = I18n.format("所在区域：%s", [Canvas.PLACES[hud.loop.location]])
	title.text = tr("全镇总览" if selected == "world" else Canvas.PLACES[selected])
	for key in region_buttons:
		region_buttons[key].text = tr("全镇总览" if key == "world" else Canvas.PLACES[key])
	if hud.loop.state.campaign.region != "field":
		var name: String = hud.loop.state.Campaign.entry(hud.loop.state.Content.DATA.regions,hud.loop.state.campaign.region).name
		region_buttons.field.text = tr(name)
		if hud.loop.location == "field": location_label.text = I18n.format("所在区域：%s",[name])
		if selected == "field": title.text = tr(name)

func show_region(region: String, play_sound: bool = true) -> void:
	if region != "world" and region not in Canvas.PLACES: return
	selected = region
	canvas.view = region
	for key in region_buttons: region_buttons[key].set_pressed_no_signal(key == region)
	refresh_language()
	canvas.queue_redraw()
	if play_sound: hud.loop.audio.play_event("ui_page")
