extends Node

const PORT = 62350
const MAX_PLAYERS = 4
var is_server = false

@onready var player_scene = preload("res://player_control/wizards/wizard.tscn")

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if DisplayServer.cli_has_option("server"):
		start_server()
	else:
		join_server("127.0.0.1") # Change to actual server IP if needed
	
func start_server():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	is_server = true
	print("Server started on port ", PORT)
	
func join_server(ip: String):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer
	print("Attempting to join server at ", ip)

func _on_peer_connected(id):
	print("Player connected: ", id)
	if is_server:
		var player = player_scene.instantiate()
		add_child(player)
		player.set_multiplayer_authority(id)

func _on_peer_disconnected(id):
	print("Player disconnected: ", id)
