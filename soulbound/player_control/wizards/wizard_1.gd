extends Wizard

func _ready() -> void:
	setup(1)
	print("Called")

func _process(delta: float) -> void:
	position = get_new_position(delta)
