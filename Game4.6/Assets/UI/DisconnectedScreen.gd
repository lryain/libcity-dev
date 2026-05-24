extends Control

#@export var menu_path : NodePath
#@onready var menu : Control = get_node(menu_path)

func activate():
	print("Activated disconnect screen")
#	menu.hide()
#	var frame_capture = Texture2D.new()
#	await RenderingServer.frame_post_draw
#	frame_capture = get_viewport().get_texture().get_image()
#	$Freezeframe.texture = frame_capture

	# temporarily cap the framerate
	Engine.max_fps = 30

	Globals.game_state.hud.hide()
	MultiplayerState.local_character = null
	Globals.current_character = null
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_back_to_menu_pressed() -> void:
	# carry on cleaning the game state
	MultiplayerState.cleanup_game_state()
	# temporarily cap the framerate
	Engine.max_fps = Settings.get_var(&"render_fps_max")

	get_tree().paused = false
	hide()
#	menu.show()
	Globals.focus = Globals.Focus.MENU


func _enter_tree() -> void:
	hide()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	multiplayer.server_disconnected.connect(activate)
