extends Node

func spawn_debug_player():
	$Networking.spawn_player(-1, Vector2(-1, -1), "DEBUG")
