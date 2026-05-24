extends OptionButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	selected = Settings.get_var('render_enviro_quality')


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_item_selected(index: int) -> void:
	Settings.set_var('render_enviro_quality', index)
