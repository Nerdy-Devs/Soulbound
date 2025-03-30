extends Area2D

var speed = 4
var screen_size

func _ready():
	screen_size = get_viewport_rect().size
	
func _process(delta: float) -> void:
	var velocity = Vector2.ZERO
	
	if Input.is_action_pressed("player_1_move_up"):
		velocity.y -= 1
	if Input.is_action_pressed("player_1_move_down"):
		velocity.y += 1
	if Input.is_action_pressed("player_1_move_left"):
		velocity.x -= 1
	if Input.is_action_pressed("player_1_move_right"):
		velocity.x += 1

	if velocity.y != 0:
		$AnimatedSprite2D.animation = "jump"
		$AnimatedSprite2D.flip_h = velocity.x < 0	

	elif velocity.x != 0:
		$AnimatedSprite2D.animation = "run"
		$AnimatedSprite2D.flip_h = velocity.x < 0

	if velocity.length() <= 0:
		$AnimatedSprite2D.animation = "idle"
	
	velocity = velocity.normalized() * speed
		
	$AnimatedSprite2D.play()
		
	position += velocity * delta
	position = position.clamp(Vector2.ZERO, screen_size)
