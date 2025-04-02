extends Node

const DEV = true

var multiplayer_peer = ENetMultiplayerPeer.new()
var url : String = "your-prod.url"
const PORT = 9009
var wizard_scene : PackedScene  # Reference to the player scene

var connected_peer_ids = []

func _ready():
	if DEV == true:
		url = "127.0.0.1"
	update_connection_buttons()
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Preload the wizard scene (player prefab) here
	wizard_scene = preload("res://player_control/wizards/wizard.tscn")  # Change path accordingly

@rpc
func sync_player_list(updated_connected_peer_ids):
	# Ensure peer ID list matches across all clients
	connected_peer_ids = updated_connected_peer_ids
	print("Currently connected Players: " + str(connected_peer_ids))
	update_connection_buttons()

@rpc
func spawn_player(peer_id : int):
	# Ensure spawn behavior is correct when syncing with peers
	var player_instance = wizard_scene.instantiate()
	player_instance.name = "Player_" + str(peer_id)
	player_instance.player_number = 1
	#player_instance.set_network_master(peer_id)  # Assign this player to the correct peer

	# Set a random spawn position (you can modify this based on your needs)
	player_instance.position = Vector2(randf_range(-500, 500), randf_range(-500, 500))

	# Add the player instance to the scene tree
	get_tree().root.add_child(player_instance)
	print("Player " + str(peer_id) + " spawned.")

func _on_connect_btn_pressed() -> void:
	print("Connecting ...")
	multiplayer_peer.create_client(url, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	update_connection_buttons()

func _on_disconnect_btn_pressed():
	multiplayer_peer.close()
	update_connection_buttons()
	print("Disconnected.")

func _on_server_disconnected():
	multiplayer_peer.close()
	update_connection_buttons()
	print("Connection to server lost.")

func update_connection_buttons() -> void:
	# Update UI buttons for connect/disconnect based on state
	pass
