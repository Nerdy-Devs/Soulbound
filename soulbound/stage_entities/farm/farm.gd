extends Area2D





func _on_body_entered(body):
	print("farm hit")
	print(body.isHolding)
	
	if(body.isHolding == false):
		body.isHolding = true
