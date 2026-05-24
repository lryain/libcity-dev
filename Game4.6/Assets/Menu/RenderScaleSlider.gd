extends HSlider


func value_changed():
	$"../RenderScaleValueLabel".text = str(value)
	var red = min(remap(value, 1, 2, 1, 1), remap(value, 0, 1, 0, 1))
	var green = remap(value, 1, 2, 1, 0)
	var blue = min(remap(value, 1, 2, 1, 0), remap(value, 0, 1, 0, 1))
	$"../RenderScaleValueLabel".modulate = Color(red,green,blue)


# Called when the node enters the scene tree for the first time.
func _ready():
	set_value_no_signal(Settings.get_var("render_scale"))
	$"../ScalingMode".selected = Settings.get_var("render_scale_mode")
	value_changed()


func _on_value_changed(value):
	Settings.set_var("render_scale", value)
	value_changed()


func _on_scaling_mode_item_selected(index: int) -> void:
	Settings.set_var("render_scale_mode", index)
