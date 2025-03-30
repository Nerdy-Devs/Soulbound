extends CharacterBody2D

@export var speed = 100
var screen_size

func _ready():
	screen_size = get_viewport_rect().size
	
func _process(delta: float) -> void:
	velocity = Vector2.ZERO
	
	if Input.is_action_pressed("player_1_move_up"):
		velocity.y -= 1
	if Input.is_action_pressed("player_1_move_down"):
		velocity.y += 1
	if Input.is_action_pressed("player_1_move_left"):
		velocity.x -= 1
	if Input.is_action_pressed("player_1_move_right"):
		velocity.x += 1
	
	# If the player is going up/down, use the jump animation
	if velocity.y != 0:
		$Wizard_Animated_1.animation = "jump"
		$Wizard_Animated_1.flip_h = velocity.x < 0
		
	# If the player is going left or right use the run animation
	elif velocity.x != 0:
		$Wizard_Animated_1.animation = "run"
		$Wizard_Animated_1.flip_h = velocity.x < 0

	# If the player isn't moving, use the idle animationasd
	if velocity.length() <= 0:
		$Wizard_Animated_1.animation = "idle"
	
	velocity = velocity.normalized() * speed
		
	$Wizard_Animated_1.play()
		
	position += velocity * delta
	position = position.clamp(Vector2.ZERO, screen_size)
