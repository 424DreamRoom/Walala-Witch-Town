extends RefCounted
## A held stack is a transaction: saves and closing return to its last commit.
const Items = preload("res://Scenes/Storage/inventory_items.gd")
var state
var chest_id := -1
var hand := {}
var origin_side := "bag"
var origin_index := -1

func _init(owner, id: int = -1) -> void:
	state = owner
	chest_id = id
	Items.ensure_bag(state)
	if id >= 0: Items.chest_slots(state.furniture_by_id(id))

func slots(side: String) -> Array:
	if side == "bag": return state.bag_slots
	return Items.chest_slots(state.furniture_by_id(chest_id)) if chest_id >= 0 else []

func _begin() -> void:
	if not state.inventory_pending.is_empty(): return
	state.inventory_pending = {"bag": state.bag_slots.duplicate(true), "chest_id": chest_id}
	if chest_id >= 0: state.inventory_pending["chest"] = slots("chest").duplicate(true)

func _sync() -> void:
	Items.sync(state)
	if chest_id >= 0: Items.sync_chest(state.furniture_by_id(chest_id))
	if hand.is_empty(): state.inventory_pending.clear()

func click(side: String, index: int, right: bool = false, quick: bool = false) -> bool:
	var target := slots(side)
	if index < 0 or index >= target.size(): return false
	var slot: Dictionary = target[index]
	if quick and hand.is_empty(): return quick_move(side, index)
	if hand.is_empty():
		if slot.is_empty(): return false
		_begin()
		origin_side = side
		origin_index = index
		var amount: int = ceili(slot.count / 2.0) if right else slot.count
		hand = {"id": slot.id, "count": amount}
		slot.count -= amount
		if slot.count == 0: target[index] = {}
	elif slot.is_empty() or slot.id == hand.id:
		var available: int = Items.stack_size(hand.id) - int(slot.get("count", 0))
		var amount := mini(available, 1 if right else int(hand.count))
		if amount <= 0: return false
		target[index] = {"id": hand.id, "count": int(slot.get("count", 0)) + amount}
		hand.count -= amount
		if hand.count == 0: hand = {}
	elif not right:
		target[index] = hand
		hand = slot
	else: return false
	_sync()
	return true

func quick_move(side: String, index: int) -> bool:
	if not hand.is_empty(): return false
	var source := slots(side)
	if index < 0 or index >= source.size() or source[index].is_empty(): return false
	var slot: Dictionary = source[index]
	var destination := slots("chest" if side == "bag" else "bag")
	if chest_id < 0:
		# In the backpack, Shift moves between the first row and extra rows.
		destination = source.slice(12) if index < 12 else source.slice(0, 12)
	var moved := Items.insert(destination, slot.id, slot.count)
	if moved == 0: return false
	if chest_id < 0:
		var offset := 12 if index < 12 else 0
		for i in range(destination.size()): source[offset + i] = destination[i]
	slot.count -= moved
	if slot.count == 0: source[index] = {}
	_sync()
	return true

func finish() -> void:
	if not hand.is_empty() and not state.inventory_pending.is_empty():
		var bag := slots("bag").duplicate(true)
		var chest := slots("chest").duplicate(true)
		var source: Array = bag if origin_side == "bag" else chest
		var other: Array = chest if origin_side == "bag" else bag
		var remaining: int = hand.count
		if origin_index >= 0 and origin_index < source.size():
			var origin: Dictionary = source[origin_index]
			if origin.is_empty() or origin.id == hand.id:
				var amount := mini(remaining, Items.stack_size(hand.id) - int(origin.get("count", 0)))
				source[origin_index] = {"id": hand.id, "count": int(origin.get("count", 0)) + amount}
				remaining -= amount
		remaining -= Items.insert(source, hand.id, remaining)
		remaining -= Items.insert(other, hand.id, remaining)
		state.bag_slots = bag if remaining == 0 else state.inventory_pending.bag.duplicate(true)
		if chest_id >= 0:
			state.furniture_by_id(chest_id)["slots"] = chest if remaining == 0 else state.inventory_pending.chest.duplicate(true)
	hand = {}
	_sync()
