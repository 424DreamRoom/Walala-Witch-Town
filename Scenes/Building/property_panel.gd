extends Control
const House = preload("res://Scenes/Building/house_catalog.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const I18n = preload("res://Localization/localized_text.gd")
var loop
var provider: WeakRef
var feedback := ""
var body: Control

func _ready() -> void:
	name = "PropertyOffice"
	position = Vector2(32, 26)
	size = Vector2(576, 308)
	loop.hud.panel(Rect2(Vector2.ZERO, size), self).mouse_filter = Control.MOUSE_FILTER_STOP
	loop.hud.label("贝阿特丽丝 · 房地产魔女", Rect2(18, 12, 540, 30), self, UISkin.INK, 22)
	body = Control.new()
	body.position = Vector2(18, 54)
	add_child(body)
	var back: Button = loop.hud.button("返回", Rect2(446, 272, 112, 26), self, loop.hud.close_modal)
	back.name = "Back"
	refresh()
	if not body.get_node("Rent").disabled: body.get_node("Rent").grab_focus()
	else: body.get_node("House").grab_focus()
	Localization.language_changed.connect(func(_locale: String): refresh())

func available() -> bool:
	var service = provider.get_ref() if provider != null else null
	return is_instance_valid(service) and service.available() and loop.hud.mode == "property" and is_instance_valid(loop.hud.modal) and loop.hud.modal.is_ancestor_of(self)

func refresh() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var hud = loop.hud
	var state = loop.state
	hud.label("小镇餐厅", Rect2(0, 0, 260, 26), body, UISkin.INK, 20)
	hud.label("住宅扩建", Rect2(284, 0, 256, 26), body, UISkin.INK, 20)
	hud.label("租约已生效" if state.restaurant_leased else "尚未承租", Rect2(0, 34, 260, 22), body)
	hud.label(I18n.format("长期租金：%d金", [state.RESTAURANT_RENT]), Rect2(0, 62, 260, 22), body)
	hud.label("一次付费 · 长期使用", Rect2(0, 90, 260, 22), body, UISkin.MUTED_INK)
	hud.label(tr(House.TITLES[state.furniture.house_level]), Rect2(284, 34, 256, 22), body)
	var floor: Rect2 = House.floor_for(state.furniture)
	hud.label(I18n.format("房屋面积：%d×%d", [int(floor.size.x / 16), int(floor.size.y / 16)]), Rect2(284, 62, 256, 22), body)
	var footprint: Rect2 = House.outdoor_footprint(state.furniture)
	hud.label(I18n.format("房屋占地：%d×%d", [int(footprint.size.x / 16), int(footprint.size.y / 16)]), Rect2(284, 90, 256, 22), body)
	var rent: Button = hud.button("已承租" if state.restaurant_leased else "承租餐厅", Rect2(0, 132, 256, 28), body, rent_restaurant)
	rent.name = "Rent"
	rent.disabled = not available() or not state.can_rent_restaurant()
	var house: Button = hud.button("住宅扩建", Rect2(284, 132, 256, 28), body, open_house)
	house.name = "House"
	house.disabled = not available()
	hud.label(I18n.format("金币 %d", [state.coins]), Rect2(0, 174, 540, 22), body)
	hud.label(tr(feedback), Rect2(0, 200, 540, 22), body, UISkin.MUTED_INK)

func rent_restaurant() -> void:
	if not available(): return
	if loop.state.rent_restaurant():
		loop.audio.play_event("coins")
		loop._autosave()
	else: loop.audio.play_event("ui_error")
	feedback = loop.state.message
	refresh()
	get_node("Back").grab_focus()

func open_house() -> void:
	if available(): loop.hud.open_house_upgrades(provider.get_ref())
