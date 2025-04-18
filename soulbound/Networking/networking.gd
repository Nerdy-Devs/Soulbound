extends Node

const DEV = true
const PORT = 9009
const POSITION_SYNC_INTERVAL = 1.0 / 30.0

var multiplayer_peer = ENetMultiplayerPeer.new()
var url : String = "127.0.0.1"
var wizard_scene : PackedScene
var my_id = 1
var player_count = 2  # Number of players per client
var position_sync_timer : Timer

var player_instances = {} # key: "peer_id:player_number"
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

func make_key(peer_id: int, player_number: int) -> String:
	return str(peer_id) + ":" + str(player_number)

### SERVER-INTEGRATED: HOST MODE ENTRYPOINT
func start_server():
	for id in connected_peer_ids:
		remove_player(id)
		
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

	my_id = 1
	var username : String = get_username()
	for i in range(player_count):
		var pnum = i + 1
		var pose = Vector2(randf_range(370, 860), 474)
		setup_player(my_id, pose, username, pnum)
		var key = make_key(my_id, pnum)
		player_positions[key] = pose
		player_usernames[key] = username + "-" + str(pnum)
	
	connected_peer_ids.append(my_id)

func connect_to_server(ip: String):
	for id in connected_peer_ids:
		remove_player(id)
	multiplayer_peer.close()
	url = ip
	multiplayer_peer.create_client(url, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	my_id = multiplayer_peer.get_unique_id()

func _on_server_connected():
	var username = get_username()
	for i in range(player_count):
		var pnum = i + 1
		rpc("update_player_username", my_id, username, true, pnum)
		setup_player(my_id, Vector2(-1,-1), username, pnum)
		rpc("join_game", my_id, username, pnum)

@rpc("any_peer")
func join_game(new_peer_id : int, username : String, player_number : int):
	if is_multiplayer_authority():
		var key = make_key(new_peer_id, player_number)
		if !connected_peer_ids.has(new_peer_id):
			connected_peer_ids.append(new_peer_id)
		
		var pose : Vector2 = Vector2(randf_range(370, 860), 474)
		player_positions[key] = pose
		player_usernames[key] = username + "-" + str(player_number)

		if multiplayer.is_server():
			setup_player(new_peer_id, pose, username, player_number)

		rpc("spawn_player", new_peer_id, pose, username, player_number)

		# Send existing players to the new player
		for id in connected_peer_ids:
			for i in range(player_count):
				var pn = i + 1
				var other_key = make_key(id, pn)
				if id != new_peer_id and player_usernames.has(other_key):
					var uname = player_usernames[other_key]
					var pos = player_positions.get(other_key, Vector2(randf_range(370, 860), 474))
					rpc_id(new_peer_id, "spawn_player", id, pos, uname, pn)

@rpc("any_peer")
func spawn_player(peer_id: int, pose: Vector2, username: String, player_number: int):
	var key = make_key(peer_id, player_number)
	if !player_instances.has(key):
		setup_player(peer_id, pose, username, player_number)

func setup_player(peer_id: int, pose: Vector2, username: String, player_number: int):
	username = username + "-" + str(player_number)
	if pose == Vector2(-1, -1):
		pose = Vector2(randf_range(370, 860), 474)
	print("Spawning ", username, ": ", peer_id, "-", player_number, " at ", pose)
	var player = wizard_scene.instantiate()
	player.name = "Player_" + str(peer_id) + "_" + str(player_number)
	player.player_number = player_number
	player.master_id = peer_id
	player.set_username(username)
	player.position = pose
	get_tree().root.add_child(player)
	player_instances[make_key(peer_id, player_number)] = player

@rpc("any_peer")
func update_player_position(peer_id: int, position: Vector2, player_number: int):
	var key = make_key(peer_id, player_number)
	if player_instances.has(key):
		var player = player_instances[key]
		if peer_id == my_id:
			position = player.position
			rpc("update_player_position", my_id, position, player_number)
		else:
			player.position = position
	player_positions[key] = position

@rpc("any_peer")
func update_animation(peer_id: int, animation: String, is_left: bool, player_number: int):
	var key = make_key(peer_id, player_number)
	if player_instances.has(key):
		var player = player_instances[key]
		if peer_id == my_id:
			animation = player.get_animation()
			rpc("update_animation", my_id, animation, player.is_left, player_number)
		else:
			player.set_animation(animation)
			player.is_left = is_left
	player_animations[key] = animation

@rpc("any_peer")
func update_player_username(peer_id: int, username: String, joining: bool, player_number: int):
	var key = make_key(peer_id, player_number)
	player_usernames[key] = username + "-" + str(player_number)
	if !joining and player_instances.has(key):
		player_instances[key].set_username(username)

@rpc
func remove_player(peer_id: int):
	print("Removing: ", peer_id)
	for i in range(player_count):
		var key = make_key(peer_id, i + 1)
		if player_instances.has(key):
			player_instances[key].queue_free()
			player_instances.erase(key)

@rpc
func sync_player_list(_ids): pass # Satisfy RPC requirements

func _sync_wizards():
	for i in range(player_count):
		var key = make_key(my_id, i + 1)
		if player_instances.has(key):
			update_player_position(my_id, player_instances[key].position, i + 1)
			update_animation(my_id, "", false, i + 1)

func _on_peer_connected(new_peer_id: int):
	print("Player " + str(new_peer_id) + " is joining...")
	await get_tree().create_timer(1).timeout

func _on_peer_disconnected(leaving_peer_id: int):
	await get_tree().create_timer(1).timeout
	delete_player(leaving_peer_id)
	remove_player(leaving_peer_id)
	rpc("remove_player", leaving_peer_id)
	for i in range(player_count):
		var key = make_key(leaving_peer_id, i + 1)
		player_positions.erase(key)
		player_usernames.erase(key)
		player_animations.erase(key)

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
			for i in range(player_count):
				var key = make_key(id, i + 1)
				if player_usernames.has(key):
					$"Player List".add_item(str(key) + ": " + player_usernames[key] + ", Pos: " + str(player_positions.get(key)))

func _on_server_disconnected():
	remove_player(my_id)
	multiplayer_peer.close()

func _on_connect_btn_pressed():
	if !$"Server IP".text.is_empty():
		connect_to_server($"Server IP".text)
	else: connect_to_server(url)

func _on_username_text_submitted(_text: String):
	var username = get_username()
	for i in range(player_count):
		var key = make_key(my_id, i + 1)
		if player_instances.has(key):
			player_instances[key].set_username(username)
			player_instances[key].text_focused = false
			player_usernames.set(key, username + "-" + str(i + 1))
			rpc("update_player_username", my_id, username, false, i + 1)

func _on_username_text_changed(_text: String):
	for i in range(player_count):
		var key = make_key(my_id, i + 1)
		if player_instances.has(key):
			player_instances[key].text_focused = true

func get_username() -> String:
	return $Username.text if not $Username.text.is_empty() else $Username.placeholder_text
