extends ColorRect


func _ready() -> void:
	if Settings.get_var("first_run"):
		show()
		Settings.set_var("first_run", false)
	else:
		queue_free()


func _on_button_pressed() -> void:
	queue_free()
