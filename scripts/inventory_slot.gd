class_name InventorySlot
extends RefCounted

var item_id: String = ""
var quantity: int = 0

func is_empty() -> bool:
	return item_id.is_empty() or quantity <= 0

func can_add_item(item: Item, amount: int = 1) -> bool:
	if is_empty():
		return true
	if item_id == item.id and item.stackable:
		return quantity + amount <= item.max_stack
	return false

func add_item(item: Item, amount: int = 1) -> int:
	if is_empty():
		item_id = item.id
		quantity = min(amount, item.max_stack)
		return amount - quantity
	elif item_id == item.id and item.stackable:
		var space_available = item.max_stack - quantity
		var amount_to_add = min(amount, space_available)
		quantity += amount_to_add
		return amount - amount_to_add
	return amount

func remove_item(amount: int = 1) -> int:
	var removed = min(amount, quantity)
	quantity -= removed
	if quantity <= 0:
		clear()
	return removed

func clear() -> void:
	item_id = ""
	quantity = 0

func to_dict() -> Dictionary:
	return {"item_id": item_id, "quantity": quantity}

func from_dict(data: Dictionary) -> void:
	item_id = data.get("item_id", "")
	quantity = data.get("quantity", 0)