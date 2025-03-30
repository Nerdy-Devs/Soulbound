extends Wizard

func _ready() -> void:
	setup_wizard(1)

func _process(delta: float) -> void:
	position = get_new_position(delta)
