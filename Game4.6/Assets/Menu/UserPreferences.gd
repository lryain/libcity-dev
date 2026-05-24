extends VBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%MouseSensitivitySlider.set_value_no_signal(Settings.get_var("input_mouse_sensitivity"))
	%MouseSensitivityValueLabel.text = str(Settings.get_var("input_mouse_sensitivity"))
	%MouseInvertY.button_pressed = Settings.get_var("input_mouse_invert_y")
	%MouseInvertX.button_pressed = Settings.get_var("input_mouse_invert_x")
	%FovSlider.set_value_no_signal(Settings.get_var("render_fov"))
	%FovValueLabel.text = str(Settings.get_var("render_fov")) + "°"
	%ParticlesFallback.set_pressed_no_signal(Settings.get_var("render_particles_fallback"))


func _on_mouse_sensitivity_slider_value_changed(value: float) -> void:
	value = roundf(value * 100) / 100
	%MouseSensitivityValueLabel.text = str(value)
	Settings.set_var("input_mouse_sensitivity", value)


func _on_fov_slider_value_changed(value: float) -> void:
	%FovValueLabel.text = str(value) + "°"
	Settings.set_var("render_fov", int(value))


func _on_particles_fallback_toggled(button_pressed: bool) -> void:
	Settings.set_var("render_particles_fallback", button_pressed)


func _on_mouse_invert_y_toggled(button_pressed: bool) -> void:
	Settings.set_var("input_mouse_invert_y", button_pressed)


func _on_mouse_invert_x_toggled(button_pressed: bool) -> void:
	Settings.set_var("input_mouse_invert_x", button_pressed)
