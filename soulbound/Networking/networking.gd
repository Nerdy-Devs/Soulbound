extends Node

const DEV = true
const PORT = 9009
const POSITION_SYNC_INTERVAL = 1.0 / 30.0

var multiplayer_peer = ENetMultiplayerPeer.new()
var url : String = "127.0.0.1"
var wizard_scene : PackedScene
var my_id = 1
var position_sync_timer : Timer

var player_instances = {}
var player_positions = {}
var player_animations = {}
var player_usernames = {}
var connected_peer_ids = []

func _ready():
	if DEV:
		url = "127.0.0.1"
	
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_server_connected)
	
	wizard_scene = preload("res://player_control/wizards/wizard.tscn")
	
	position_sync_timer = Timer.new()
	position_sync_timer.one_shot = false
	position_sync_timer.wait_time = POSITION_SYNC_INTERVAL
	add_child(position_sync_timer)
	position_sync_timer.connect("timeout", Callable(self, "_sync_wizards"))
	position_sync_timer.start()

### SERVER-INTEGRATED: HOST MODE ENTRYPOINT
func start_server():
	multiplayer_peer.close()
	multiplayer_peer.set_bind_ip("0.0.0.0")

	var error = multiplayer_peer.create_server(PORT, 8)
	if error != OK:
		push_error("Failed to start server: " + str(error))
		return

	multiplayer.multiplayer_peer = multiplayer_peer
	
	multiplayer_peer.peer_connected.connect(_on_peer_connected)
	multiplayer_peer.peer_disconnected.connect(_on_peer_disconnected)

	print("Server started, waiting for players...")

	# Spawn the local player (server host)
	my_id = 1
	var username : String = get_username()
	setup_player(my_id, Vector2(-1, -1), username)
	player_usernames[my_id] = username
	connected_peer_ids.append(my_id)


func connect_to_server(ip: String):
	url = ip
	multiplayer_peer.create_client(url, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	my_id = multiplayer_peer.get_unique_id()

func _on_server_connected():
	var username = get_username()
	rpc("update_player_username", my_id, username, true)
	setup_player(my_id, Vector2(-1,-1), username)
	rpc("join_game", my_id, username)

@rpc("any_peer")
func join_game(new_peer_id : int, username : String):
	if is_multiplayer_authority():
		connected_peer_ids.append(new_peer_id)
		print("Player " + str(new_peer_id) + " joined.")
		print("Currently connected Players: " + str(connected_peer_ids))
		
		var pose : Vector2 = Vector2(-1, -1)
		if player_positions.has(new_peer_id):
			pose = player_positions.get(new_peer_id)
		else:
			player_positions[new_peer_id] = pose

		# Server spawns the new player for itself
		if multiplayer.is_server():
			setup_player(new_peer_id, pose, username)

		# Tell all clients to spawn this new player
		rpc("spawn_player", new_peer_id, pose, username)

		# Tell the new player to spawn all existing players
		for id in connected_peer_ids:
			if id != new_peer_id:
				rpc_id(new_peer_id, "spawn_player", id, pose, player_usernames.get(id))


@rpc("any_peer")
func spawn_player(peer_id: int, pose: Vector2, username: String):
	if !player_instances.has(peer_id):
		setup_player(peer_id, pose, username)

func setup_player(peer_id: int, pose: Vector2, username: String):
	if pose == Vector2(-1, -1):
		pose = Vector2(randf_range(370, 860), 474)
	print("Spawning ", username, ": ", peer_id, " at ", pose)
	var player = wizard_scene.instantiate()
	player.name = "Player_" + str(peer_id)
	player.player_number = 1
	player.master_id = peer_id
	player.set_username(username)
	player.position = pose
	get_tree().root.add_child(player)
	player_instances[peer_id] = player

@rpc("any_peer")
func update_player_position(peer_id: int, position: Vector2):
	if player_instances.has(peer_id):
		var player = player_instances[peer_id]
		if peer_id == my_id:
			position = player.position
			rpc("update_player_position", my_id, position)
		else:
			player.position = position
	player_positions[peer_id] = position

@rpc("any_peer")
func update_animation(peer_id: int, animation: String, is_left: bool):
	if player_instances.has(peer_id):
		var player = player_instances[peer_id]
		if peer_id == my_id:
			animation = player.get_animation()
			rpc("update_animation", my_id, animation, player.is_left)
		else:
			player.set_animation(animation)
			player.is_left = is_left
	player_animations[peer_id] = animation

@rpc("any_peer")
func update_player_username(peer_id: int, username: String, joining: bool):
	player_usernames[peer_id] = username
	if !joining and player_instances.has(peer_id):
		player_instances[peer_id].set_username(username)

@rpc
func remove_player(peer_id: int):
	print("Removing: ", peer_id)
	if player_instances.has(peer_id):
		player_instances[peer_id].queue_free()
		player_instances.erase(peer_id)

@rpc
func sync_player_list(_ids): pass # Satisfy RPC requirements

func _sync_wizards():
	if player_instances.has(my_id):
		update_player_position(my_id, player_instances[my_id].position)
		update_animation(my_id, "", false)

func _on_peer_connected(new_peer_id: int):
	print("Player " + str(new_peer_id) + " is joining...")
	await get_tree().create_timer(1).timeout

func _on_peer_disconnected(leaving_peer_id: int):
	await get_tree().create_timer(1).timeout
	delete_player(leaving_peer_id)
	remove_player(leaving_peer_id)
	rpc("remove_player", leaving_peer_id)
	player_positions.erase(leaving_peer_id)
	player_usernames.erase(leaving_peer_id)
	player_animations.erase(leaving_peer_id)

func delete_player(id: int):
	var idx = connected_peer_ids.find(id)
	if idx != -1:
		connected_peer_ids.remove_at(idx)
	print("Player " + str(id) + " disconnected.")
	print("Connected: " + str(connected_peer_ids))
	rpc("sync_player_list", connected_peer_ids)

func update_list():
	if has_node("Player List"):
		$"Player List".clear()
		for id in connected_peer_ids:
			$"Player List".add_item(str(id) + ": " + player_usernames.get(id) + ", Position: " + str(player_positions.get(id)))

func _on_server_disconnected():
	remove_player(my_id)
	multiplayer_peer.close()

func _on_connect_btn_pressed():
	if !$"Server IP".text.is_empty():
		connect_to_server($"Server IP".text)
	else: connect_to_server(url)

func _on_username_text_submitted(_text: String):
	var username = get_username()
	if player_instances.has(my_id):
		player_instances[my_id].set_username(username)
		player_instances[my_id].text_focused = false
		player_usernames.set(my_id, username)
		print(player_usernames)
		rpc("update_player_username", my_id, username, false)

func _on_username_text_changed(_text: String):
	if player_instances.has(my_id):
		player_instances[my_id].text_focused = true

func get_username() -> String:
	return $Username.text if not $Username.text.is_empty() else $Username.placeholder_text
