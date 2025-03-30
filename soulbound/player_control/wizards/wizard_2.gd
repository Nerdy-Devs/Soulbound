extends Wizard

func _ready() -> void:
	setup(2)

func _process(delta: float) -> void:
	var new_pose = get_new_position(delta)
	position = new_pose
