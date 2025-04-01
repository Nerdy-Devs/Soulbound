class_name Wizard

extends CharacterBody2D

var speed : int = 100
var screen_size

## Which controller to use
var controller_input : String

## Player Number
##
## Allows the wizards to be controlled by different users
@export var player_number : int = -1

## Used to keep track of the direction the wizard is facing
var is_left : bool = false


func _ready() -> void:
	screen_size = get_viewport_rect().size
	controller_input = "player_" + str(player_number)
	
func _process(delta: float) -> void:
	position = get_new_position(delta)
	set_animation()
	
func get_new_position(delta) -> Vector2:
	var new_pose : Vector2 = position
	velocity = Vector2.ZERO
	
	# If the wizard is attacking, he can't move
	if !$Wizard_Animated.animation.contains("attack"):
		if Input.is_action_pressed(controller_input + "_move_up"):
			velocity.y -= 1
		if Input.is_action_pressed(controller_input + "_move_down"):
			velocity.y += 1
		if Input.is_action_pressed(controller_input + "_move_left"):
			velocity.x -= 1
		if Input.is_action_pressed(controller_input + "_move_right"):
			velocity.x += 1
	
	velocity = velocity.normalized() * speed
	
	new_pose += velocity * delta
	return new_pose

func set_animation() -> void:
	if Input.is_action_pressed(controller_input + "_attack_1"):
		$Wizard_Animated.animation = "attack_1"
	else:
		# If the player is going up/down, use the jump animation
		if velocity.y != 0:
			$Wizard_Animated.animation = "jump"
			
		# If the player is going left or right use the run animation
		elif velocity.x != 0:
			$Wizard_Animated.animation = "run"

		# If the player isn't moving, use the idle animationasd
		if velocity.length() <= 0:
			$Wizard_Animated.animation = "idle"

	## If the player wants to go left, invert the animation horizontally
	if velocity.x != 0:
		is_left = Input.is_action_pressed(controller_input + "_move_left")
				
	$Wizard_Animated.flip_h = is_left
	
	$Wizard_Animated.play()
