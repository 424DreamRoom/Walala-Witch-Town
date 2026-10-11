extends Control
const House = preload("res://Scenes/Building/house_catalog.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const I18n = preload("res://Localization/localized_text.gd")
var loop
var provider: WeakRef
var detail: Control
var feedback := ""

func _ready() -> void:
	name = "HouseUpgrades"
	position = Vector2(40, 24)
	size = Vector2(560, 312)
	var paper: Panel = loop.hud.panel(Rect2(Vector2.ZERO, size), self)
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	loop.hud.label("榛木家具店", Rect2(20, 12, 520, 32), self, UISkin.INK, 24)
	loop.hud.label("房屋扩建", Rect2(20, 48, 520, 24), self, UISkin.MUTED_INK, 18)
	detail = Control.new()
	detail.position = Vector2(20, 80)
	add_child(detail)
	var back: Button = loop.hud.button("返回", Rect2(428, 278, 112, 26), self, loop.hud.close_modal, "")
	back.name = "Back"
	refresh()
	if not detail.get_node("Expand").disabled: detail.get_node("Expand").grab_focus()
	else: back.grab_focus()
	Localization.language_changed.connect(func(_locale: String): refresh())

func refresh() -> void:
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	var hud = loop.hud
	var state = loop.state
	var rank: int = state.furniture.house_level
	var maximum := rank >= House.MAX_LEVEL
	var floor: Rect2 = House.FLOORS[rank]
	hud.label(tr(House.TITLES[rank]), Rect2(0, 0, 252, 26), detail, UISkin.INK, 18)
	hud.label(I18n.format("房屋面积：%d×%d", [int(floor.size.x / 16), int(floor.size.y / 16)]), Rect2(0, 32, 252, 22), detail)
	hud.label(I18n.format("已摆放 %d 件家具", [state.furniture.placed.size()]), Rect2(0, 60, 252, 22), detail)
	if not maximum:
		var next: Rect2 = House.FLOORS[rank + 1]
		hud.label(tr(House.TITLES[rank + 1]), Rect2(272, 0, 248, 26), detail, UISkin.INK, 18)
		hud.label(I18n.format("房屋面积：%d×%d", [int(next.size.x / 16), int(next.size.y / 16)]), Rect2(272, 32, 248, 22), detail)
		var price: Dictionary = House.COSTS[rank]
		hud.label(I18n.format("金币 %d / %d", [state.coins, price.coins]), Rect2(272, 66, 248, 22), detail)
		hud.label(I18n.format("木材 %d / %d", [state.resources.wood, price.wood]), Rect2(272, 92, 248, 22), detail)
		hud.label(I18n.format("铁锭 %d / %d", [state.resources.iron, price.iron]), Rect2(272, 118, 248, 22), detail)
	var expand: Button = hud.button("已达最高等级" if maximum else "扩建", Rect2(272, 152, 248, 26), detail, purchase, "")
	expand.name = "Expand"
	expand.disabled = not _available() or not state.can_expand_house()
	hud.label(tr(feedback), Rect2(0, 188, 520, 24), detail, UISkin.MUTED_INK)

func _available() -> bool:
	var shop = provider.get_ref() if provider != null else null
	return is_instance_valid(shop) and shop.is_inside_tree() and loop.area == shop and loop.location == "furniture_store" and loop.near(shop.stations.service) and loop.state.phase == "day" and loop.hud.mode == "housing" and is_instance_valid(loop.hud.modal) and loop.hud.modal.is_ancestor_of(self) and not loop.save_menu.open

func purchase() -> void:
	if not _available(): return
	if loop.state.expand_house():
		feedback = "房屋扩建完成。"
		loop.audio.play_event("coins")
		loop._autosave()
	else:
		feedback = loop.state.message
		loop.audio.play_event("ui_error")
	refresh()
	var expand: Button = detail.get_node("Expand")
	if not expand.disabled: expand.grab_focus()
	else: get_node("Back").grab_focus()
