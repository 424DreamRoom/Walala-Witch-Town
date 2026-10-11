extends RefCounted
## Slots are authoritative during interaction; aggregate fields serve gameplay.
const TOOLS := ["wand"]
const LEGACY_TOOLS := ["axe", "hoe", "watering_can", "pickaxe"]
const RAW := ["mushroom", "berry", "herb"]
const RESOURCES := ["wood", "ore", "fish", "iron"]
const FOODS := ["bread", "egg", "tomato"]
const IDS := ["wand", "mushroom", "berry", "herb", "wood", "ore", "fish", "iron", "seed", "bread", "egg", "tomato"]
const LEGACY_IDS := ["axe", "hoe", "watering_can", "pickaxe", "mushroom", "berry", "herb", "wood", "ore", "fish", "iron", "seed"]
const NAMES := {"wand": "法杖", "mushroom": "蘑菇", "berry": "莓果", "herb": "香草", "wood": "木材", "ore": "矿石", "fish": "鱼", "iron": "铁锭", "seed": "香草种子", "bread": "面包", "egg": "鸡蛋", "tomato": "番茄"}
const CHEST_SLOTS := 12
const HOTBAR_SLOTS := 10
const STACK_SIZE := 99

static func count(state, id: String) -> int:
	if id in TOOLS or id in LEGACY_TOOLS: return state.tools[id]
	if id in RAW: return state.raw[RAW.find(id)]
	if id in RESOURCES: return state.resources[id]
	if id == "seed": return state.farm.seeds
	# These stacks have no legacy aggregate field; the bag remains authoritative.
	if id in FOODS: return int(totals(state.bag_slots).get(id, 0))
	return 0

static func stack_size(id: String) -> int:
	return 1 if id in TOOLS or id in LEGACY_TOOLS else STACK_SIZE

static func empty_slots(capacity: int) -> Array:
	var slots := []
	for i in range(capacity): slots.append({})
	return slots

static func totals(slots: Array) -> Dictionary:
	var result := {}
	for slot in slots:
		if not slot.is_empty(): result[slot.id] = int(result.get(slot.id, 0)) + slot.count
	return result

static func room_in(slots: Array, id: String) -> int:
	var result := 0
	for slot in slots:
		if slot.is_empty(): result += stack_size(id)
		elif slot.id == id: result += stack_size(id) - slot.count
	if id in TOOLS or id in LEGACY_TOOLS: result = mini(result, 1 - int(totals(slots).get(id, 0)))
	return result

static func insert(slots: Array, id: String, requested: int) -> int:
	var remaining := mini(requested, room_in(slots, id))
	var amount := remaining
	for empty in [false, true]:
		for i in range(slots.size()):
			if remaining == 0: return amount
			var slot: Dictionary = slots[i]
			if empty and slot.is_empty(): slots[i] = {"id": id, "count": 0}
			elif empty or slot.is_empty() or slot.id != id: continue
			var moved := mini(remaining, stack_size(id) - int(slots[i].count))
			slots[i].count += moved
			remaining -= moved
	return amount - remaining

static func remove(slots: Array, id: String, requested: int) -> int:
	var remaining := requested
	for i in range(slots.size() - 1, -1, -1):
		var slot: Dictionary = slots[i]
		if slot.is_empty() or slot.id != id: continue
		var moved := mini(remaining, int(slot.count))
		slot.count -= moved
		remaining -= moved
		if slot.count == 0: slots[i] = {}
		if remaining == 0: break
	return requested - remaining

static func sync(state) -> void:
	var quantities := totals(state.bag_slots)
	for id in TOOLS: state.tools[id] = int(quantities.get(id, 0))
	for i in range(RAW.size()): state.raw[i] = int(quantities.get(RAW[i], 0))
	for id in RESOURCES: state.resources[id] = int(quantities.get(id, 0))
	state.farm.seeds = int(quantities.get("seed", 0))

static func ensure_bag(state) -> void:
	while state.bag_slots.size() < state.bag_capacity(): state.bag_slots.append({})
	var quantities := totals(state.bag_slots)
	# Import legacy quantities without throwing away stacks that do not fit.
	for id in IDS:
		var difference: int = count(state, id) - int(quantities.get(id, 0))
		if difference < 0: remove(state.bag_slots, id, -difference)
		elif difference > 0:
			var overflow := difference - insert(state.bag_slots, id, difference)
			if overflow > 0: state.bag_overflow[id] = int(state.bag_overflow.get(id, 0)) + overflow
	sync(state)

