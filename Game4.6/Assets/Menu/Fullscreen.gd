extends CheckButton

# Called when the node enters the scene tree for the first time.
func _ready():
	set_pressed_no_signal(Settings.get_var("display_fullscreen"))


func _on_toggled(button_pressed):
	Settings.set_var("display_fullscreen", button_pressed)
