extends Node

const PORT = 9009
var multiplayer_peer = ENetMultiplayerPeer.new()

# Store the positions of players by their peer ID
var player_positions = {}

# Interval to update clients with player positions (e.g., every 1/30th of a second)
const POSITION_SYNC_INTERVAL = 1.0 / 30.0
var position_sync_timer : Timer
var connected_peer_ids = []

func _ready():
	# Start the server
	var error = multiplayer_peer.create_server(PORT)
	if error != OK:
		push_error("Failed to start server: " + str(error))
		return
	
	multiplayer.multiplayer_peer = multiplayer_peer
	multiplayer_peer.peer_connected.connect(_on_peer_connected)
	multiplayer_peer.peer_disconnected.connect(_on_peer_disconnected)
	
	print("Server started, waitingn for players...")

	# Set up the timer to sync positions every few milliseconds
	position_sync_timer = Timer.new()
	position_sync_timer.one_shot = false  # Repeat the timer
	position_sync_timer.wait_time = POSITION_SYNC_INTERVAL
	add_child(position_sync_timer)  # Add it to the scene tree
	
	# Correctly connect the timeout signal
	position_sync_timer.connect("timeout", Callable(self, "_sync_positions"))

	# Start the timer
	position_sync_timer.start()

func _on_peer_connected(new_peer_id : int) -> void:
	print("Player " + str(new_peer_id) + " is joining...")
	# The connect signal fires before the client is added to the connected
	# clients in multiplayer.get_peers(), so we wait for a moment.
	await get_tree().create_timer(1).timeout
	player_positions[new_peer_id] = Vector2(0, 0)  # Initialize player position at (0, 0)
	add_player(new_peer_id)

func add_player(new_peer_id : int) -> void:
	connected_peer_ids.append(new_peer_id)
	print("Player " + str(new_peer_id) + " joined.")
	print("Currently connected Players: " + str(connected_peer_ids))
	rpc("sync_player_list", connected_peer_ids)
	rpc("spawn_player", new_peer_id)
	for id in connected_peer_ids:
		if id != new_peer_id:
			rpc_id(new_peer_id, "spawn_player", id)

func _on_peer_disconnected(leaving_peer_id : int) -> void:
	# The disconnect signal fires before the client is removed from the connected
	# clients in multiplayer.get_peers(), so we wait for a moment.
	await get_tree().create_timer(1).timeout
	remove_player(leaving_peer_id)
	player_positions.erase(leaving_peer_id)

func remove_player(leaving_peer_id : int) -> void:
	var peer_idx_in_peer_list : int = connected_peer_ids.find(leaving_peer_id)
	if peer_idx_in_peer_list != -1:
		connected_peer_ids.remove_at(peer_idx_in_peer_list)
	print("Player " + str(leaving_peer_id) + " disconnected.")
	print("Currently connected Players: " + str(connected_peer_ids))
	rpc("sync_player_list", connected_peer_ids)

@rpc
func sync_player_list(_updated_connected_peer_ids):
	# This method syncs the list of connected peers
	# The server may not need implementation but it must exist for the client
	pass

@rpc 
func spawn_player(_peer_id: int):
	# This is just a placeholder to satisfy RPC requirement
	# The actual logic is handled on the client side
	pass
	
# This method syncs the positions of all players to all clients
func _sync_positions():
	# Send the player positions to all clients
	for peer_id in player_positions.keys():
		rpc("update_player_position", peer_id, player_positions[peer_id])

# The client will receive this and update the player’s position
# Server-side function to handle position updates from a client
@rpc
func update_player_position(peer_id: int, position: Vector2):
	print("Received position from Player " + str(peer_id) + ": " + str(position))
	
	# Update the player's position locally on the server (you can store this in a dictionary)
	player_positions[peer_id] = position
	
	# Now send this position update to all other connected clients
	for other_peer_id in player_positions.keys():
		if other_peer_id != peer_id:
			rpc_id(other_peer_id, "update_player_position", peer_id, position)
