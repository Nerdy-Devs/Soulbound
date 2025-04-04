extends Node

const DEV = true

var multiplayer_peer = ENetMultiplayerPeer.new()
var url : String = "127.0.0.1"
const PORT = 9009
var wizard_scene : PackedScene  # Reference to the player scene
var my_id
## Interval to update clients with player positions (e.g., every 1/30th of a second)
const POSITION_SYNC_INTERVAL = 1.0 / 30.0
var position_sync_timer : Timer

## Track player instances by their peer ID
var player_instances = {}
## Track the previous player pose to see whether to update it or not
var previous_positions = {}

var connected_peer_ids = []

func _ready():
	if DEV == true:
		url = "127.0.0.1"
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Preload the wizard scene (player prefab) here
	wizard_scene = preload("res://player_control/wizards/wizard.tscn")  # Change path accordingly
	
	# Set up the timer to sync positions every few milliseconds
	position_sync_timer = Timer.new()
	position_sync_timer.one_shot = false  # Repeat the timer
	position_sync_timer.wait_time = POSITION_SYNC_INTERVAL
	add_child(position_sync_timer)  # Add it to the scene tree

	# Correctly connect the timeout signal
	position_sync_timer.connect("timeout", Callable(self, "_sync_wizards"))

	# Start the timer
	position_sync_timer.start()

@rpc
func sync_player_list(updated_connected_peer_ids):
	# Ensure peer ID list matches across all clients
	connected_peer_ids = updated_connected_peer_ids
	print("Currently connected Players: " + str(connected_peer_ids))

@rpc
func spawn_player(peer_id: int, pose : Vector2):
	# Ensure spawn behavior is correct when syncing with peers
	if !player_instances.has(peer_id):
		if pose.x == -1 and pose.y == -1:
			print("NEW PLAYER")
			pose = Vector2(randf_range(370, 860), 474)
		print("Spawing ", peer_id, " at ", pose)
		var player_instance = wizard_scene.instantiate()
		player_instance.name = "Player_" + str(peer_id)
		player_instance.player_number = 1
		player_instance.master_id = peer_id
		#player_instance.set_network_master(peer_id)  # Assign this player to the correct peer

		# Set a random spawn position (you can modify this based on your needs)
		player_instance.position = pose

		# Add the player instance to the scene tree
		get_tree().root.add_child(player_instance)
		player_instances[peer_id] = player_instance  # Track the player by peer_id
		print("Player " + str(peer_id) + " spawned.")
	
func _sync_wizards():
	if player_instances.has(my_id):
		update_player_position(my_id, player_instances.get(my_id).position)
		update_animation(my_id, "", false)
	pass
	
@rpc("any_peer")
func update_player_position(peer_id: int, position: Vector2):
	# Handle updating the player's position locally
	if player_instances.has(peer_id):
		var player_instance = player_instances[peer_id]
		if peer_id == my_id:
			position = player_instance.position
			rpc("update_player_position", my_id, position)
		else:
			player_instance.set_pose(position) # Update the position of the player

@rpc("any_peer")
func update_animation(peer_id : int, animation : String, is_left : bool):
	if player_instances.has(peer_id):
		var player_instance = player_instances.get(peer_id)
		if peer_id == my_id:
			animation = player_instance.get_animation()
			rpc("update_animation", my_id, animation, player_instance.is_left)
		else:
			player_instance.set_animation(animation)
			player_instance.is_left = is_left

func _on_connect_btn_pressed() -> void:
	if !$"Server IP".text.is_empty():
		url = $"Server IP".text
	print("Connecting to, ", url, " ...")
	multiplayer_peer.create_client(url, PORT)
	my_id = multiplayer_peer.get_unique_id()
	multiplayer.multiplayer_peer = multiplayer_peer

func _on_disconnect_btn_pressed():
	multiplayer_peer.close()
	print("Disconnected.")

func _on_server_disconnected():
	multiplayer_peer.close()
	print("Connection to server lost.")
	
@rpc
func remove_player(peer_id: int):
	if player_instances.has(peer_id):
		player_instances[peer_id].queue_free()  # Remove from scene
		player_instances.erase(peer_id)  # Remove from dictionary
