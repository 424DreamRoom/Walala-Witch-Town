extends Node2D

const ResourceNode = preload("res://Scenes/Gameplay/resource_node.gd")
const SHEET := "res://Art/Character/Storybook/WalalaTools32/witch-tools-32.png"
const BITE_WINDOW := 1.5
var loop
var target: ResourceNode
var action := ""
var elapsed := 0.0
var wait_seconds := 0.0
var action_day := 0
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
	actor.texture = load(SHEET)
	fish_texture = load("res://Art/Environment/Hearthwood/harvest_fish.png")
	actor.hframes = 5
	actor.vframes = 12
	actor.position = loop.lane.WITCH_FOOT_OFFSET
	actor.visible = false
	loop.lane.player.add_child(actor)

func busy() -> bool:
	return not action.is_empty()

func fishing() -> bool:
	return action in ["cast", "wait", "bite", "reel"]

func start(node: ResourceNode) -> void:
	if busy() or loop.state.phase != "day" or loop.location not in ["field", "dock"]:
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
	target = node
	action_day = loop.state.day
	var direction: Vector2 = target.position - loop.lane.player.position
	loop.lane.facing = (2 if direction.x > 0 else 3) if absf(direction.x) > absf(direction.y) else (0 if direction.y > 0 else 1)
	loop.lane.player.velocity = Vector2.ZERO
	wait_seconds = rng.randf_range(2.0, 4.0) / (1.0 + loop.state.equipment.wand * 0.2)
	set_action({"wood": "chop", "ore": "mine", "fish": "cast"}[target.resource_kind])
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
	farm_cast_left = maxf(0.0, farm_cast_left - delta) if loop.location == "farm" and loop.state.phase == "day" else 0.0
	effect_left = maxf(0.0, effect_left - delta)
	if not busy():
		update_pose()
		queue_redraw()
		return
	# Scene changes and the day timer invalidate actions before rewards can be applied.
	if loop.location not in ["field", "dock"] or loop.state.phase != "day" or loop.state.day != action_day or not is_instance_valid(target) or not target.is_inside_tree() or loop.lane.player.position.distance_to(target.anchor) > 29.0:
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
	elif action == "bite" and elapsed >= BITE_WINDOW + loop.state.equipment.wand * 0.4:
		cancel("鱼儿溜走了。")
	elif action == "reel" and elapsed >= 0.6:
		if loop.state.catch_fish(target.resource_id):
			loop.audio.play_event("catch")
			loop._show_feedback()
		cancel()
	update_pose()
	queue_redraw()

func update_pose() -> void:
	actor.visible = busy() or farm_cast_left > 0.0
	loop.lane.avatar.visible = not actor.visible
	actor.position = loop.lane.WITCH_FOOT_OFFSET + loop.lane.player.position.round() - loop.lane.player.position
	if not busy():
		if farm_cast_left > 0.0:
			actor.frame = 32 + loop.lane.facing * 3 + mini(2, int((FARM_CAST_SECONDS - farm_cast_left) / (FARM_CAST_SECONDS / 3.0)))
		return
	var row: int = loop.lane.facing
	if action in ["chop", "mine"]:
		actor.frame = (0 if action == "chop" else 16) + row * 4 + mini(3, int(elapsed / (loop.state.swing_seconds(target.resource_kind) / 4.0)))
	elif action == "cast":
		actor.frame = 32 + row * 3 + mini(2, int(elapsed / 0.15))
	elif action in ["wait", "bite"]:
		actor.frame = 44 + row
	else:
		actor.frame = 48 + row * 3 + mini(2, int(elapsed / 0.2))
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
	var tip: Vector2 = [Vector2(14, -26), Vector2(12, -29), Vector2(14, -26), Vector2(-15, -26)][loop.lane.facing]
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
		draw_rect(Rect2(top + Vector2(-13, -11), Vector2(26 * maxf(0.0, 1.0 - elapsed / (BITE_WINDOW + loop.state.equipment.wand * 0.4)), 1)), Color("d9bd82"))
