class_name Wizard

extends CharacterBody2D

var speed : int = 100
var screen_size
var animation_node : Node
var controller_input : String
	
func get_new_position(delta) -> Vector2:
	var new_pose : Vector2 = position
	velocity = Vector2.ZERO
	
	if Input.is_action_pressed(controller_input + "_move_up"):
		velocity.y -= 1
	if Input.is_action_pressed(controller_input + "_move_down"):
		velocity.y += 1
	if Input.is_action_pressed(controller_input + "_move_left"):
		velocity.x -= 1
	if Input.is_action_pressed(controller_input + "_move_right"):
		velocity.x += 1
	
	# If the player is going up/down, use the jump animation
	if velocity.y != 0:
		animation_node.animation = "jump"
		animation_node.flip_h = velocity.x < 0
		
	# If the player is going left or right use the run animation
	elif velocity.x != 0:
		animation_node.animation = "run"
		animation_node.flip_h = velocity.x < 0

	# If the player isn't moving, use the idle animationasd
	if velocity.length() <= 0:
		animation_node.animation = "idle"
	
	velocity = velocity.normalized() * speed
		
	animation_node.play()
		
	new_pose += velocity * delta
	new_pose = new_pose.clamp(Vector2.ZERO, screen_size)
	return new_pose

func setup(player_number: int) -> void:
	screen_size = get_viewport_rect().size
	controller_input = "player_" + str(player_number)
	animation_node = get_node("Wizard_Animated_" + str(player_number))
