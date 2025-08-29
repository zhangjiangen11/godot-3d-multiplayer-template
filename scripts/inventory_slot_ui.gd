extends Control
class_name InventorySlotUI

@onready var background: NinePatchRect = $Background
@onready var item_icon: TextureRect = $ItemIcon
@onready var quantity_label: Label = $QuantityLabel
@onready var rarity_border: NinePatchRect = $RarityBorder

var slot_index: int = 0
var inventory_data: InventorySlot
var parent_inventory: Control

signal slot_clicked(slot_index: int, button: int)
signal item_hovered(slot_index: int, item: Item)
signal item_unhovered

const RARITY_COLORS = {
	Item.ItemRarity.COMMON: Color.WHITE,
	Item.ItemRarity.UNCOMMON: Color.GREEN,
	Item.ItemRarity.RARE: Color.BLUE,
	Item.ItemRarity.EPIC: Color.PURPLE,
	Item.ItemRarity.LEGENDARY: Color.ORANGE
}

func _ready():
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Initialize empty slot
	update_display()

func set_slot_data(slot_data: InventorySlot, index: int):
	inventory_data = slot_data
	slot_index = index
	update_display()

func update_display():
	if not inventory_data or inventory_data.is_empty():
		_show_empty_slot()
	else:
		_show_item_slot()

func _show_empty_slot():
	if item_icon:
		item_icon.texture = null
	if quantity_label:
		quantity_label.visible = false
	if rarity_border:
		rarity_border.visible = false
	if background:
		background.modulate = Color.WHITE

func _show_item_slot():
	var item = ItemDatabase.get_item(inventory_data.item_id)
	if not item:
		_show_empty_slot()
		return
	
	# Set item icon
	item_icon.texture = item.icon
	
	# Show quantity if stackable and > 1
	if item.stackable and inventory_data.quantity > 1:
		quantity_label.text = str(inventory_data.quantity)
		quantity_label.visible = true
	else:
		quantity_label.visible = false
	
	# Show rarity border
	if RARITY_COLORS.has(item.rarity):
		rarity_border.modulate = RARITY_COLORS[item.rarity]
		rarity_border.visible = true
	else:
		rarity_border.visible = false

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			slot_clicked.emit(slot_index, event.button_index)

func _on_mouse_entered():
	if inventory_data and not inventory_data.is_empty():
		var item = ItemDatabase.get_item(inventory_data.item_id)
		if item:
			item_hovered.emit(slot_index, item)
	
	# Highlight slot
	background.modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited():
	item_unhovered.emit()
	
	# Remove highlight
	background.modulate = Color.WHITE

# Drag and drop functionality
func _can_drop_data(_position: Vector2, data) -> bool:
	return data is Dictionary and data.has("slot_index") and data.has("inventory_type")

func _drop_data(_position: Vector2, data):
	if parent_inventory and parent_inventory.has_method("handle_item_drop"):
		parent_inventory.handle_item_drop(data.slot_index, slot_index, data.inventory_type)

func _get_drag_data(_position: Vector2):
	if not inventory_data or inventory_data.is_empty():
		return null
	
	var item = ItemDatabase.get_item(inventory_data.item_id)
	if not item:
		return null
	
	# Create drag preview
	var preview = Control.new()
	var preview_icon = TextureRect.new()
	preview_icon.texture = item.icon
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.size = Vector2(32, 32)
	preview.add_child(preview_icon)
	
	# Semi-transparent during drag
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	
	# Dim the original slot during drag
	item_icon.modulate = Color(0.5, 0.5, 0.5)
	
	return {
		"slot_index": slot_index,
		"item_id": inventory_data.item_id,
		"quantity": inventory_data.quantity,
		"inventory_type": "player"  # Can be extended for different inventory types
	}

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		# Restore original appearance when drag ends
		item_icon.modulate = Color.WHITE
