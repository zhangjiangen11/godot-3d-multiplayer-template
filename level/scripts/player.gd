extends CharacterBody3D
class_name Character

const NORMAL_SPEED = 6.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 10

enum SkinColor { BLUE, YELLOW, GREEN, RED }

@onready var nickname: Label3D = $PlayerNick/Nickname

var player_inventory: PlayerInventory

@export_category("Objects")
@export var _body: Node3D = null
@export var _spring_arm_offset: Node3D = null

@export_category("Skin Colors")
@export var blue_texture : CompressedTexture2D
@export var yellow_texture : CompressedTexture2D
@export var green_texture : CompressedTexture2D
@export var red_texture : CompressedTexture2D

@onready var _bottom_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Bottom")
@onready var _chest_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Chest")
@onready var _face_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Face")
@onready var _limbs_head_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head")

var _current_speed: float
var _respawn_point = Vector3(0, 5, 0)
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	$SpringArmOffset/SpringArm3D/Camera3D.current = is_multiplayer_authority()

func _ready():
	if is_multiplayer_authority():
		player_inventory = PlayerInventory.new()
		# Add some starting items for testing
		_add_starting_items()
		print("Debug: Client-side player inventory initialized for player ", name)
	elif multiplayer.is_server():
		# Server-side: Always create inventory for all players (including clients)
		player_inventory = PlayerInventory.new()
		_add_starting_items()
		print("Debug: Server-side player inventory initialized for player ", name, " (client ", get_multiplayer_authority(), ")")
	else:
		# Client-side for other players: Request inventory sync from server
		request_inventory_sync.rpc_id(1)
		print("Debug: Requested inventory sync for player ", name)

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	var current_scene = get_tree().get_current_scene()
	if current_scene and is_on_floor():
		# Freeze movement if chat or inventory is visible
		var should_freeze = false
		if current_scene.has_method("is_chat_visible") and current_scene.is_chat_visible():
			should_freeze = true
		elif current_scene.has_method("is_inventory_visible") and current_scene.is_inventory_visible():
			should_freeze = true
		
		if should_freeze:
			freeze()
			return

	if not is_on_floor():
		velocity.y -= gravity * delta
		_body.animate(velocity)

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= gravity * delta

	_move()
	move_and_slide()
	_body.animate(velocity)

func _process(_delta):
	if not is_multiplayer_authority(): return
	_check_fall_and_respawn()

func freeze():
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	_body.animate(Vector3.ZERO)

func _move() -> void:
	var _input_direction: Vector2 = Vector2.ZERO
	if is_multiplayer_authority():
		_input_direction = Input.get_vector(
			"move_left", "move_right",
			"move_forward", "move_backward"
			)

	var _direction: Vector3 = transform.basis * Vector3(_input_direction.x, 0, _input_direction.y).normalized()

	is_running()
	_direction = _direction.rotated(Vector3.UP, _spring_arm_offset.rotation.y)

	if _direction:
		velocity.x = _direction.x * _current_speed
		velocity.z = _direction.z * _current_speed
		_body.apply_rotation(velocity)
		return

	velocity.x = move_toward(velocity.x, 0, _current_speed)
	velocity.z = move_toward(velocity.z, 0, _current_speed)

func is_running() -> bool:
	if Input.is_action_pressed("shift"):
		_current_speed = SPRINT_SPEED
		return true
	else:
		_current_speed = NORMAL_SPEED
		return false

func _check_fall_and_respawn():
	if global_transform.origin.y < -15.0:
		_respawn()

func _respawn():
	global_transform.origin = _respawn_point
	velocity = Vector3.ZERO

@rpc("any_peer", "reliable")
func change_nick(new_nick: String):
	if nickname:
		nickname.text = new_nick

func get_texture_from_name(skin_color: SkinColor) -> CompressedTexture2D:
	match skin_color:
		SkinColor.BLUE: return blue_texture
		SkinColor.GREEN: return green_texture
		SkinColor.RED: return red_texture
		SkinColor.YELLOW: return yellow_texture
		_: return blue_texture

@rpc("any_peer", "reliable")
func set_player_skin(skin_name: SkinColor) -> void:
	var texture = get_texture_from_name(skin_name)

	set_mesh_texture(_bottom_mesh, texture)
	set_mesh_texture(_chest_mesh, texture)
	set_mesh_texture(_face_mesh, texture)
	set_mesh_texture(_limbs_head_mesh, texture)

func set_mesh_texture(mesh_instance: MeshInstance3D, texture: CompressedTexture2D) -> void:
	if mesh_instance:
		var material := mesh_instance.get_surface_override_material(0)
		if material and material is StandardMaterial3D:
			var new_material := material
			new_material.albedo_texture = texture
			mesh_instance.set_surface_override_material(0, new_material)

