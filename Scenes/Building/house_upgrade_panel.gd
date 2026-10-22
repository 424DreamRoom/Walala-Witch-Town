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
	loop.hud.label("贝阿特丽丝 · 房地产魔女" if provider.get_ref() == loop.property_service else "榛木家具店", Rect2(20, 12, 520, 32), self, UISkin.INK, 24)
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
	var plan := House.upgrade_for(state.furniture)
	var maximum := plan.is_empty()
	var floor: Rect2 = House.FLOORS[rank]
	hud.label(tr(House.TITLES[rank]), Rect2(0, 0, 252, 26), detail, UISkin.INK, 18)
	hud.label(I18n.format("房屋面积：%d×%d", [int(floor.size.x / 16), int(floor.size.y / 16)]), Rect2(0, 32, 252, 22), detail)
	hud.label(I18n.format("已摆放 %d 件家具", [state.furniture.placed.size()]), Rect2(0, 60, 252, 22), detail)
	var footprint := House.outdoor_footprint(state.furniture)
	hud.label(I18n.format("房屋占地：%d×%d", [int(footprint.size.x / 16), int(footprint.size.y / 16)]), Rect2(0, 92, 252, 22), detail)
	if not maximum:
		var next: Rect2 = House.FLOORS[plan.house_level]
		hud.label(tr(House.TITLES[plan.house_level]), Rect2(272, 0, 248, 26), detail, UISkin.INK, 18)
		hud.label(I18n.format("房屋面积：%d×%d", [int(next.size.x / 16), int(next.size.y / 16)]), Rect2(272, 32, 248, 22), detail)
		var price: Dictionary = plan.price
		# Resource requirements use the same icon-plus-value language as the shop
		# cards, so the expansion cost can be scanned without reading a text list.
		var costs := [["coin", "金币 %d / %d", [state.coins, price.coins]], ["wood", "木材 %d / %d", [state.resources.wood, price.wood]], ["iron", "铁锭 %d / %d", [state.resources.iron, price.iron]]]
		for index in range(costs.size()):
			hud.ornament(costs[index][0], Vector2(272, 86 + index * 24), detail, Vector2(18, 18))
			hud.label(I18n.format(costs[index][1], costs[index][2]), Rect2(294, 84 + index * 24, 226, 22), detail)
		var dimensions: Vector2 = House.OUTDOOR_SIZES[plan.exterior_level]
		hud.label(I18n.format("房屋占地：%d×%d", [int(dimensions.x / 16), int(dimensions.y / 16)]), Rect2(272, 60, 248, 22), detail)
		if not state.house_expansion_clear(): feedback = "扩建用地被占用。"
		elif feedback == "扩建用地被占用。": feedback = ""
	var expand: Button = hud.button("已达最高等级" if maximum else "扩建", Rect2(272, 160, 248, 26), detail, purchase, "")
	expand.name = "Expand"
	expand.disabled = not _available() or not state.can_expand_house()
	hud.label(tr(feedback), Rect2(0, 188, 520, 24), detail, UISkin.MUTED_INK)

func _available() -> bool:
	var shop = provider.get_ref() if provider != null else null
	if not is_instance_valid(shop) or not shop.is_inside_tree(): return false
	var at_provider: bool = shop == loop.property_service and shop.available()
	if not at_provider: at_provider = loop.area == shop and loop.location == "furniture_store" and loop.near(shop.stations.service) and loop.state.phase == "day"
	return at_provider and loop.hud.mode == "housing" and is_instance_valid(loop.hud.modal) and loop.hud.modal.is_ancestor_of(self) and not loop.save_menu.open

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
