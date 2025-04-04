extends Node

const PORT = 9009
var multiplayer_peer = ENetMultiplayerPeer.new()

# Store the positions of players by their peer ID
var player_positions = {}
var player_animations = {}
var player_usernames = {}

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

func _on_peer_connected(new_peer_id : int) -> void:
	print("Player " + str(new_peer_id) + " is joining...")
	# The connect signal fires before the client is added to the connected
	# clients in multiplayer.get_peers(), so we wait for a moment.
	await get_tree().create_timer(1).timeout
	#add_player(new_peer_id, "new_player")
	

@rpc("any_peer")
func join_game(new_peer_id : int, username : String) -> void:
	connected_peer_ids.append(new_peer_id)
	print("Player " + str(new_peer_id) + " joined.")
	print("Currently connected Players: " + str(connected_peer_ids))
	rpc("sync_player_list", connected_peer_ids)
	var pose : Vector2
	# Sets `pose` to the correct position
	if !player_positions.has(new_peer_id):
		pose = Vector2(-1, -1)
		player_positions.set(new_peer_id, pose)
	else:
		pose = player_positions.get(new_peer_id)
	update_list()
	rpc("spawn_player", new_peer_id, pose, username)
	for id in connected_peer_ids:
		if id != new_peer_id:
			rpc_id(new_peer_id, "spawn_player", id, pose, player_usernames.get(id))

func _on_peer_disconnected(leaving_peer_id : int) -> void:
	# The disconnect signal fires before the client is removed from the connected
	# clients in multiplayer.get_peers(), so we wait for a moment.
	await get_tree().create_timer(1).timeout
	delete_player(leaving_peer_id)
	rpc("remove_player", leaving_peer_id)
	player_positions.erase(leaving_peer_id)
	player_usernames.erase(leaving_peer_id)
	player_animations.erase(leaving_peer_id)
	update_list()

func delete_player(leaving_peer_id : int) -> void:
	var peer_idx_in_peer_list : int = connected_peer_ids.find(leaving_peer_id)
	if peer_idx_in_peer_list != -1:
		connected_peer_ids.remove_at(peer_idx_in_peer_list)
	print("Player " + str(leaving_peer_id) + " disconnected.")
	print("Currently connected Players: " + str(connected_peer_ids))
	rpc("sync_player_list", connected_peer_ids)

@rpc
func remove_player(_leaving_peer_id : int) -> void:
	pass

@rpc
func sync_player_list(_updated_connected_peer_ids):
	# This method syncs the list of connected peers
	# The server may not need implementation but it must exist for the client
	pass

@rpc("any_peer")
func spawn_player(_peer_id: int, _pose : Vector2, _username : String):
	# This is just a placeholder to satisfy RPC requirement
	# The actual logic is handled on the client side
	pass


@rpc("any_peer")
func update_player_username(peer_id : int, username : String):
	player_usernames.set(peer_id, username)
	update_list()

## This method syncs the positions of all players to all clients
func _sync_positions():
	# Send the player positions to all clients
	for peer_id in player_positions.keys():
		rpc("update_player_position", peer_id, player_positions[peer_id])

## The client will receive this and update the player’s position
## Server-side function to handle position updates from a client
@rpc("any_peer")
func update_player_position(peer_id: int, position: Vector2):
	# Update the player's position locally on the server
	player_positions[peer_id] = position
	
@rpc("any_peer")
func update_animation(peer_id: int, animation: String, _is_left : bool):
	player_animations[peer_id] = animation

func update_list() -> void:
	$"Player List".clear()
	
	for id in connected_peer_ids:
		$"Player List".add_item(str(id) + ": " + player_usernames.get(id))
