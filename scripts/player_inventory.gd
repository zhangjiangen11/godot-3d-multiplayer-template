class_name PlayerInventory
extends RefCounted

const INVENTORY_SIZE = 20  # 4x5 grid
var slots: Array[InventorySlot] = []

func _init():
	_initialize_slots()

func _initialize_slots():
	slots.clear()
	for i in range(INVENTORY_SIZE):
		slots.append(InventorySlot.new())

func get_slot(index: int) -> InventorySlot:
	if index >= 0 and index < slots.size():
		return slots[index]
	return null

func add_item(item: Item, quantity: int = 1) -> int:
	var remaining = quantity
	
	# First, try to add to existing stacks
	if item.stackable:
		for slot in slots:
			if slot.item_id == item.id:
				remaining = slot.add_item(item, remaining)
				if remaining <= 0:
					break
	
	# Then, try to add to empty slots
	if remaining > 0:
		for slot in slots:
			if slot.is_empty():
				remaining = slot.add_item(item, remaining)
				if remaining <= 0:
					break
	
	return remaining  # Returns what couldn't be added

func remove_item(item_id: String, quantity: int = 1) -> int:
	var removed = 0
	for slot in slots:
		if slot.item_id == item_id:
			var slot_removed = slot.remove_item(quantity - removed)
			removed += slot_removed
			if removed >= quantity:
				break
	return removed

func move_item(from_index: int, to_index: int, quantity: int = -1) -> bool:
	var from_slot = get_slot(from_index)
	var to_slot = get_slot(to_index)
	
	if not from_slot or not to_slot or from_slot.is_empty():
		return false
	
	# If quantity is -1, move entire stack
	var move_amount = quantity if quantity > 0 else from_slot.quantity
	move_amount = min(move_amount, from_slot.quantity)
	
	# Get item reference for validation
	var item = ItemDatabase.get_item(from_slot.item_id)
	if not item:
		return false
	
	# Check if we can add to destination
	if to_slot.can_add_item(item, move_amount):
		from_slot.remove_item(move_amount)
		to_slot.add_item(item, move_amount)
		return true
	
	return false

func swap_items(from_index: int, to_index: int) -> bool:
	var from_slot = get_slot(from_index)
	var to_slot = get_slot(to_index)
	
	if not from_slot or not to_slot:
		return false
	
	# Store temporary data
	var temp_item_id = from_slot.item_id
	var temp_quantity = from_slot.quantity
	
	# Swap the contents
	from_slot.item_id = to_slot.item_id
	from_slot.quantity = to_slot.quantity
	
	to_slot.item_id = temp_item_id
	to_slot.quantity = temp_quantity
	
	return true

func get_item_count(item_id: String) -> int:
	var total = 0
	for slot in slots:
		if slot.item_id == item_id:
			total += slot.quantity
	return total

func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity

func get_first_empty_slot() -> int:
	for i in range(slots.size()):
		if slots[i].is_empty():
			return i
	return -1

func get_free_space_for_item(item: Item) -> int:
	var free_space = 0
	
	# Count space in existing stacks
	if item.stackable:
		for slot in slots:
			if slot.item_id == item.id:
				free_space += item.max_stack - slot.quantity
	
	# Count empty slots
	for slot in slots:
		if slot.is_empty():
			free_space += item.max_stack
	
	return free_space

func to_dict() -> Dictionary:
	var data = []
	for slot in slots:
		data.append(slot.to_dict())
	return {"slots": data}

func from_dict(data: Dictionary) -> void:
	var slots_data = data.get("slots", [])
	for i in range(min(slots_data.size(), slots.size())):
		slots[i].from_dict(slots_data[i])