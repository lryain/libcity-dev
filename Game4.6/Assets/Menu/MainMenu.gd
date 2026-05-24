extends Control

@onready var in_game_menu_custom_min_size = %InGameMenu.custom_minimum_size

#var menu_map : Node3D:
#	set(value):
#		menu_map = value
		# pass the reference so the Game menu can free the menu bg map
#		$TabContainer/Game.menu_map = menu_map

# Called when the node enterss the scene tree for the first time.
func _ready():
	MultiplayerState.role_changed.connect(_on_multiplayer_role_changed)

	%InGameMenu.hide()


func _on_multiplayer_role_changed(new_role : Globals.MultiplayerRole):
	if self.is_queued_for_deletion() or not self.is_inside_tree():
		return

	if not is_instance_valid(%InGameMenu):
		printerr("Trying to animate InGameMenu hiding, but the referene is not valid")
		return
	elif %InGameMenu.is_queued_for_deletion():
		printerr("Trying to animate InGameMenu hiding, but it's queued for deletion")
		return

	if new_role != Globals.MultiplayerRole.NONE:
		%InGameMenu.show()
		%InGameMenu.custom_minimum_size = in_game_menu_custom_min_size
	else:
		var tween = create_tween()
		tween.tween_property(%InGameMenu, "custom_minimum_size", Vector2(0, in_game_menu_custom_min_size.y), 1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.chain()
		tween.tween_property(%InGameMenu, "visible", false, 0)
		tween.play()
