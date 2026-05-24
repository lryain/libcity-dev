extends Node

### This singleton manages global game settings. This is a bit like cvars in idtech engines

# SETTINGS

signal var_changed(var_name, value)
signal test_var_changed(var_name, value)

var settings = {} # current game settings


var settings_dir = "user://settings/"
var settings_file_path = settings_dir + "settings.liblast"
var settings_last = {} # copy of last settings for undo

var presets_dir = "res://settings/presets/"
var presets = {} # a dictionary of var_name presets. preset : settings{}

var dirty = false # have the settings been altered?

const SAVE_WAIT_TIME : float = 3 # how many seconds to wait between saving preferences

var save_timer : float = 0 # timer to limit disk writes when settings are changed rapidly

# some vars might want to skip initial apply call (display_fullscreen)
# becasue they are applied manually with delay (by BootScreen.gd)
var is_initial_call_apply := true


enum EnviroQuality {VERY_LOW, LOW, MEDIUM, HIGH, VERY_HIGH, EXTREME}
enum HeightMappingQuality {DISPLACEMENT, OCCLUSION_LOW, OCCLUSION_MEDIUM, OCCLUSION_HIGH}

# DEFAULTS

const settings_default = {
#	'player_name' = "player",
#	'player_color' = Color.GRAY.to_html(),
#	'player_uuid' = OS.get_unique_id(),
	'first_run' = true,
#	'player_play_time' = 0.0,
#	'player_games_played' = 0,
#	'player_games_won' = 0,
	'auth_enabled' = false,
	'auth_enabled_remember' = true,
	'auth_username' = "",
	'auth_username_remember' = false,
#	'user_avatar_hash' = PackedByteArray(),
#	'player_account_login' = null, # encrypted
#	'player_account_password_remember' = true,
#	'player_account_password' = null, # encrypted
#	'player_account_last_login' = null, # timestamp
	'input_mouse_sensitivity' = 1.0,
	'input_mouse_invert_y' = false,
	'input_mouse_invert_x' = false,
#	'network_game_host' = 'libla.st',
#	'network_game_port' = 12597,
#	'network_lobby_host' = 'libla.st',
#	'network_lobby_port' = 12598,
#	'network_auth_host' = 'libla.st',
#	'network_auth_port' = 12599,
	'display_fullscreen' = true,
	'display_window_size' = Vector2(1280,720),
#	'display_vsync_enabled' = true,
	'display_vsync' = 2, # Disabled, Enabled, Adaptive, Mailbox
	'render_scale' = 1.0, # 3D viewport render scaling
	'render_scale_mode' = 0,
	'render_fps_max' = 0, # 0 means unlimited
	'render_fps_min' = 5, # 0 means fps won't be limited when th egame loses focus
	'render_fov' = 90,
	'debug_nav' = false,
	'debug_hide_loading_screen' = false,
#	'render_msaa' = 0, # none, 2x, 4x, 8x
#	'render_ssaa' = 0, # none, fxaa
	'debug_render' = 0,
	'render_hud' = true,
	'view_weapon_sway' = false,
	'view_weapon_sway_limit' = 0.05,
#	'render_debanding_enabled' = false,
#	'render_ssrl_enabled' = false,
#	'render_ssrl_amount' = 0.25,
#	'render_ssrl_limit' = 0.18,
#	'render_glow_enabled' = true,
#	'render_glow_quality' = 1.0,
	'render_refprobes' = true,
	'render_gibs' = true,
	'render_particles_amount' = 1.0,
	'render_particles_fallback' = false,
	'render_height_mapping' = true,
	'render_height_mapping_quality' = HeightMappingQuality.OCCLUSION_LOW,
#	'render_ssr_enabled' = false,
#	'render_ssr_quality' = 1.0,
#	'render_ssao_enabled' = false,
#	'render_ssao_quality' = 1.0,
#	'render_ssil_enabled' = false,
#	'render_ssil_quality' = 1.0,
	'render_enviro_quality' = EnviroQuality.MEDIUM,
#	'render_particles_extra' = false,
#	'render_casing' = true,
	'menu_background' = true,
#	'menu_background_bots' = false,
#	'menu_skip_auth' = true,
#	'render_grain' = false,
#	'host_name' = "Liblast Server",
	'host_welcome_message' = "[color=ffffff][b]Welcome to Liblast! Have fun![/b][/color]",
	'host_local_discovery' = true,
#	'host_peer_limit' = 32,
#	'host_peer_require_auth' = false, # players need to be authenticated to join
	'audio_volume_master' = 0.0,
	'audio_volume_music'= -6.0,
	'audio_volume_sfx' = -6.0,
	'audio_volume_ui' = -6.0,
	'audio_automute' = true,
	'audio_welcome' = true,
	'network_upnp' = true,

	}

