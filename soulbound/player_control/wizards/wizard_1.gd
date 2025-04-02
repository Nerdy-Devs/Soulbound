extends Area2D

@export var speed = 400
var screen_size

func _ready():
	screen_size = get_viewport_rect().size
	
func _process(delta: float) -> void:
	var velocity = Vector2.ZERO
	
	if Input.is_action_just_pressed("player_1_move_up"):
		velocity.y -= 1
	if Input.is_action_just_pressed("player_1_move_down"):
		velocity.y += 1
	if Input.is_action_just_pressed("player_1_move_left"):
		velocity.x -= 1
	if Input.is_action_just_pressed("player_1_move_right"):
		velocity.x += 1

	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
		
