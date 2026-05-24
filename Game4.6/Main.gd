extends Node

# display refresh rate, which is used to set the physics tick rate
var hz := 60

var menu_music_tween
var mute_tween
var fps_cap_tween

var muted_manually := false
var muted := false

@export var menu_background_map : PackedScene


func _ready():
	%LoadingScreen.hide()

	get_tree().root.title = "Liblast"
	#get_viewport().vrs_texture = load("res://Assets/Menu/UiVrsMask.tres")

	Globals.focus = Globals.Focus.MENU
	Globals.focus_changed.connect(_on_focus_changed)

	Settings.var_changed.connect(_settings_changed)

	MultiplayerState.role_changed.connect(_on_multiplayer_role_changed)

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)

	var args = OS.get_cmdline_args()

	#args.clear()

	$Muted.modulate = Color(Color.WHITE, 0)

	for i in range(args.size()):
		match args[i]:
#			"--skip-auth-menu":
#				print("Skipping authentication menu")
#				$UI/PlayerAuthMenu._on_anonymous_pressed()

			"--host":
				var map = args[i+1]
				prints("Hosting a local game on ", map)
				var game_config = GameConfig.new()
				game_config.map = map
				MultiplayerState.game_config = game_config
				MultiplayerState.start_server()

			"--join":
				var host = args[i+1]
				prints("Joining a game at ", host)
				MultiplayerState.start_client(host)
			
			# runnings test scenes is handled in the BootScreen
			
			#"--test":
				#var test = args[i+1]
				#prints("Requested running a test scene ", test)
				#get_tree().change_scene_to_file("res://Tests/" + test + ".tscn")

			"--mute":
				prints("Muting audio")
				set_mute(true, true, true)
				$Muted.modulate = Color(Color.WHITE, 1)
				AudioServer.set_bus_mute(0, true) # immediatelly mute the master bus

#THIS LINE IS COMENTED, NOT DELETED, AS A REMINDER TO GET RID OF THE CODE THAT
#HANDLE THIS. BUT LETS JUST DISABLE IT AT THE MOMENT AND HOPE NOTHING EXPLODES.
#create_tween().set_loops().tween_callback(set_physics_tick_to_display_rate).set_delay(1.0) #calls tick_rate update every one second.

	#if not muted or muted_manually:
	if Settings.get_var(&'audio_welcome'):
		$UI/Welcome.play()

	$UI/Music.play()

	if OS.has_feature("web"):
		$UI/Quit.hide()

	spawn_menu_background()

#	$Grain.visible = Settings.get_var(&'render_grain')

#	if Settings.get_var('auth_enabled') == false:
#		print("Skipping authentication menu")
##		await get_tree().create_timer(0.5).timeout
#		$UI/PlayerAuthMenu.auth_menu_closed.emit()
#		$UI/PlayerAuthMenu._on_anonymous_pressed()


func spawn_menu_background():
	var bg_map = menu_background_map.instantiate()
	$UI.add_child(bg_map)
	bg_map.name = "BackgroundMap"


