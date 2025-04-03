extends CharacterBody2D

@onready var farmThing = $Farm_thing

@onready var noPowerSprite = $No_Power
@onready var swordPowerSprite = $Sword
@onready var blastPowerSprite = $Blast

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

#check if the player is holding farm stuff
var isHolding := false
#check if the player is powered and what power they have
var isPowered := false
#no power = None   sword power = Sword   blaster power = Blast
var powerType := "None"


func _physics_process(delta):
	
	if(powerType == "None"):
		noPowerSprite.show()
		swordPowerSprite.hide()
		blastPowerSprite.hide()
	if(powerType == "Sword"):
		noPowerSprite.hide()
		swordPowerSprite.show()
		blastPowerSprite.hide()
	if(powerType == "Blast"):
		noPowerSprite.hide()
		swordPowerSprite.hide()
		blastPowerSprite.show()
	
	#handles showing and hiding the farm thing
	if(isHolding == true):
		farmThing.show()
	else:
		farmThing.hide()
	
	
	
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
