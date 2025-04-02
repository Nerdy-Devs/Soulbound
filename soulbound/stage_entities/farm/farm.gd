extends Area2D



func _on_area_entered(area: Area2D) -> void:
	#gonna try and assign a variable to the farm that will read whether or not a player is holding the thing
	var x = get_overlapping_bodies()
	
