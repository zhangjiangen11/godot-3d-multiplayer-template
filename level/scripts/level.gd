extends Node3D

@onready var skin_input: LineEdit = $Menu/MainContainer/MainMenu/Option2/SkinInput
@onready var nick_input: LineEdit = $Menu/MainContainer/MainMenu/Option1/NickInput
@onready var address_input: LineEdit = $Menu/MainContainer/MainMenu/Option3/AddressInput
@onready var players_container: Node3D = $PlayersContainer
@onready var menu: Control = $Menu
@export var player_scene: PackedScene

# multiplayer chat
@onready var message: LineEdit = $MultiplayerChat/VBoxContainer/HBoxContainer/Message
@onready var send: Button = $MultiplayerChat/VBoxContainer/HBoxContainer/Send
@onready var chat: TextEdit = $MultiplayerChat/VBoxContainer/Chat
@onready var multiplayer_chat: Control = $MultiplayerChat

# inventory
@onready var inventory_ui: InventoryUI = $InventoryUI

var chat_visible = false
var inventory_visible = false

func _ready():
	multiplayer_chat.hide()
	menu.show()
	multiplayer_chat.set_process_input(true)
	
	# Connect inventory signals
	if inventory_ui:
		inventory_ui.inventory_closed.connect(_on_inventory_closed)
	
	if not multiplayer.is_server():
		return

	Network.connect("player_connected", Callable(self, "_on_player_connected"))
	multiplayer.peer_disconnected.connect(_remove_player)

func _on_player_connected(peer_id, player_info):
	_add_player(peer_id, player_info)

func _on_host_pressed():
	menu.hide()
	Network.start_host(nick_input.text.strip_edges(), skin_input.text.strip_edges().to_lower())

func _on_join_pressed():
	menu.hide()
	Network.join_game(nick_input.text.strip_edges(), skin_input.text.strip_edges().to_lower(), address_input.text.strip_edges())

func _add_player(id: int, player_info : Dictionary):
	if players_container.has_node(str(id)):
		return
	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = get_spawn_point()
	players_container.add_child(player, true)

	var nick = Network.players[id]["nick"]
	player.nickname.text = nick

	var skin_enum = player_info["skin"]
	player.set_player_skin(skin_enum)

func get_spawn_point() -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 10 # spawn radius
	return Vector3(spawn_point.x, 0, spawn_point.y)

func _remove_player(id):
	if not multiplayer.is_server() or not players_container.has_node(str(id)):
		return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()

func _on_quit_pressed() -> void:
	get_tree().quit()

# ---------- MULTIPLAYER CHAT ----------
func toggle_chat():
	if menu.visible:
		return

	chat_visible = !chat_visible
	if chat_visible:
		multiplayer_chat.show()
		message.grab_focus()
	else:
		multiplayer_chat.hide()
		get_viewport().set_input_as_handled()

func is_chat_visible() -> bool:
	return chat_visible

func _input(event):
	if event.is_action_pressed("toggle_chat"):
		toggle_chat()
	elif event.is_action_pressed("inventory"):
		toggle_inventory()
	elif event is InputEventKey and event.keycode == KEY_ENTER:
		_on_send_pressed()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		# Debug: Add test item to local player's inventory
		_debug_add_item()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		# Debug: Print local player's inventory
		_debug_print_inventory()

func _on_send_pressed() -> void:
	var trimmed_message = message.text.strip_edges()
	if trimmed_message == "":
		return # do not send empty messages

	var nick = Network.players[multiplayer.get_unique_id()]["nick"]

	rpc("msg_rpc", nick, trimmed_message)
	message.text = ""
	message.grab_focus()

@rpc("any_peer", "call_local")
func msg_rpc(nick, msg):
	chat.text += str(nick, " : ", msg, "\n")

# ---------- INVENTORY SYSTEM ----------
func toggle_inventory():
	if menu.visible:
		return
	
	# Get the local player
	var local_player = _get_local_player()
	if not local_player:
		return
	
	inventory_visible = !inventory_visible
	if inventory_visible:
		inventory_ui.open_inventory(local_player)
	else:
		inventory_ui.close_inventory()

func is_inventory_visible() -> bool:
	return inventory_visible

# Additional helper for testing
func _notification(what):
	if what == NOTIFICATION_READY:
		print("Inventory System Controls:")
		print("  B - Toggle inventory")
		print("  F1 - Add random test item (debug)")
		print("  F2 - Print inventory contents (debug)")

func _on_inventory_closed():
	inventory_visible = false

# Called by player when inventory is synced from server
func update_local_inventory_display():
	if inventory_ui:
		# Always refresh if the UI exists, regardless of visibility
		# This ensures the UI is up-to-date when it becomes visible
		inventory_ui.refresh_display()
		print("Debug: Inventory display updated from server sync")

func _get_local_player() -> Character:
	# Find the player node that this client controls
	var local_player_id = multiplayer.get_unique_id()
	if players_container.has_node(str(local_player_id)):
		return players_container.get_node(str(local_player_id)) as Character
	return null

# Debug functions for testing inventory system
func _debug_add_item():
	var local_player = _get_local_player()
	if local_player:
		# Add a random test item
		var test_items = ["iron_sword", "health_potion", "leather_armor", "magic_gem", "iron_pickaxe"]
		var random_item = test_items[randi() % test_items.size()]
		print("Debug: Requesting to add ", random_item, " to player ", local_player.name, " (authority: ", local_player.get_multiplayer_authority(), ")")
		local_player.request_add_item.rpc_id(1, random_item, 1)
	else:
		print("Debug: No local player found!")

func _debug_print_inventory():
	var local_player = _get_local_player()
	if local_player and local_player.get_inventory():
		var inventory = local_player.get_inventory()
		print("=== Inventory Debug ===")
		for i in range(inventory.slots.size()):
			var slot = inventory.get_slot(i)
			if slot and not slot.is_empty():
				print("Slot ", i, ": ", slot.item_id, " x", slot.quantity)
		print("=====================")
	else:
		print("No inventory found for local player")
