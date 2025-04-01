class_name Wizard

extends CharacterBody2D

const SPEED : int = 300
const JUMP_VELOCITY = -400.0
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
	
func _physics_process(delta: float) -> void:
	set_new_position(delta)
	set_animation()
	
func set_new_position(delta) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("player_1_move_up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Input.get_axis("player_1_move_left", "player_1_move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

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