# Inventory Network Functions - Server authoritative, client-specific
@rpc("any_peer", "call_local", "reliable")
func request_inventory_sync():
	print("Debug: request_inventory_sync called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())
	
	# Only the server can handle this request
	if not multiplayer.is_server():
		print("Debug: Not on server, ignoring sync request")
		return
	
	var requesting_client = multiplayer.get_remote_sender_id()
	# Validate that the requesting client is asking for their own player's inventory
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to request inventory for player " + str(get_multiplayer_authority()))
		return
		
	if player_inventory:
		# Send inventory data only to the requesting client
		sync_inventory_to_owner.rpc_id(requesting_client, player_inventory.to_dict())

@rpc("any_peer", "call_local", "reliable")
func sync_inventory_to_owner(inventory_data: Dictionary):
	print("Debug: sync_inventory_to_owner called on player ", name, " (authority: ", get_multiplayer_authority(), ") - local unique id: ", multiplayer.get_unique_id(), " from: ", multiplayer.get_remote_sender_id())
	
	# Only allow server to send inventory updates
	if multiplayer.get_remote_sender_id() != 1:
		print("Debug: Ignoring inventory sync from non-server peer: ", multiplayer.get_remote_sender_id())
		return
	
	# Only the owning client should process this (not other clients)
	if not is_multiplayer_authority():
		print("Debug: Not the owning client, ignoring inventory sync")
		return
	
	if not player_inventory:
		player_inventory = PlayerInventory.new()
	player_inventory.from_dict(inventory_data)
	
	# Update the client's inventory UI if it's open
	var level_scene = get_tree().get_current_scene()
	if level_scene:
		# Check if this is the local player's inventory being updated
		if is_multiplayer_authority() or get_multiplayer_authority() == multiplayer.get_unique_id():
			print("Debug: This is the local player, updating UI")
			if level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()
			# Also directly update the inventory UI if it exists and is visible
			if level_scene.has_node("InventoryUI"):
				var inventory_ui = level_scene.get_node("InventoryUI")
				if inventory_ui.visible and inventory_ui.has_method("refresh_display"):
					print("Debug: Calling refresh_display directly on InventoryUI")
					inventory_ui.refresh_display()
		else:
			print("Debug: Not the local player, skipping UI update")

@rpc("any_peer", "call_local", "reliable")
func request_move_item(from_slot: int, to_slot: int, quantity: int = -1):
	print("Debug: request_move_item called - from:", from_slot, " to:", to_slot, " on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())
	
	# Only server handles inventory operations - check if we're on the server
	if not multiplayer.is_server():
		print("Debug: Not on server, ignoring move request")
		return
	
	# Validate that the requesting client owns this player
	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to modify inventory for player " + str(get_multiplayer_authority()))
		return
	
	if not player_inventory:
		print("Debug: No player inventory found for move")
		return
	
	# Validate slot indices
	if from_slot < 0 or from_slot >= PlayerInventory.INVENTORY_SIZE or to_slot < 0 or to_slot >= PlayerInventory.INVENTORY_SIZE:
		push_warning("Invalid slot indices: from=" + str(from_slot) + " to=" + str(to_slot))
		return
	
	var success = false
	if quantity == -1:
		success = player_inventory.move_item(from_slot, to_slot)
		if not success:
			success = player_inventory.swap_items(from_slot, to_slot)
			print("Debug: Swapped items between slots ", from_slot, " and ", to_slot)
		else:
			print("Debug: Moved item from slot ", from_slot, " to ", to_slot)
	else:
		success = player_inventory.move_item(from_slot, to_slot, quantity)
		print("Debug: Moved ", quantity, " items from slot ", from_slot, " to ", to_slot)
	
	if success:
		print("Debug: Move successful, syncing inventory to owner ", get_multiplayer_authority())
		# Send updated inventory only to this player's client
		var owner_id = get_multiplayer_authority()
		if owner_id != 1:  # If not the server itself
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())
		else:
			# If this is the server player, update directly
			var level_scene = get_tree().get_current_scene()
			if level_scene and level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()
	else:
		print("Debug: Move/swap failed")

@rpc("any_peer", "call_local", "reliable")
func request_add_item(item_id: String, quantity: int = 1):
	print("Debug: request_add_item called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())
	
	if not multiplayer.is_server():
		print("Debug: Not on server, ignoring request")
		return
	
	# Validate that the requesting client owns this player (for admin/pickup scenarios)
	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority() and requesting_client != 1:  # Allow server to add items
		push_warning("Client " + str(requesting_client) + " tried to add items to player " + str(get_multiplayer_authority()))
		return
	
	if not player_inventory:
		print("Debug: No player inventory found")
		return
	
	# Validate item exists and quantity is positive
	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return
		
	var item = ItemDatabase.get_item(item_id)
	if not item:
		push_warning("Item not found: " + item_id)
		return
	
	var remaining = player_inventory.add_item(item, quantity)
	var added = quantity - remaining
	print("Debug: Added ", added, " ", item_id, " to inventory (", remaining, " remaining)")
	
	if added > 0:
		# Send updated inventory only to this player's client
		var owner_id = get_multiplayer_authority()
		print("Debug: Syncing inventory to owner ", owner_id)
		if owner_id != 1:  # If not the server itself
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())
		else:
			# If this is the server player, update directly
			var level_scene = get_tree().get_current_scene()
			if level_scene and level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()

@rpc("any_peer", "call_local", "reliable")
func request_remove_item(item_id: String, quantity: int = 1):
	print("Debug: request_remove_item called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())
	
	if not multiplayer.is_server():
		print("Debug: Not on server, ignoring request")
		return
	
	# Validate that the requesting client owns this player
	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to remove items from player " + str(get_multiplayer_authority()))
		return
	
	if not player_inventory:
		return
	
	# Validate quantity is positive
	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return
	
	var removed = player_inventory.remove_item(item_id, quantity)
	
	if removed > 0:
		# Send updated inventory only to this player's client
		var owner_id = get_multiplayer_authority()
		if owner_id != 1:  # If not the server itself
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())

func get_inventory() -> PlayerInventory:
	return player_inventory

func _add_starting_items():
	if not player_inventory:
		return
	
	# Add some starting items for testing
	var sword = ItemDatabase.get_item("iron_sword")
	var potion = ItemDatabase.get_item("health_potion")
	
	if sword:
		player_inventory.add_item(sword, 1)
	if potion:
		player_inventory.add_item(potion, 3)
