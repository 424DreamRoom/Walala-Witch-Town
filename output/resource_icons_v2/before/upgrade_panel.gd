extends Control
## NPC service uses the HUD's existing paused modal and input routing.
const Catalog = preload("res://Scenes/Equipment/equipment_catalog.gd")
const UISkin = preload("res://Scenes/Gameplay/ui_skin.gd")
const RESOURCE_IDS := ["coin", "wood", "iron"]
const RESOURCE_NAMES := {"coin": "金币", "wood": "木材", "iron": "铁锭"}
const RESOURCE_TEXTURES := {
	"coin": preload("res://Art/Icon/Resources16_Original/witch_coin.png"),
	"wood": preload("res://Art/Icon/Resources16_Original/wood.png")
}
var loop
var provider: WeakRef
var selected := "wand"
var entries: Dictionary = {}
var detail: Control
var resources: Control
var status: Label
var feedback := ""

func _ready() -> void:
	name = "EquipmentUpgrades"
	position = Vector2(40, 24)
	size = Vector2(560, 312)
	var paper: Panel = loop.hud.panel(Rect2(Vector2.ZERO, size), self)
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	loop.hud.label("装备升级", Rect2(20, 12, 520, 32), self, UISkin.INK, 24)
	loop.hud.label("铁匠 · 余烬", Rect2(20, 48, 190, 20), self, UISkin.MUTED_INK)
	resources = Control.new()
	resources.name = "Resources"
	resources.position = Vector2(228, 46)
	resources.size = Vector2(312, 24)
	add_child(resources)
	for index in range(RESOURCE_IDS.size()):
		_resource_badge(RESOURCE_IDS[index], "", Rect2(index * 104, 0, 104, 24), resources)
	for index in range(Catalog.IDS.size()):
		var id: String = Catalog.IDS[index]
		var button: Button = loop.hud.button("", Rect2(20, 80 + index * 34, 188, 30), self, func():
			selected = id
			feedback = ""
			refresh(), "ui_page")
		button.name = "Equipment_" + id
		button.toggle_mode = true
		loop.hud.ornament(id, Vector2(7, 3), button)
		loop.hud.label(Catalog.TITLES[id], Rect2(40, 3, 140, 24), button, Color("fff0cf"))
		entries[id] = button
	detail = Control.new()
	detail.position = Vector2(228, 76)
	add_child(detail)
	status = loop.hud.label("", Rect2(20, 258, 188, 20), self, UISkin.MUTED_INK)
	var back: Button = loop.hud.button("返回", Rect2(428, 280, 112, 24), self, loop.hud.close_modal, "")
	back.name = "Back"
	refresh()
	entries[selected].grab_focus()
	Localization.language_changed.connect(func(_locale: String): refresh())

func _resource_badge(id: String, amount: String, rect: Rect2, parent: Node) -> Control:
	var badge := Control.new()
	badge.name = "Resource_" + id
	badge.position = rect.position
	badge.size = rect.size
	badge.tooltip_text = RESOURCE_NAMES[id]
	parent.add_child(badge)
	if id in RESOURCE_TEXTURES:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = RESOURCE_TEXTURES[id]
		icon.position = Vector2(4, 4)
		icon.size = Vector2(16, 16)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(icon)
	else:
		var icon: Control = loop.hud.ornament(id, Vector2.ZERO, badge)
		icon.name = "Icon"
	var count: Label = loop.hud.label(amount, Rect2(28, 0, rect.size.x - 28, 24), badge)
	count.name = "Count"
	return badge

func refresh() -> void:
	var state = loop.state
	var amounts := [state.coins, state.resources.wood, state.resources.iron]
	for index in range(RESOURCE_IDS.size()):
		resources.get_node("Resource_" + RESOURCE_IDS[index] + "/Count").text = str(amounts[index])
	for id in entries: entries[id].set_pressed_no_signal(id == selected)
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	var rank: int = state.equipment[selected]
	var maximum := rank >= Catalog.MAX_LEVEL
	var hud = loop.hud
	hud.label(Catalog.TITLES[selected], Rect2(0, 0, 310, 24), detail, UISkin.INK, 18)
	hud.ornament(selected, Vector2(0, 32), detail)
	var tier: String = tr(Catalog.TIERS[rank]) if maximum else "%s → %s" % [tr(Catalog.TIERS[rank]), tr(Catalog.TIERS[rank + 1])]
	hud.label(tier, Rect2(38, 30, 270, 24), detail)
	var effect: RichTextLabel = hud.rich_label(Catalog.effect(selected, rank, not maximum), Rect2(0, 62, 310, 60), detail, UISkin.MUTED_INK)
	effect.name = "EquipmentDescription"
	if not maximum:
		var price := Catalog.cost(selected, rank)
		_resource_badge("coin", "%d / %d" % [state.coins, price.coins], Rect2(0, 122, 310, 24), detail)
		_resource_badge("wood", "%d / %d" % [state.resources.wood, price.wood], Rect2(0, 146, 155, 24), detail)
		_resource_badge("iron", "%d / %d" % [state.resources.iron, price.iron], Rect2(155, 146, 155, 24), detail)
	var upgrade: Button = hud.button("已达最高等级" if maximum else "升级", Rect2(0, 174, 310, 26), detail, purchase, "")
	upgrade.name = "Upgrade"
	upgrade.disabled = not _available() or not state.can_upgrade(selected)
	status.text = tr(feedback)

func _available() -> bool:
	var npc = provider.get_ref() if provider != null else null
	return is_instance_valid(npc) and npc.is_inside_tree() and loop.location == "blacksmith" and npc.kind == "blacksmith" and loop.near(npc.stations.service) and loop.state.phase == "day" and loop.hud.mode == "upgrades" and not loop.save_menu.open

func purchase() -> void:
	# A queued click cannot buy after leaving, closing, or switching service.
	if not _available(): return
	if loop.state.upgrade_equipment(selected):
		feedback = "升级完成"
		loop.audio.play_event("mine")
		loop._autosave()
	else:
		feedback = "无法升级"
		loop.audio.play_event("ui_error")
	refresh()
	var button: Button = detail.get_node("Upgrade")
	if not button.disabled: button.grab_focus()
	else: entries[selected].grab_focus()