func _on_multiplayer_role_changed(new_role: Globals.MultiplayerRole):
	if not self.is_inside_tree():
		return
		
	var bg_map = $UI.get_node_or_null("BackgroundMap")

	if new_role == Globals.MultiplayerRole.NONE:
		if Settings.get_var(&"menu_background") and not bg_map:
			spawn_menu_background()
		$UI/Music.stream_paused = false
		var tween = create_tween()
		tween.tween_property($UI/Music, "volume_db", 0, 4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tween.play()
	elif new_role == Globals.MultiplayerRole.INTERMEDIATE:
		if Settings.get_var(&"menu_background"):
			if bg_map:
				bg_map.queue_free()
			$UI.hide()
	else:
		if Settings.get_var(&"menu_background"):
			if bg_map:
				bg_map.queue_free()
		$UI.hide()
		var tween = create_tween()
		tween.tween_property($UI/Music, "volume_db", -80, 4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		tween.chain()
		tween.tween_property($UI/Music, "stream_paused", true, 0)
		tween.play()


func _on_auth_menu_closed():

#	print("PlayerAuth menu closed")
	$UI/MainMenu.show()
#	if $UI.has_node("BackgroundMap"):
#		$UI/MainMenu.menu_map = $UI/BackgroundMap


func _on_focus_changed(new, previous):

	if new == Globals.Focus.MENU:
		$UI.show()

#		return # skipping music management here
#
#		if menu_music_tween:
#			menu_music_tween.kill()
#
#		menu_music_tween = create_tween()
#		menu_music_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
#
#		# menu music
#
#		# turn on
#		#menu_music_tween.tween_property($UI/Music, 'stream_paused', false, 0)
#		#menu_music_tween.tween_property($UI/Music, 'volume_db', 0, 3)
#		menu_music_tween.tween_property($UI/Music, 'volume_db', -60, 3)
#		menu_music_tween.tween_property($UI/Music, 'stream_paused', true, 0)
#
#		menu_music_tween.play()

		#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		$UI.hide()

#		return # skipping music management here
#
#		if menu_music_tween:
#			menu_music_tween.kill()
#
#		menu_music_tween = create_tween()
#		menu_music_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
#		# turn on
#		menu_music_tween.tween_property($UI/Music, 'stream_paused', false, 0)
#		menu_music_tween.tween_property($UI/Music, 'volume_db', 0, 3)
##
#		# turn off
###		menu_music_tween.tween_property($UI/Music, 'volume_db', -60, 3)
##		#menu_music_tween.tween_property($UI/Music, 'stream_paused', true, 0)
#
#		menu_music_tween.play()


func _unhandled_key_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"): # Escape
		# if the menu is open, try to bring the focus back to where it was before
		if Globals.focus == Globals.Focus.MENU and Globals.focus_previous != Globals.Focus.MENU:
			Globals.focus = Globals.focus_previous

		# open the menu
		elif Globals.focus != Globals.Focus.MENU:
			Globals.focus = Globals.Focus.MENU

		get_tree().root.set_input_as_handled()

	elif event.is_action_pressed("mute_audio"):
		set_mute(not muted_manually, true)

		get_tree().root.set_input_as_handled()
	elif event.is_action_pressed("quit"):
		get_tree().quit()
	elif event.is_action_pressed("fullscreen"):
		# invert
		Settings.set_var(&"display_fullscreen", ! Settings.get_var(&"display_fullscreen"))

func set_mute(mute: bool, manual:= false, immediate:= false):
	if manual:
		muted_manually = mute
	else:
		muted = mute

	if mute_tween:
		mute_tween.kill()

	mute_tween = create_tween()

	# the master volume set by the user
	var master_db = Settings.get_var(&"audio_volume_master") as int

	if muted or muted_manually:
		mute_tween.tween_method(func(v): AudioServer.set_bus_volume_db(0,v), master_db, -60, 0.5 if not immediate else .0)
		mute_tween.parallel().tween_property($Muted, "modulate", Color(Color.WHITE, 1.0) if muted_manually else Color(Color.WHITE, 0.5), 0.25 if not immediate else .0)
		mute_tween.tween_method(func(v): AudioServer.set_bus_mute(0,v), false, true, 0)
	else:
		mute_tween.tween_method(func(v): AudioServer.set_bus_mute(0,v), true, false, 0)
		mute_tween.tween_method(func(v): AudioServer.set_bus_volume_db(0,v), -60, master_db, 0.25 if not immediate else .0)
		mute_tween.parallel().tween_property($Muted, "modulate", Color(Color.WHITE, 0), 0.5 if not immediate else .0)

	if muted or muted_manually:
		get_tree().root.title = "Liblast 🔇" # unicode mute symbol
	else:
		get_tree().root.title = "Liblast"


func _settings_changed(variable, value):
	match variable:
		'menu_background':
#			print_debug("Menu background ap visibility var changed to ", value)
			if $UI.has_node("BackgroundMap") and value == false:
				$UI/BackgroundMap.queue_free()
#		'render_grain':
#			$Grain.visible = Settings.get_var('render_grain')

# limit game FPS when the window is not active
func _notification(what: int) -> void:
#	return # temporarily skip the following logic
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if Settings.get_var(&'audio_automute'):
				set_mute(true)

			if MultiplayerState.role in [Globals.MultiplayerRole.SERVER, Globals.MultiplayerRole.DEDICATED_SERVER]:
				if MultiplayerState.peer.host.get_peers().size() > 0:
#					print("Active server - refusing to lower FPS as that'll affect all peers")
					return

			var min_fps = Settings.get_var(&"render_fps_min")

			# don't lower FPS when loading a map because that's only going to make it take longer
			if min_fps == 0 or MultiplayerState.role == Globals.MultiplayerRole.INTERMEDIATE:
				return
			if fps_cap_tween:
				fps_cap_tween.kill()
			fps_cap_tween = create_tween()
			Engine.max_fps  = 60
			fps_cap_tween.tween_property(Engine, "max_fps", min_fps, 1).set_delay(0.25)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if Settings.get_var(&'audio_automute'):
				set_mute(false)

			if fps_cap_tween:
				fps_cap_tween.kill()
			Engine.max_fps  = Settings.get_var(&"render_fps_max")


func set_physics_tick_to_display_rate():
	# update physics tick rate if display refresh rate changed (for high-refresh rate monitors)
	# this will become obsolete once physics interpolation is implemented upstream
	var hz_new = DisplayServer.screen_get_refresh_rate()
	if hz_new == 0:
		hz_new = 60

	if hz != hz_new:
		hz = hz_new
#		print("Detected display refresh rate change to ", hz," Hz. Updating physics tick rate.")
		Engine.physics_ticks_per_second = hz


func _on_ui_visibility_changed() -> void:
	return
#
#	if $UI.visible:
##		print("Enabling VRS")
#		get_viewport().vrs_mode = Viewport.VRS_TEXTURE
#	else:
##		print("Disabling VRS")
#		get_viewport().vrs_mode = Viewport.VRS_DISABLED


func _on_button_pressed() -> void:
	get_tree().quit()
