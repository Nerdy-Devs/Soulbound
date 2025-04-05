extends Node

const DEV = true

var multiplayer_peer = ENetMultiplayerPeer.new()
var url : String = "127.0.0.1"
const PORT = 9009
var wizard_scene : PackedScene  ## Reference to the player scene
var my_id = 1
## Interval to update clients with player positions (e.g., every 1/30th of a second)
const POSITION_SYNC_INTERVAL = 1.0 / 30.0
var position_sync_timer : Timer

## Track player instances by their peer ID
var player_instances = {}

## Store the positions of players by their peer ID
var player_positions = {}
var player_animations = {}
var player_usernames = {}

var connected_peer_ids = []

func _ready():
	if DEV == true:
		url = "127.0.0.1"
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_server_connected)


	# Preload the wizard scene (player prefab) here
	wizard_scene = preload("res://player_control/wizards/wizard.tscn")  # Change path accordingly
	
	# Set up the timer to sync positions every few milliseconds
	position_sync_timer = Timer.new()
	position_sync_timer.one_shot = false  # Repeat the timer
	position_sync_timer.wait_time = POSITION_SYNC_INTERVAL
	add_child(position_sync_timer)  # Add it to the scene treed

	# Correctly connect the timeout signal
	position_sync_timer.connect("timeout", Callable(self, "_sync_wizards"))

	# Start the timer
	position_sync_timer.start()

func start_server():
	# Start the server
	var error = multiplayer_peer.create_server(PORT)
	if error != OK:
		push_error("Failed to start server: " + str(error))
		return
	
	multiplayer.multiplayer_peer = multiplayer_peer
	
	multiplayer_peer.peer_connected.connect(_on_peer_connected)
	multiplayer_peer.peer_disconnected.connect(_on_peer_disconnected)
	
	print("Server started, waitingn for players...")
	_on_server_connected()
	
@rpc("any_peer")
func spawn_player(peer_id: int, pose : Vector2, username : String):
	# Ensure spawn behavior is correct when syncing with peers
	if !player_instances.has(peer_id):
		setup_player(peer_id, pose, username)

	
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
			player_instance.position = position # Update the position of the player

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
	multiplayer_peer.create_client(url, PORT)
	my_id = multiplayer_peer.get_unique_id()
	multiplayer.multiplayer_peer = multiplayer_peer

func _on_server_disconnected():
	remove_player(my_id)
	multiplayer_peer.close()
	
func _on_server_connected():
	var username : String = get_username()
	rpc("update_player_username", my_id, username, true)
	setup_player(my_id, Vector2(-1,-1), username)
	rpc("join_game", my_id, username)
	
func setup_player(peer_id: int, pose : Vector2, username : String):
	if pose.x == -1 and pose.y == -1:
		pose = Vector2(randf_range(370, 860), 474)
	print("Spawing ", username, ": ", peer_id, " at ", pose)
	var player_instance = wizard_scene.instantiate()
	player_instance.name = "Player_" + str(peer_id)
	player_instance.player_number = 1
	player_instance.master_id = peer_id
	player_instance.set_username(username)
	
	# Set a random spawn position (you can modify this based on your needs)
	player_instance.position = pose

	# Add the player instance to the scene tree
	get_tree().root.add_child(player_instance)
	player_instances.set(peer_id, player_instance)  # Track the player by peer_id
	
@rpc("any_peer")
func update_player_username(peer_id : int, username : String, joining : bool):
	player_usernames.set(peer_id, username)
	if !joining:
		player_instances.get(peer_id).set_username(username)

@rpc("any_peer")
func join_game(new_peer_id : int, username : String):
	if is_multiplayer_authority():
		print("AUTHORITY")
		connected_peer_ids.append(new_peer_id)
		print("Player " + str(new_peer_id) + " joined.")
		print("Currently connected Players: " + str(connected_peer_ids))
		var pose : Vector2
		# Sets `pose` to the correct position
		if !player_positions.has(new_peer_id):
			pose = Vector2(-1, -1)
			player_positions.set(new_peer_id, pose)
		else:
			pose = player_positions.get(new_peer_id)
		rpc("spawn_player", new_peer_id, pose, username)
		for id in connected_peer_ids:
			if id != new_peer_id:
				rpc_id(new_peer_id, "spawn_player", id, pose, player_usernames.get(id))

@rpc
func remove_player(peer_id: int):
	if player_instances.has(peer_id):
		player_instances[peer_id].queue_free()  # Remove from scene
		player_instances.erase(peer_id)  # Remove from dictionary


func _on_username_text_submitted(_new_text: String) -> void:
	var username : String = get_username()
	player_instances.get(my_id).text_focused = false
	if player_instances.has(my_id):
		player_instances.get(my_id).set_username(username)
	rpc("update_player_username", my_id, username, false)

func get_username() -> String:
	var username
	if $Username.text.is_empty():
		username = $Username.placeholder_text
	else: username = $Username.text
	
	print("MY USERNAME IS: ", username)
	
	return username

func delete_player(leaving_peer_id : int) -> void:
	var peer_idx_in_peer_list : int = connected_peer_ids.find(leaving_peer_id)
	if peer_idx_in_peer_list != -1:
		connected_peer_ids.remove_at(peer_idx_in_peer_list)
	print("Player " + str(leaving_peer_id) + " disconnected.")
	print("Currently connected Players: " + str(connected_peer_ids))
	rpc("sync_player_list", connected_peer_ids)

func connections() -> void:
	for instance in player_instances:
		print(instance) # Replace with function body.
		
func _on_username_text_changed(_new_text: String) -> void:
	if player_instances.has(my_id):
		player_instances.get(my_id).text_focused = true

func _on_peer_connected(new_peer_id : int) -> void:
	print("Player " + str(new_peer_id) + " is joining...")
	# The connect signal fires before the client is added to the connected
	# clients in multiplayer.get_peers(), so we wait for a moment.
	await get_tree().create_timer(1).timeout
	#add_player(new_peer_id, "new_player")

func _on_peer_disconnected(leaving_peer_id : int) -> void:
	# The disconnect signal fires before the client is removed from the connected
	# clients in multiplayer.get_peers(), so we wait for a moment.
	await get_tree().create_timer(1).timeout
	delete_player(leaving_peer_id)
	rpc("remove_player", leaving_peer_id)
	player_positions.erase(leaving_peer_id)
	player_usernames.erase(leaving_peer_id)
	player_animations.erase(leaving_peer_id)
