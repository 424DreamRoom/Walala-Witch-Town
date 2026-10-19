extends Node2D

const ResourceNode = preload("res://Scenes/Gameplay/resource_node.gd")
const Equipment = preload("res://Scenes/Equipment/equipment_catalog.gd")
const WitchAnimation = preload("res://Art/Character/Storybook/WalalaWitchAseprite32/witch_animation.gd")
const WandVisuals = preload("res://Scenes/Equipment/wand_visuals.gd")
const SHEET := WitchAnimation.SHEET
var loop
var target: ResourceNode
var action := ""
var elapsed := 0.0
var wait_seconds := 0.0
var action_day := 0
var action_mode := "blue"
var impacted := false
var effect_left := 0.0
var effect_position := Vector2.ZERO
var effect_kind := "wood"
var rng := RandomNumberGenerator.new()
var actor: Sprite2D
var fish_texture: Texture2D
var paused_for_test := false
var farm_cast_left := 0.0
const FARM_CAST_SECONDS := 0.35

func _ready() -> void:
	# Wand, line and catch travel with the player's depth, including behind foliage.
	z_index = 0
	rng.randomize()
	actor = Sprite2D.new()
	actor.name = "ToolAction"
	WitchAnimation.configure(actor)
	fish_texture = load("res://Art/Environment/Hearthwood/harvest_fish.aseprite")
	actor.position = loop.lane.WITCH_FOOT_OFFSET
	actor.visible = false
	loop.lane.player.add_child(actor)

func busy() -> bool:
	return not action.is_empty()

func fishing() -> bool:
	return action in ["cast", "wait", "bite", "reel"]

func start(node: ResourceNode) -> void:
	if busy() or loop.state.phase != "day" or loop.location not in ["field", "dock", "farm"]:
		return
	if not node.available():
		loop.state.message = "鱼儿已散去。" if node.resource_kind == "fish" else "这里已采完，次日刷新。"
		loop._show_feedback()
		return
	var required_tool: String = loop.state.RESOURCE_TOOLS.get(node.resource_kind, "")
	if not required_tool.is_empty() and not loop.state.has_tool(required_tool):
		loop.state.set_message("需要%s。", [loop.state.TOOL_NAMES[required_tool]])
		loop._show_feedback()
		return
	if not required_tool.is_empty() and not loop.state.require_selected_item(required_tool):
		loop._show_feedback()
		return
	if node.resource_kind in ["wood", "ore", "weed"] and not loop.state.require_wand_mode("red"):
		loop._show_feedback()
		return
	target = node
	action_day = loop.state.day
	action_mode = loop.state.wand_mode
	var direction: Vector2 = target.position - loop.lane.player.position
	loop.lane.facing = (2 if direction.x > 0 else 3) if absf(direction.x) > absf(direction.y) else (0 if direction.y > 0 else 1)
	loop.lane.player.velocity = Vector2.ZERO
	var wait_range := Equipment.fishing_wait_range(loop.state.equipment.wand)
	wait_seconds = rng.randf_range(wait_range.x, wait_range.y)
	set_action({"wood": "chop", "ore": "mine", "fish": "cast", "weed": "chop"}[target.resource_kind])
	if action == "cast":
		loop.state.message = ""

func set_action(value: String) -> void:
	action = value
	elapsed = 0.0
	impacted = false
	update_pose()

func interact() -> void:
	if action == "bite":
		set_action("reel")
	elif action == "wait":
		cancel("收竿太早，鱼儿还没咬钩。")

func show_farm_cast() -> void:
	action_mode = loop.state.wand_mode
	farm_cast_left = FARM_CAST_SECONDS
	update_pose()

func cancel(message: String = "") -> void:
	action = ""
	farm_cast_left = 0.0
	target = null
	actor.visible = false
	loop.lane.avatar.visible = true
	if not message.is_empty():
		loop.state.message = message
		loop._show_feedback()
	queue_redraw()

func advance(delta: float) -> void:
	if paused_for_test:
		return
	if (busy() or farm_cast_left > 0.0) and (not loop.state.is_item_selected("wand") or loop.state.wand_mode != action_mode):
		cancel()
		return
	farm_cast_left = maxf(0.0, farm_cast_left - delta) if loop.location == "farm" and loop.state.phase == "day" else 0.0
	effect_left = maxf(0.0, effect_left - delta)
	if not busy():
		update_pose()
		queue_redraw()
		return
	# Scene changes and the day timer invalidate actions before rewards can be applied.
	if loop.location not in ["field", "dock", "farm"] or loop.state.phase != "day" or loop.state.day != action_day or not is_instance_valid(target) or not target.is_inside_tree() or loop.lane.player.position.distance_to(target.anchor) > 29.0:
		cancel()
		return
	elapsed += delta
	if action in ["chop", "mine"]:
		var duration: float = loop.state.swing_seconds(target.resource_kind)
		if elapsed >= duration / 2.0 and not impacted:
			impacted = true
			var left: int = loop.state.strike_resource(target.resource_id, target.resource_kind)
			if left >= 0:
				target.hit()
				loop.audio.play_event(action)
				effect_position = target.position + Vector2(0, -10)
				effect_kind = target.resource_kind
				effect_left = 0.4
				if left == 0:
					loop._show_feedback()
		if elapsed >= duration:
			cancel()
	elif action == "cast" and elapsed >= 0.45:
		# The water cue belongs to the bobber landing, after the casting arc.
		loop.audio.play_event("cast")
		set_action("wait")
	elif action == "wait" and elapsed >= wait_seconds:
		set_action("bite")
		loop.audio.play_event("bite")
	elif action == "bite" and elapsed >= Equipment.BITE_WINDOWS[loop.state.equipment.wand]:
		cancel("鱼儿溜走了。")
	elif action == "reel" and elapsed >= 0.6:
		if loop.state.catch_fish(target.resource_id):
			loop.audio.play_event("catch")
			loop._show_feedback()
		cancel()
	update_pose()
	queue_redraw()

