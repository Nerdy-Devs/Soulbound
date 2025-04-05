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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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
	
	print("Server started, waitingn for players...")

func _on_server_disconnected():
	remove_player(my_id)
	multiplayer_peer.close()
	
func _on_server_connected():
	my_id = multiplayer.get_unique_id()
	var username : String = get_username()
	rpc("update_player_username", my_id, username)
	spawn_player()
	rpc("join_game", my_id, username)
	
@rpc("any_peer")
func spawn_player():
	pass

func setup_player(peer_id : int, pose : Vector2, username : String):
	if pose == Vector2(-1, -1):
		pose = Vector2(randf_range(370, 860), 474)
	print("Spawing ", username, ": ", peer_id, " at ", pose)
	

func get_username() -> String:
	var username
	if $Username.text.is_empty():
		username = $Username.placeholder_text		
	else: username = $Username.text
	
	return username

## The client will receive this and update the player’s position
## Server-side function to handle position updates from a client
@rpc("any_peer")
func update_player_position(peer_id: int, position: Vector2):
	# Update the player's position locally on the server
	player_positions[peer_id] = position
	
@rpc("any_peer")
func update_animation(peer_id: int, animation: String, _is_left : bool):
	player_animations[peer_id] = animation

func remove_player(peer_id: int):
	if player_instances.has(peer_id):
		player_instances[peer_id].queue_free()  # Remove from scene
		player_instances.erase(peer_id)  # Remove from dictionary
