extends Node

const PORT = 27777 ## Default Port
const DEFAULT_SERVER_IP = "127.0.0.1"
const MAX_PLAYERS = 4

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players = {}

# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
# For example, the value of "name" can be set to something the player
# entered in a UI scene.
var player_info = {"name": "Name"}

var players_loaded = 0

## Signals
signal player_connected(id)
signal player_disconnected(id)
signal server_disconnected

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func join_game(address = "127.0.0.1"):
	print("join_game() called, connecting to ", address)

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, 27777)

	if error != OK:
		print("Failed to create client! Error code: ", error)
		return error

	multiplayer.multiplayer_peer = peer
	print("Client connection attempt started.")
	print("Multiplayer Peer:", multiplayer.multiplayer_peer)


	
func create_game():
	print("Starting Server")
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(27777, MAX_PLAYERS)

	if error != OK:
		print("Failed to create server! Error code: ", error)
		return error

	multiplayer.multiplayer_peer = peer
	print("Server started successfully!")
	print("Multiplayer Peer:", multiplayer.multiplayer_peer)



func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null
	players.clear()
	

# When the server decides to start the game from a UI scene,
# do Lobby.load_game.rpc(filepath)
@rpc("call_local", "reliable")
func load_game(game_scene_path):
	get_tree().change_scene_to_file(game_scene_path)

@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if multiplayer.is_server():
		players_loaded += 1
		if players_loaded == players.size():
			$/root/maps/map_1/Map_1.start()
			players_loaded = 0
			
# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(id):
	print("Player connected with ID: ", id)
	_register_player.rpc_id(id, player_info)

	
	_register_player.rpc_id(id, player_info)
	
	# Ensure the server spawns the new player
	if multiplayer.is_server():
		spawn_player.rpc(id)


@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)

	# Send existing player data to the new player
	for id in players.keys():
		if id != new_player_id:
			spawn_player.rpc_id(new_player_id, id)

	
func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_ok():
	print("Connected to server successfully!")  # <- Check if this prints
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)


func _on_connected_fail():
	multiplayer.multiplayer_peer = null
	
func _on_server_disconnected():
	print("Server disconnected!")
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

	
@rpc("any_peer", "reliable")
func spawn_player(id):
	print("spawing player", id)
	if not multiplayer.is_server():
		print("Not Multiplayer")
		return
	
	var player_scene = preload("res://player_control/wizards/wizard.tscn")
	var player_instance = player_scene.instantiate()
	
	player_instance.name = str(id)  # Unique name for the player
	player_instance.player_number = id  # Assign network ID
	player_instance.position = Vector2(100 * id, 300)  # Adjust spawn position
	
	get_tree().current_scene.add_child(player_instance)  # Add to the game scene
	
	player_instance.set_multiplayer_authority(id)  # Assign ownership