static func room(state, id: String) -> int:
	ensure_bag(state)
	return room_in(state.bag_slots, id)

static func changed_slots(slots: Array, deltas: Dictionary) -> Array:
	var next := slots.duplicate(true)
	for id in deltas:
		if id not in IDS: return []
		if deltas[id] < 0 and remove(next, id, -deltas[id]) != -deltas[id]: return []
	for id in deltas:
		if deltas[id] > 0 and insert(next, id, deltas[id]) != deltas[id]: return []
	return next

static func can_change(state, deltas: Dictionary) -> bool:
	ensure_bag(state)
	return not changed_slots(state.bag_slots, deltas).is_empty()

static func change(state, deltas: Dictionary) -> bool:
	ensure_bag(state)
	var next := changed_slots(state.bag_slots, deltas)
	if next.is_empty(): return false
	state.bag_slots = next
	sync(state)
	return true

static func add(state, id: String, amount: int) -> void:
	change(state, {id: amount})

static func chest_slots(chest: Dictionary) -> Array:
	if not chest.has("slots"):
		chest["slots"] = empty_slots(CHEST_SLOTS)
		for id in chest.get("items", {}): insert(chest.slots, id, int(chest.items[id]))
	return chest.slots

static func sync_chest(chest: Dictionary) -> void:
	chest["items"] = totals(chest.slots)

static func claim_overflow(state) -> int:
	ensure_bag(state)
	var moved := 0
	for id in state.bag_overflow.keys():
		var amount := insert(state.bag_slots, id, state.bag_overflow[id])
		state.bag_overflow[id] -= amount
		moved += amount
		if state.bag_overflow[id] == 0: state.bag_overflow.erase(id)
	sync(state)
	return moved

static func normalize_slots(value: Variant, capacity: int, legacy: bool = false) -> Dictionary:
	if not value is Array or value.size() != capacity: return {"ok": false}
	var ids: Array = LEGACY_IDS if legacy else IDS
	var slots := []
	for slot in value:
		if not slot is Dictionary: return {"ok": false}
		if slot.is_empty(): slots.append({}); continue
		if slot.size() != 2 or slot.get("id") not in ids or not valid_amount(slot.get("count"), stack_size(slot.id)): return {"ok": false}
		slots.append({"id": slot.id, "count": int(slot.count)})
	for id in (LEGACY_TOOLS if legacy else TOOLS):
		if int(totals(slots).get(id, 0)) > 1: return {"ok": false}
	return {"ok": true, "slots": slots}

static func valid_amount(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 1 and value <= maximum and float(value) == floorf(float(value))

static func normalize_contents(value: Variant, maximum: int = STACK_SIZE, legacy: bool = false) -> Dictionary:
	var ids: Array = LEGACY_IDS if legacy else IDS
	if not value is Dictionary or value.size() > ids.size(): return {"ok": false}
	var items := {}
	for id in value:
		if id not in ids or not valid_amount(value[id], 1 if id in TOOLS or id in LEGACY_TOOLS else maximum): return {"ok": false}
		items[id] = int(value[id])
	return {"ok": true, "items": items}

static func migrate_tools(state: Dictionary) -> void:
	# Validate the old schema first, then keep one wand in the first owned slot.
	var rank: int = state.campaign.rod
	for id in LEGACY_TOOLS: rank = maxi(rank, state.equipment[id])
	state.equipment = {"wand": rank, "bag": state.equipment.bag}
	state.campaign.rod = 0
	var found := _migrate_tool_slots(state.bag_slots, false)
	for id in LEGACY_TOOLS:
		if state.bag_overflow.has(id):
			if not found: state.bag_overflow.wand = 1; found = true
			state.bag_overflow.erase(id)
	for chest in state.furniture.placed:
		if chest.kind != "chest": continue
		found = _migrate_tool_slots(chest.slots, found)
		sync_chest(chest)
	# Fishing rods were implicit ownership, including when all other tools were absent.
	if not found:
		if insert(state.bag_slots, "wand", 1) == 0: state.bag_overflow.wand = 1
	state.tools = {"wand": 0}
	sync(state)

static func _migrate_tool_slots(slots: Array, found: bool) -> bool:
	for index in range(slots.size()):
		if slots[index].get("id", "") not in LEGACY_TOOLS: continue
		slots[index] = {} if found else {"id": "wand", "count": 1}
		found = true
	return found
