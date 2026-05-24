extends CanvasLayer


# block inputs when loading
func _input(event):
	if visible:
		get_tree().root.set_input_as_handled()


func set_progress(progress: float) -> void:
#	print("Setting loading progress to ", progress)
	$CenterContainer/MarginContainer/Panel/ProgressBar.material.set(&"shader_parameter/throbber", progress == 0)
	$CenterContainer/MarginContainer/Panel/ProgressBar.material.set(&"shader_parameter/progress", progress)


# Called when the node enters the scene tree for the first time.
func _ready():
	set_progress(0)