var test_settings = {
	'use_pooling' = false,
}


#func _init():

func _ready() -> void:
	settings = settings_default.duplicate(true)
	set_physics_process(false)
	load_settings()
	call_apply_all()
	set_deferred(&"is_initial_call_apply", false)

# SAVE/LOAD

func _physics_process(delta: float) -> void:
#	print(save_timer)
	if save_timer > 0:
		save_timer = max(0, save_timer - delta)
		if save_timer == 0:
#			print("FFF")
			if dirty:
				save_settings()
	else:
		set_physics_process(false)


# TODO: Unify the type of the return value
func save_settings(force = false):
	if save_timer > 0 and not force:
		set_physics_process(true)
		return

	if not dirty and not force:
#		print_debug("Attempted to save unmodified settings, skipping")
		return ERR_ALREADY_EXISTS
#	elif not dirty and force:
#		print_debug("Forced saving unmodified settings")
#	else:
#		print_debug("Saving dirty settings")

	var settings_changed = {}

	for i in settings_default.keys():
		if settings.keys().has(i):

			if typeof(settings[i]) != typeof(settings_default[i]):
				printerr("Setting ", i, " is of type ", typeof(settings[i]), " but default is of type ", typeof(settings_default[i]), " - using default.")
				settings_changed[i] = settings_default[i] # if the type of existing value different, override with a default

#			print("Comparing var ", settings[i], " with default value ", settings_default[i])
#			print("Comparing var ", i , " of value ", settings[i], " with default value ", settings_default[i])
			# Due to an obscure Godot bug both values are printed (and compared) as being the same,
			# despite settings_default being a constant and the setting value being clearly different.
			# Happy debugging. Read more here: https://codeberg.org/Liblast/Liblast/issues/354
#			if typeof(settings[i]) != typeof(settings_default[i]):
#				settings[i] = settings_default[i] # if the type of existing value different, override with a default
#
			elif settings[i] != settings_default[i]:
#					prints("Variable ", i, "is not using default value - SAVING")
					settings_changed[i] = settings[i]
#			else:
#				prints("Variable", i, "is using default value - not saving.")
#			else:
#				prints("Setting", i, "is of different type than default - not saving.")

	if settings_changed.is_empty():
		print_debug("Settings were NOT saved! This might be a known Godot bug. See here: https://codeberg.org/Liblast/Liblast/issues/354")
		if not force:
			return
		else:
			settings_changed = {"placeholder" : true}

	if not DirAccess.dir_exists_absolute(settings_dir):
		DirAccess.make_dir_recursive_absolute(settings_dir)

	var file = FileAccess.open(settings_file_path, FileAccess.WRITE)
	if file == null:
		print_debug("Cannot open file for writing")
		return

#	print("Variables changed: ", settings_changed)

	file.store_string(var_to_str(settings_changed))
	if file.get_error():
		return file.get_error()
	file.flush()

#	print_debug("Settings saved")
	dirty = false
	save_timer = SAVE_WAIT_TIME # set timer
	set_physics_process(true)
	return OK


func load_settings():
	var file = FileAccess.open(settings_file_path, FileAccess.READ)

	if file:
		var settings_loaded = str_to_var(file.get_as_text())
		if settings_loaded is Dictionary: # overlay the file contents over defaults
			for i in settings_default.keys():
				if settings_loaded.has(i):
					if typeof(settings_loaded[i]) != typeof(settings_default[i]):
						settings[i] = settings_default[i] # if the type of existing value different, override with a default
						printerr("Setting ", i, " is of type ", typeof(settings_loaded[i]), " but default is of type ", typeof(settings_default[i]), " - using default.")
					else:
#						prints("Setting", i, "present. Overriding default value.")
						settings[i] = settings_loaded[i]
				else:
					settings[i] = settings_default[i]
#					prints("Setting", i, "missing. Using default.")

		else:
			printerr("Settings file contains invalid data")
			return ERR_INVALID_DATA
	else:
		printerr("Cannot load settings file. Using defaults.")
		save_settings(true)
		return ERR_FILE_CANT_OPEN

	return OK

# SET/GET


func set_var(var_name: String, value: Variant) -> int:
	if test_settings.has(var_name):
		test_settings[var_name] = value
		emit_signal(&'test_var_changed', var_name, value)
		return OK

	if value == null:
		return ERR_INVALID_DATA

	if not dirty:
		dirty = true
	settings[var_name] = value
	emit_signal(&'var_changed', var_name, value)
	call_apply_var(var_name)
	save_settings()

	return OK
