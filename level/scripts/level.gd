extends Node3D

@onready var skin_input: LineEdit = $Menu/MainContainer/MainMenu/Option2/SkinInput
@onready var nick_input: LineEdit = $Menu/MainContainer/MainMenu/Option1/NickInput
@onready var address_input = $Menu/MainContainer/MainMenu/Option3/AddressInput
@onready var players_container = $PlayersContainer
@onready var menu = $Menu
@export var player_scene : PackedScene

func _ready():
	if not multiplayer.is_server():
		return
		
	#multiplayer.peer_connected.connect(_add_player)
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
	Network.start_host()

func _on_join_pressed():
	menu.hide()
	Network.join_game(address_input.text.strip_edges(), nick_input.text.strip_edges(), skin_input.text.strip_edges())
	
func _add_player(id: int, player_info : Dictionary):
	if players_container.has_node(str(id)) or not multiplayer.is_server() or id == 1:
		return

	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = get_spawn_point()
	players_container.add_child(player, true)
	
	var nick = Network.players[id]["nick"]
	player.rpc("change_nick", nick)
	
	var skin_name = player_info["skin"]
	rpc("sync_player_skin", id, skin_name)
	
	if multiplayer.is_server():
		rpc("sync_player_position", id, player.position)
		
func get_spawn_point():
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 10 # SPAWN_RADIUS
	return Vector3(spawn_point.x, 0, spawn_point.y)
	
func _remove_player(id):
	if not multiplayer.is_server():
		return
	
	if not players_container.has_node(str(id)):
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
func sync_player_skin(id: int, skin_name: String):
	if id == 1: # ignore host
		return
	var player = players_container.get_node(str(id))
	if player:
		player.set_player_skin(skin_name)
		
func _on_quit_pressed() -> void:
	get_tree().quit()
	
