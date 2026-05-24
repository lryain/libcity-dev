extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	$Quality/HeightMappingQualitySlider.value = Settings.get_var(&"render_height_mapping_quality")
	$HBoxContainer/CheckButton.button_pressed = Settings.get_var(&"render_height_mapping")
	_on_check_button_toggled(Settings.get_var(&"render_height_mapping"))


func _on_height_mapping_quality_slider_value_changed(value):
	Settings.set_var(&"render_height_mapping_quality", value as int)
	var label_text : String
	var label_color : Color
	match value as int:
		Settings.HeightMappingQuality.DISPLACEMENT:
			label_text = "displacement mapping"
			label_color = Color(0,1,0,1)
		Settings.HeightMappingQuality.OCCLUSION_LOW:
			label_text = "parallax occlusion mapping low"
			label_color = Color(1,1,0,1)
		Settings.HeightMappingQuality.OCCLUSION_MEDIUM:
			label_text = "parallax occlusion mapping medium"
			label_color = Color(1,0.5,0,1)
		Settings.HeightMappingQuality.OCCLUSION_HIGH:
			label_text = "parallax occlusion mapping high"
			label_color = Color(1,0,0,1)
	$HeightMappingQualityLabel.text = label_text
	$HeightMappingQualityLabel.modulate = label_color


func _on_check_button_toggled(button_pressed):
	Settings.set_var(&"render_height_mapping", button_pressed)
	$Quality/HeightMappingQualitySlider.editable = button_pressed
	if button_pressed:
		$HeightMappingQualityLabel.modulate.a = 1
	else:
		$HeightMappingQualityLabel.modulate.a = 0.25
	
	#$Quality/Label.disabled = ! button_pressed
	#$HeightMappingQualityLabel.disabled = ! button_pressed