#	print_debug("Variable ", var_name, " was set to ", value)


func get_var(var_name: String) -> Variant: # return a given var_name
	if test_settings.has(var_name):
		return test_settings.get(var_name)
	if settings.has(var_name):
		return settings.get(var_name)
	elif settings_default.has(var_name):
		push_warning("Settings: var only found in settings_default: '", var_name , "'")
		return settings_default.get(var_name)
	else:
		push_error("Settings: var not found: '", var_name , "'")
		return null

# APPLY


func call_apply_var(var_name: String) -> void: # call function corresponding to the given var_name
	var apply_method: StringName = StringName("apply_" + var_name)
	if has_method(apply_method):
		call(apply_method, settings[var_name])
#	else:
#		printerr("Settings var_name ", var_name, " has no apply method")


func call_apply_all(): # apply all current settings
	for key in settings.keys():
		call_apply_var(key)


func load_preset(preset: String) -> void: # load var_names from a preset
	settings_last = settings
	settings = presets[preset]


func restore_last() -> void:
	settings = settings_last

### VARIABLE APPLY FUNCTIONS

#func apply_player_name(value:String) -> void:
#		print_debug("Setting player name to ", value)


func apply_display_fullscreen(value:bool) -> void:
	# this property is applied manually by BootScreen.gd withi some delay
	if is_initial_call_apply:
		return

	if value:
		get_viewport().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		get_viewport().mode = Window.MODE_WINDOWED


func apply_render_fps_max(value) -> void:
	if value == Engine.max_fps:
		# we changed nothing
		return

#	if value != 0:
#		prints("Limiting framerate to", value,"FPS")
#	else:
#		prints("Removing framerate limit.")

	Engine.max_fps  = value


func apply_render_scale(value) -> void:
#	var exp_value = pow(2, value) * 0.125
#	print_debug("Applying render scale: ", exp_value)
	get_viewport().scaling_3d_scale = value


func apply_display_vsync(value) -> void:
#	print_debug("Applying Vsync mode: ", value)
	DisplayServer.window_set_vsync_mode(value)


func apply_debug_render(value) -> void:
	get_viewport().debug_draw = value


func apply_render_scale_mode(value) -> void:
	get_viewport().scaling_3d_mode = value


func apply_audio_volume_master(value) -> void:
#	print_debug("Setting master volume to ", value)
	AudioServer.set_bus_volume_db(0, value)


func apply_audio_volume_music(value) -> void:
#	print_debug("Setting music volume to ", value)
	AudioServer.set_bus_volume_db(1, value)


func apply_audio_volume_sfx(value) -> void:
#	print_debug("Setting SFX volume to ", value)
	AudioServer.set_bus_volume_db(2, value)


func apply_audio_volume_ui(value) -> void:
#	print_debug("Setting UI volume to ", value)
	AudioServer.set_bus_volume_db(3, value)


func apply_render_fov(value) -> void:
#	print_debug("Setting UI volume to ", value)
	pass #get_viewport().get_camera_3d().fov = value


func apply_render_enviro_quality(value) -> void:
#	print("Setting Environment Rendering Quality to ", str(EnviroQuality.keys()[value]))

	var env_name = str(EnviroQuality.keys()[value]).to_pascal_case().replace('_', '')
	var fname = "res://Assets/Environments/Default" + env_name + ".tres"
	var env = load(fname)

#	print("Loaded environment ", fname, " into ", env)
	if env:
#		print("Replacing the environment")
		get_viewport().find_world_3d().environment = env


func apply_render_height_mapping(value) -> void:
	RenderingServer.global_shader_parameter_set(&"height_mapping_enabled", value as bool)


func apply_render_height_mapping_quality(value) -> void:
	var height_mapping_occlusion_layer_range_limit : Vector2
	match value:
		1: height_mapping_occlusion_layer_range_limit = Vector2(1,4)
		2: height_mapping_occlusion_layer_range_limit = Vector2(2,8)
		3: height_mapping_occlusion_layer_range_limit = Vector2(4,16)

	if value > 0:
		RenderingServer.global_shader_parameter_set(&"height_mapping_layers_range_limit",\
		height_mapping_occlusion_layer_range_limit)
		RenderingServer.global_shader_parameter_set(&"height_mapping_occlusion_enabled", true)
	else:
		RenderingServer.global_shader_parameter_set(&"height_mapping_occlusion_enabled", false)


func apply_first_run(value):
	if value:
		print("Running the game for the first time!")
		set_var("first_run", false)


func _exit_tree() -> void:
	save_settings(true)


func apply_host_local_discovery(value):
	if value:
		LocalDiscovery.enable()
	else:
		LocalDiscovery.disable()