func update_pose() -> void:
	actor.texture = WandVisuals.action_texture(loop.state.wand_mode)
	actor.visible = busy() or farm_cast_left > 0.0
	loop.lane.avatar.visible = not actor.visible
	actor.position = loop.lane.WITCH_FOOT_OFFSET + loop.lane.player.position.round() - loop.lane.player.position
	if not busy():
		if farm_cast_left > 0.0:
			actor.frame = WitchAnimation.frame_for("cast", loop.lane.facing, FARM_CAST_SECONDS - farm_cast_left, FARM_CAST_SECONDS)
		return
	var row: int = loop.lane.facing
	if action in ["chop", "mine"]:
		actor.frame = WitchAnimation.frame_for("cast", row, elapsed, loop.state.swing_seconds(target.resource_kind))
	elif action == "cast":
		actor.frame = WitchAnimation.frame_for("fish-cast", row, elapsed, 0.45)
	elif action in ["wait", "bite"]:
		actor.frame = WitchAnimation.frame_for("fish-wait", row, elapsed)
	else:
		actor.frame = WitchAnimation.frame_for("fish-reel", row, elapsed, 0.6)
	actor.position = loop.lane.WITCH_FOOT_OFFSET + loop.lane.player.position.round() - loop.lane.player.position

func prompt() -> String:
	return tr({"chop": "砍伐", "mine": "开采", "cast": "抛竿", "wait": "等待咬钩", "bite": "咬钩！", "reel": "收竿"}.get(action, ""))

func _draw() -> void:
	var feet: Vector2 = loop.lane.player.position
	if effect_left > 0.0:
		var t := 1.0 - effect_left / 0.4
		for i in range(6):
			var offset := Vector2((i - 2.5) * t * 9.0, -sin(t * PI) * (8 + i % 3 * 4))
			draw_rect(Rect2((effect_position + offset - feet).round(), Vector2(2, 2)), Color("e2bd83") if effect_kind == "wood" else Color("b8d6c7"))
	if not fishing() or not is_instance_valid(target):
		return
	var bob := target.water + Vector2(0, roundf(sin(elapsed * (18.0 if action == "bite" else 3.0))))
	var fishing_animation := "fish-cast" if action == "cast" else "fish-reel" if action == "reel" else "fish-wait"
	var animation_seconds := 0.45 if action == "cast" else 0.6 if action == "reel" else 0.0
	var tip := WitchAnimation.fishing_tip(fishing_animation, loop.lane.facing, elapsed, animation_seconds)
	var hand: Vector2 = loop.lane.player.position + tip
	if action == "cast":
		bob = hand.lerp(target.water, minf(1.0, elapsed / 0.45))
	elif action == "reel":
		bob = target.water.lerp(hand, minf(1.0, elapsed / 0.6))
	hand -= feet
	bob -= feet
	draw_line(hand.round(), bob.round(), Color("ecdabc"), 1.0)
	draw_rect(Rect2(bob + Vector2(-1, -3), Vector2(3, 3)), Color("c2787c"))
	draw_rect(Rect2(bob, Vector2(3, 2)), Color("fff0d5"))
	if action == "reel":
		draw_texture(fish_texture, (bob + Vector2(-8, 4)).round())
	if action == "bite":
		draw_rect(Rect2(bob + Vector2(-6, -1), Vector2(3, 1)), Color("cfdfce"))
		draw_rect(Rect2(bob + Vector2(6, 1), Vector2(3, 1)), Color("cfdfce"))
		var top := Vector2(0, -54)
		draw_rect(Rect2(top + Vector2(-1, -6), Vector2(3, 5)), Color("fff0a0"))
		draw_rect(Rect2(top + Vector2(-1, 1), Vector2(3, 2)), Color("fff0a0"))
		draw_rect(Rect2(top + Vector2(-14, -12), Vector2(28, 3)), Color("3e473e"))
		draw_rect(Rect2(top + Vector2(-13, -11), Vector2(26 * maxf(0.0, 1.0 - elapsed / Equipment.BITE_WINDOWS[loop.state.equipment.wand]), 1)), Color("d9bd82"))
