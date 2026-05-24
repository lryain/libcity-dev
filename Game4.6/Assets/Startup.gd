extends Control

# This scene is the first thing that loads, it decides what will be the main scene next

var main_scene : PackedScene

const main_scene_path := "res://Main.tscn"
const dedicated_scene_path := "res://Dedicated.tscn"

var scene_path := main_scene_path # default main scene

var is_dedicated := false

var duration : float
var expected_duration : float = 0

enum LoadingStage {LOADING, SPAWNING}

var stage := LoadingStage.LOADING


# Called when the node enters the scene tree for the first time.
func _ready():
	var file = FileAccess.open("user://boot.time", FileAccess.READ)
	if file:
		expected_duration = file.get_float()
#		if file.get_error() == OK:
#			prints("Read expected load time as", expected_duration)

	var args = OS.get_cmdline_args()

	for i in range(args.size()):
		match args[i]:
			"--version":
				print(Globals.get_version_string())
				await get_tree().process_frame
				await get_tree().quit()

			"--help":
				print(get_help_string())
				await get_tree().process_frame
				await get_tree().quit()

			"--dedicated-host":
				is_dedicated = true
				var map : String
				if args.size() > i+1:
					map = args[i+1]
					MultiplayerState.game_config.map = map
					MultiplayerState.start_server(Globals.MultiplayerRole.DEDICATED_SERVER)

					scene_path = dedicated_scene_path # overrriding main scene
				else:
					print("You need to provide a map name to start a dedicated host. Example:
	$ liblast --dedicated-host MapA\n")
					await get_tree().process_frame
					await get_tree().quit()

			"--automated-test":
				var test : String
				if args.size() > i+1:
					test = args[i+1]
					prints("Running an automated test scene ", test, "...")
					scene_path = "res://AutomatedTests/" + test + ".tscn"
					#get_tree().change_scene_to_file("res://Tests/" + test + ".tscn")
				else:
					print("You need to provide a test scene name to run a test scene. Example:
	$ liblast --test RagdollTest\n")
					await get_tree().process_frame
					await get_tree().quit()
			"--test":
				var test : String
				if args.size() > i+1:
					test = args[i+1]
					prints("Running a manual test scene ", test, "...")
					scene_path = "res://ManualTests/" + test + ".tscn"
					#get_tree().change_scene_to_file("res://Tests/" + test + ".tscn")
				else:
					print("You need to provide a manual test scene name to run a test scene. Example:
	$ liblast --test RagdollTest\n")
					await get_tree().process_frame
					await get_tree().quit()
	# if nothing special was requested, carry on as usual
	ResourceLoader.load_threaded_request(scene_path, "PackedScene", false)


func spawn_main_scene() -> void:
	var scene = ResourceLoader.load_threaded_get(scene_path)
	var main_scene = scene.instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(main_scene)
	Settings.call_apply_var("display_fullscreen") # enable fullscreen if desired

	if expected_duration == 0:
		expected_duration = duration # if nothing was saved, use measured data
	else: # othwerise average loading time with existing data
		expected_duration = (duration + expected_duration) /2

	if not is_dedicated: # only store boot time for client
		var file = FileAccess.open("user://boot.time", FileAccess.WRITE)
		if file:
			file.store_float(expected_duration)
	#		if file.get_error() == OK:
	#			prints("Saved expected load time as", expected_duration)
			file.flush()

	# free the boot screen
	queue_free()


func _process(delta):
	duration = Time.get_ticks_msec()
#	prints(duration)
	$TextureProgressBar.value = duration / (expected_duration if expected_duration != 0 else 5.0)

	if stage == LoadingStage.LOADING:
		var progress = []
		ResourceLoader.load_threaded_get_status(scene_path, progress)

		if progress[0] == 1: # loading finished
			spawn_main_scene()
			stage = LoadingStage.SPAWNING


func get_help_string() -> String:
	return "Usage: liblast [command] [parameter]
Where a command might be any of the following:
	--help						display this help text and quit
	--version					display Liblast version and quit
	--mute						start the game with sound muted
	--host [map]				create a game server on [map]
	--dedicated-host [map]		create a dedicated server on [map]
								this works without a display if --headless is used as a first commandline parameter
								in this mode user cannot interact with the running game
	--join [host]				joins a game hosted at [host]
	--test [scene]				runs a test [scene]
	--automated-test [scene]	runs an automated test scene"
