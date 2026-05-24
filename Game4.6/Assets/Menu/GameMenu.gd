extends Control

signal game_joined

const MAP_DIR = "res://Assets/Maps"

var selected_map_path : String = ""

@onready var mapsel : OptionButton = %MapSelection


func find_available_maps():
	# disable the host section of the menu until we know all the maps available
	%Host.disabled = true
	mapsel.clear()
	var dir = DirAccess.open(MAP_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir(): # only consider files
				# only .TSCN files can contain maps.
				# Files with names beginnngin with `_` are special and should not be listed
				if (file_name.ends_with(".tscn") or file_name.ends_with(".tscn.remap")) and not file_name.begins_with('_'):
					mapsel.add_item(file_name.get_slice(".", 0), mapsel.item_count + 1)
			file_name = dir.get_next()
	else:
		print_debug("An error occurred when trying to access the map path.")
	# enable the host menu section again
	%Host.disabled = false


func _on_server_disconnected() -> void:
	# gotta flip that toggle back
	%Join.button_pressed = false


# Called when the node enters the scene tree for the first time.
func _ready():
	# don't show what can't work in HTML5 exports yet
	if OS.has_feature("web"):
		%JoinSection.hide()
		$CenterContainer/VBoxContainer/HSeparator.hide()
	set_process(false)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	find_available_maps()

	# select map that is specified in GameConfig
	for i in range(mapsel.item_count):
		if mapsel.get_item_text(i) == MultiplayerState.game_config.map:
			mapsel.select(i)

	%JoinLocalDropdown.clear()
	%JoinLocalSection.hide()
	LocalDiscovery.update.connect(on_local_discovery_update)

	$CenterContainer/VBoxContainer/HostSection/BotAmount/BotAmountSlider.value = MultiplayerState.game_config.bot_amount
	$CenterContainer/VBoxContainer/HostSection/BotOptions/BotsVsHumans.set_pressed_no_signal(MultiplayerState.game_config.bots_vs_humans)
	$CenterContainer/VBoxContainer/HostSection/BotOptions/BotsVacant.set_pressed_no_signal(MultiplayerState.game_config.bots_fill_vacant)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not selected_map_path.is_empty():
		var progress : Array = []
		var result = ResourceLoader.load_threaded_get_status(selected_map_path, progress)
		%MapLoadingProgress.value = clamp(((progress[0] * 100) - 92) * 30, 0, 100)
		if result == ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			%MapLoadingProgress.hide()


func show_loading_screen():
	get_tree().root.get_node("Main/LoadingScreen").set_progress(0)
	get_tree().root.get_node("Main/LoadingScreen").show()


func _on_host_toggled(button_pressed):
	if button_pressed and not Settings.get_var("debug_hide_loading_screen"):
		show_loading_screen()

	%Join.disabled = button_pressed # can't host and join at the same time
	%JoinLocal.disabled = button_pressed

	match button_pressed:
		true: %Host.text = %Host.text.replace("HOST", "STOP")
		false: %Host.text = %Host.text.replace("STOP", "HOST")

	if button_pressed:
		MultiplayerState.game_config.map = mapsel.get_item_text(mapsel.selected)
		MultiplayerState.start_server()
		set_process(true)
		if not is_instance_valid(Globals.game_state):
			await MultiplayerState.spawn_game_state()
		await Globals.game_state.map_loaded
		set_process(false)
	else:
		MultiplayerState.stop_server()


func _on_join_toggled(button_pressed):
	if button_pressed and not Settings.get_var("debug_hide_loading_screen"):
		show_loading_screen()

	%Host.disabled = button_pressed # can't host and join at the same time
	%JoinLocal.disabled = button_pressed

	match button_pressed:
		true: %Join.text = %Join.text.replace("JOIN", "LEAVE")
		false: %Join.text = %Join.text.replace("LEAVE", "JOIN")

	if button_pressed:
		var host : String
		if not %HostAddress.text.is_empty():
			host = %HostAddress.text
		else:
			host = %HostDropdown.get_item_text(%HostDropdown.get_selected_id())

		MultiplayerState.start_client(host)
		set_process(true)
	else:
		MultiplayerState.stop_client()


func _on_map_selection_item_selected(index):
	selected_map_path = MAP_DIR.path_join(mapsel.get_item_text(mapsel.selected)) + ".tscn"


func _on_host_address_text_changed(new_text: String) -> void:
	%HostDropdown.disabled = ! new_text.is_empty()


func _on_visibility_changed() -> void:
	if visible:
		LocalDiscovery.tween.set_speed_scale(1.5) # speed up local discovery
	else:
		LocalDiscovery.tween.set_speed_scale(1) # back to normal speed

	if Globals.game_state and MultiplayerState.role != Globals.MultiplayerRole.NONE:
		await(get_tree().process_frame)
		if Globals.game_state:
			if is_instance_valid(Globals.game_state):
				if not Globals.game_state.is_queued_for_deletion():
					# GameMenu calling for a GameState update
					Globals.game_state.game_config_changed()


func on_local_discovery_update():
	if not LocalDiscovery.discovered_peers.is_empty():
		var idx := 0
		for i in LocalDiscovery.discovered_peers:
			if LocalDiscovery.discovered_peers[i].role in\
			[Globals.MultiplayerRole.SERVER, Globals.MultiplayerRole.DEDICATED_SERVER] and\
			LocalDiscovery.discovered_peers[i].expiration_time > Time.get_ticks_msec():
				var new_item_text = "%s [%s]" % [LocalDiscovery.discovered_peers[i].name, i]
				var item_already_present = false
				for j in range(0, %JoinLocalDropdown.item_count):
					if %JoinLocalDropdown.get_item_metadata(j) == i:
						item_already_present = true
						break

				if not item_already_present:
					%JoinLocalDropdown.add_item(new_item_text, idx)
					%JoinLocalDropdown.set_item_metadata(idx, i)
					idx += 1
			else:
				var item_present = false
				for j in range(0, %JoinLocalDropdown.item_count):
					if %JoinLocalDropdown.get_item_metadata(j) == i:
						%JoinLocalDropdown.remove_item(j)
						break

		if %JoinLocalDropdown.has_selectable_items():
			%JoinLocalSection.show()
		else:
			%JoinLocalSection.hide()
	else:
		%JoinLocalSection.hide()


func _on_join_local_toggled(button_pressed: bool) -> void:
	if button_pressed:
		show_loading_screen()


	%Host.disabled = button_pressed # can't host and join at the same time
	%Join.disabled = button_pressed

	match button_pressed:
		true: %JoinLocal.text = %JoinLocal.text.replace("JOIN", "LEAVE")
		false: %JoinLocal.text = %JoinLocal.text.replace("LEAVE", "JOIN")

	if button_pressed:
		var host = %JoinLocalDropdown.get_item_metadata(%JoinLocalDropdown.get_selected_id())
		MultiplayerState.start_client(host)
		set_process(true)
	else:
		MultiplayerState.stop_client()


func _on_bot_amount_slider_value_changed(value):
	$CenterContainer/VBoxContainer/HostSection/BotAmount/BotAmountLabel.text = str(value)
	MultiplayerState.game_config.bot_amount = int(value)


func _on_bots_vacant_toggled(button_pressed):
	MultiplayerState.game_config.bots_fill_vacant = button_pressed


func _on_bots_vs_humans_toggled(button_pressed):
	MultiplayerState.game_config.bots_vs_humans = button_pressed
