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

@export var host_as_player : bool = true

var chat_visible = false

func _ready():
	multiplayer_chat.hide()
	menu.show()
	multiplayer_chat.set_process_input(true)
	if not multiplayer.is_server():
		return
		
	Network.connect("player_connected", Callable(self, "_on_player_connected"))
	multiplayer.peer_disconnected.connect(_remove_player)
	
func _on_player_connected(peer_id, player_info):
	for id in Network.players.keys():
		var player_data = Network.players[id]
		if id != peer_id:
			rpc_id(peer_id, "sync_player_skin", id, player_data["skin"])
			
	_add_player(peer_id, player_info)
	
func _on_host_pressed():
	menu.hide()
	Network.start_host(nick_input.text.strip_edges(), skin_input.text.strip_edges().to_lower(), host_as_player)

func _on_join_pressed():
	menu.hide()
	Network.join_game(nick_input.text.strip_edges(), skin_input.text.strip_edges().to_lower(), address_input.text.strip_edges())
	
func _add_player(id: int, player_info : Dictionary):
	if players_container.has_node(str(id)):
		return
	if !host_as_player and (not multiplayer.is_server() or id == 1):
		return
	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = get_spawn_point()
	players_container.add_child(player, true)
	
	if multiplayer.is_server() and !host_as_player:
		player._camera.current = false
	
	var nick = Network.players[id]["nick"]
	player.rpc("change_nick", nick)
	
	var skin_enum = player_info["skin"]
	rpc("sync_player_skin", id, skin_enum)
	
	rpc("sync_player_position", id, player.position)
	
func get_spawn_point() -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 10 # spawn radius
	return Vector3(spawn_point.x, 0, spawn_point.y)
	
func _remove_player(id):
	if not multiplayer.is_server() or not players_container.has_node(str(id)):
		return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()
		
@rpc("any_peer", "call_local")
func sync_player_position(id: int, new_position: Vector3):
	var player = players_container.get_node(str(id))
	if player:
		player.position = new_position
		
@rpc("any_peer", "call_local")
func sync_player_skin(id: int, skin_color: Character.SkinColor):
	if id == 1 and !host_as_player: return # ignore host
	var player = players_container.get_node(str(id))
	if player:
		player.set_player_skin(skin_color)
		
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
	elif event is InputEventKey and event.keycode == KEY_ENTER:
		_on_send_pressed()

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
