extends Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var button = Button.new()
	button.text = "Start Server"
	add_child(button)
