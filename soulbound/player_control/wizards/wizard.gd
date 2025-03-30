class_name Wizard

extends CharacterBody2D

var speed : int = 100
var screen_size
var controller_input : String
@export var player_number : int = -1

func _ready() -> void:
	screen_size = get_viewport_rect().size
	controller_input = "player_" + str(player_number)
	
func _process(delta: float) -> void:
	position = get_new_position(delta)
	
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
		$Wizard_Animated.animation = "jump"
		$Wizard_Animated.flip_h = velocity.x < 0
		
	# If the player is going left or right use the run animation
	elif velocity.x != 0:
		$Wizard_Animated.animation = "run"
		$Wizard_Animated.flip_h = velocity.x < 0

	# If the player isn't moving, use the idle animationasd
	if velocity.length() <= 0:
		$Wizard_Animated.animation = "idle"
	
	velocity = velocity.normalized() * speed
		
	$Wizard_Animated.play()
		
	new_pose += velocity * delta
	new_pose = new_pose.clamp(Vector2.ZERO, screen_size)
	return new_pose
