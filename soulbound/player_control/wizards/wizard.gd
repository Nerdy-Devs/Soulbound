class_name Wizard

extends CharacterBody2D

const SPEED : int = 200
const JUMP_VELOCITY = -200.0
var screen_size

## Which controller to use
var controller_input : String

## Player Number
##
## Allows the wizards to be controlled by different users
@export var player_number : int = -1

## Used to keep track of the direction the wizard is facing
var is_left : bool = false
var master_id : int
var target_pose = position ## Only for multiplayer

func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	controller_input = "player_" + str(player_number)
	
	# Assign ownership to ensure only the correct client controls this character
	if player_number != multiplayer.get_unique_id():
		set_multiplayer_authority(player_number)
	
	$Wizard_Animated.animation = "idle"
	
func _physics_process(delta: float) -> void:
	if master_id != multiplayer.get_unique_id():
		position = position.lerp(target_pose, 10 * delta)
	set_new_position(delta)
	set_animation()
	check_position()
	
func set_pose(new_target_pose : Vector2):
	target_pose = new_target_pose
	
func set_new_position(delta) -> void:
	if master_id == multiplayer.get_unique_id():
		# Add the gravity.
		if not is_on_floor():
			velocity += get_gravity() * delta

		# Handle jump.
		if Input.is_action_just_pressed("player_1_move_up"):
			velocity.y = JUMP_VELOCITY

		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		var direction = Input.get_axis("player_1_move_left", "player_1_move_right")
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

		move_and_slide()

func set_animation(animation = "") -> void:
	if master_id == multiplayer.get_unique_id() and animation.is_empty():
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

		## If the player wants to go left, invaert the animation horizontally
		if velocity.x != 0:
			is_left = Input.is_action_pressed(controller_input + "_move_left")
					
		velocity.x = clamp(velocity.x, -50, 50)
		velocity.y = clamp(velocity.y, -300, 300)
					
		
	elif !animation.is_empty():
		$Wizard_Animated.animation = animation
	
	$Wizard_Animated.flip_h = is_left
	$Wizard_Animated.play()	
	
func get_animation() -> String:
	return $Wizard_Animated.animation
	
func check_position():
	var pose = position
	
	# Checks X
	if pose[0] < -1280:
		pose[0] = 1280
	elif pose[0] > 1280:
		pose[0] = 0
	
	# Checks Y
	if pose[1] < 0:
		pose[1] = 720
	elif pose[1] > 720:
		pose[1] = 0	
	
	
	position = pose
