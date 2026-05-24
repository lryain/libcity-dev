extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)

	get_tree().root.title = "Liblast Dediated Server"

	# a dedicated server shouldn't make any sound
	AudioServer.set_bus_mute(0, true)

	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60

	var args = OS.get_cmdline_args()

	for i in range(args.size()):
		match args[i]:
			"--dedicated-host":
				var map : String
				if args.size() > i:
					map = args[i+1]
					MultiplayerState.game_config.map = map

	MultiplayerState.start_server(Globals.MultiplayerRole.DEDICATED_SERVER)
	print("MultiplayerRole: ", Globals.MultiplayerRole.keys()[MultiplayerState.role])
	print("Multiplayer: ", multiplayer)
