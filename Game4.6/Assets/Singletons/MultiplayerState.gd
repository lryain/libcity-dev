extends Node
# Holds global multiplayer peer and role

var logger: Node
# for signalling when auth status has changed
signal auth_changed(enabled: bool)
signal role_changed(role: Globals.MultiplayerRole)
#signal ServerStarted(error)

#var game_state: GameState = null # stores reference to active game state if present

enum HandshakeStage {NONE, PREP, SENT, OK, ERROR}

var handhshake_stage : HandshakeStage = HandshakeStage.NONE

var local_character: Character = null

var uptime = 0 # seconds
#const respawn_delay : float = 3 # seconds
#const reset_delay : float = 10 # seconds
#var spawn_queue = {}
#var reset_at : float = -1
#
#var game_score_limit = 10 #15

var auth_enabled : bool:
	set(value):
		auth_enabled = value
		if value == true:
			emit_signal(&"auth_changed", true)
		else:
			emit_signal(&"auth_changed", false)

var auth_username : String
var auth_tokens : Array # auth tokens

@onready var user_character_profile := CharacterProfile.new():
	set(value):
		user_character_profile = value

		# propagate changes to local character profile
		update_character_profile(peer.get_unique_id(), user_character_profile)

var peer : ENetMultiplayerPeer

@export var game_config := GameConfig.new()


var role := Globals.MultiplayerRole.NONE:
	set(new_role):
		role = new_role
		role_changed.emit(role)
		LocalDiscovery.send_and_recive() # broadcast our new multiplayer role
#		print("Multiplayer Role changed to ", Globals.MultiplayerRole.keys()[new_role])

var upnp_thread = null
signal upnp_completed(error)


func _upnp_setup(port: int):
	var upnp = UPNP.new()
	var err = upnp.discover()
	if err != OK:
		push_error(error_string(err))
		upnp_completed.emit(err)
		return

	if not upnp.get_gateway():
		push_warning("UPnP didn't find a Gateway")
		return


	print("UPNP Gateway found:", upnp.get_gateway())
	print("UPNP Gateway is valid?:", upnp.get_gateway().is_valid_gateway())

	if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		upnp.add_port_mapping(port, port, ProjectSettings.get_setting("application/config/name"), "UDP")
		upnp.add_port_mapping(port, port, ProjectSettings.get_setting("application/config/name"), "TCP")
		upnp_completed.emit(OK)
#		print("UPnP port forwarding was set up (hopefully)")

	await(self.tree_exiting)

#	print("UPnP cleaning up port mappings...")

	upnp.delete_port_mapping(port, "UDP")
	upnp.delete_port_mapping(port, "TCP")

#	print("UPnP done.")


func _exit_tree() -> void:
	if Settings.get_var("network_upnp"):
		upnp_thread.wait_to_finish()

	if multiplayer.is_server():
		stop_server()


func _ready():
	logger = get_node("/root/Logger")
	# run UPnP discovery and port setup on a separate thread to avoid blocking the main one
	if Settings.get_var("network_upnp"):
		upnp_thread = Thread.new()
		upnp_thread.start(_upnp_setup.bind(Globals.NET_PORT))

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func spawn_game_state(threaded_map_loading := false):
#	if Globals.game_state:
#		print_debug("trying to spawn a game state but the previous one exists!")
#		await Globals.game_state.tree_exited
#		print_debug("Previous game state freed, creating new one")

#	if is_instance_valid(Globals.game_state) or Globals.game_state != null:
#		Globals.game_state.queue_free()
#		push_warning("Game state wasn't freed before spawning a new one!")
#		await get_tree().process_frame

	print("Spawning game state")
	logger.event(["spawning game state"])
	var game_state = preload("res://Assets/Game/GameState.tscn").instantiate()
	game_state.threaded_map_loading = threaded_map_loading
	Globals.game_state = game_state
	print("Game state instantiated")
	Globals.game_state.name = "GameState"
	get_tree().root.call_deferred(&"add_child", Globals.game_state)
	print("Game state added to scene tree")

	return game_state
#	else:
#		push_warning("Trying to spawn a second GameState")


func cleanup_game_state():
	print("Cleaning up game state")
	logger.event(["cleaning up game state"])
	if Globals.game_state:
		Globals.game_state.queue_free()
	else:
		push_warning("Trying to free a non-existing GameState")

	multiplayer.multiplayer_peer = null
	role = Globals.MultiplayerRole.NONE

	local_character = null
	Globals.current_character = null


func start_server(new_role=Globals.MultiplayerRole.SERVER) -> int:
	role = Globals.MultiplayerRole.INTERMEDIATE
	if new_role == Globals.MultiplayerRole.DEDICATED_SERVER:
		print("Starting dedicated game server...")
		logger.event(["starting dedicated server"])
		#AudioServer.set_bus_mute(0, true)  # Mute sound
	else:
		logger.event(["starting local server"])
		print("Starting game server...")

	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(Globals.NET_PORT, Globals.NET_PEER_LIMIT)

	if err == OK:
		get_tree().get_multiplayer().multiplayer_peer = peer
#		print("Starting server")
#		set_physics_process(true)

		spawn_game_state(false)
		await(Globals.game_state.map_spawned) # wait for the map

		role = new_role

		if role != Globals.MultiplayerRole.DEDICATED_SERVER:
			Globals.game_state.spawn_character(1) # spawn server's local character
			Globals.focus = Globals.Focus.GAME

			get_tree().root.get_node("Main/LoadingScreen").hide()
		#ServerStarted.emit(OK)
	elif err != OK:
		push_error("Cannot start server:", error_string(err))
		logger.event(["failed to start server: ", error_string(err)])
		role = Globals.MultiplayerRole.NONE
		#ServerStarted.emit(err)
	return err


func stop_server():
	logger.event(["stopping server"])
	assert(multiplayer.is_server(), "Trying to stop server, while not being a server")

	# tell all clients to disconnect
	stop_client.rpc()

	cleanup_game_state()
#
#	multiplayer.multiplayer_peer = null
#	role = Globals.MultiplayerRole.NONE

	# dedicated servers don't need this
	if role == Globals.MultiplayerRole.SERVER:
		Globals.focus = Globals.Focus.MENU


# before we can connect to the server's game we need to get some infromation from it and make sure we're compatible
func handshake(host : String):
	while handhshake_stage not in [HandshakeStage.OK or HandshakeStage.ERROR]:
		match handhshake_stage:
			HandshakeStage.NONE:
				peer = ENetMultiplayerPeer.new()
				handhshake_stage = HandshakeStage.PREP
				var err = peer.create_client(host, Globals.NET_PORT)

			HandshakeStage.PREP:
				# create the handshake packet
				var snd = {
					"client_version" : var_to_str(Globals.VERSION),
					"auth_token" : auth_tokens[0] if not auth_tokens.is_empty() else null,
					"user_display_name" : user_character_profile.display_name,
					"request" : "join",
					"platform" : "web" if OS.has_feature("web") else "pc",
				}
				peer.put_var(snd)
				handhshake_stage = HandshakeStage.SENT

			HandshakeStage.SENT:
				pass

			HandshakeStage.OK:
				pass

			HandshakeStage.ERROR:
				pass



#		if err != OK:
#			logger.event(["cannot connect: ", error_string(err)])
#			return err
#
		peer.set_target_peer(1) # send to host


func start_client(host: String) -> int:
#	logger.event(["sending handshake to server ", host])


#	var handhshake_thread = Thread.new()
#	handhshake_thread.start(handshake, Thread.PRIORITY_LOW)
#	var err = handshake(host)

	logger.event(["starting client"])

	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(host, Globals.NET_PORT)


	get_tree().get_multiplayer().multiplayer_peer = peer
#	role = Globals.MultiplayerRole.CLIENT

	if err != OK:
		push_error("Cannot start client:", error_string(err))
		role = Globals.MultiplayerRole.NONE
		get_tree().root.get_node("Main/LoadingScreen").hide()
		if Settings.get_bar("menu_background"):
			get_tree().root.get_node("Main/UI/BackgroundMap").show()

	role = Globals.MultiplayerRole.INTERMEDIATE

	return err


@rpc("call_remote", "any_peer", "reliable")
func stop_client():
	logger.event(["stopping client"])
	assert(role == Globals.MultiplayerRole.CLIENT, "Trying to stop client but the role is not client")
	if not multiplayer.get_remote_sender_id() in [0,1]:
		printerr("Anauthorized disconnect request sent from PID ",\
		multiplayer.get_remote_sender_id(), " to PID ",\
		multiplayer.get_unique_id())
		return
	elif multiplayer.get_remote_sender_id() == 1: # we're being disconnected by the server
		multiplayer.server_disconnected.emit() # trigger the disconnected screen
	else: # we're disconencting on our own volition
		client_disconnecting.rpc_id(1, multiplayer.get_unique_id())
		# check our e-mail one last time
		multiplayer.poll()
		# give our resignation letter time to go out
		await get_tree().process_frame
		# and terminate the network connection
		multiplayer.multiplayer_peer = null

		cleanup_game_state()
		Globals.focus = Globals.Focus.MENU


@rpc("call_remote", "any_peer", "reliable")
func client_disconnecting(pid) -> void:
	logger.event(["client disconnecting"])
	# if the peer requests to leave and we're the server
	if multiplayer.get_remote_sender_id() == pid and\
	multiplayer.is_server():
#		print("Server sees client disconnecting called for PID ", pid, " from PID ", multiplayer.get_remote_sender_id() )
		# let's acknowledge that
		_on_peer_disconnected(pid)


func _on_connected_to_server():
	logger.event(["connected to server"])
	role = Globals.MultiplayerRole.CLIENT
	print("Connected to server. Spawning GameState")
	spawn_game_state()
	print("Spawned. Waiting for the map to load")
	await Globals.game_state.map_spawned  # wait for the map
	print("Waiting 1 extra second for good measure")
	await get_tree().create_timer(1).timeout

	# request that our character is spawned
	print("Requesting spawning a client character")
	Globals.game_state.spawn_character.rpc_id(1, multiplayer.get_unique_id()) # spawn client's local character

	Globals.focus = Globals.Focus.GAME
	# send local character profile
	update_character_profile.rpc(peer.get_unique_id(), inst_to_dict(user_character_profile))

	get_tree().root.get_node("Main/LoadingScreen").hide()


func _on_connection_failed():
	logger.event(["connection failed"])
	role = Globals.MultiplayerRole.NONE
	multiplayer.multiplayer_peer = null

	get_tree().root.get_node("Main/LoadingScreen").hide()


func _on_server_disconnected():
	logger.event(["server disconnected"])
	# DisconnectScreen will handle the rest
	get_tree().paused = true
	get_tree().root.get_node("Main/LoadingScreen").hide()



func _on_peer_connected(pid):
	logger.event(["peer connected: ", pid])
#	prints("Peer connected:", pid)

	if not multiplayer.is_server():
		return

	if Engine.max_fps < 60:
#		print("Peer connected, incresing FPS to at least 60 to avoid affecting other peers")
		Engine.max_fps = min(60, Settings.get_var(&"render_fps_max"))

	Globals.game_state.send_character_profiles_to_peer(pid)
	Globals.game_state.set_match_timer_on_peer(pid)
	Globals.game_state.update_bots()


func _on_peer_disconnected(pid):
	logger.event(["peer disconnected: ", pid])
#	prints("Peer disconnected:", pid)

	# delete the character on clients
	Globals.game_state.free_character.rpc(pid)

	# delete the character on server
	Globals.game_state.free_character(pid)

	Globals.game_state.update_bots()


@rpc("call_remote", "any_peer", "reliable")
func update_character_profile(pid : int, _profile):
	var profile
	if _profile is CharacterProfile:
		profile = _profile
	elif _profile is Dictionary:
		profile = dict_to_inst(_profile)

#	print("MultiplayerState updating character ", pid, " profile: ", _profile)
#	print("Profile parsed: ", profile)

	if Globals.game_state:
#		print("Game state present. Applying character profile")
		Globals.game_state.profiles_by_pid[pid] = profile
		Globals.game_state.update_character_profile(pid, profile)
		return OK
	else:
		push_error("MultiplayerState attempted to add a character profile but no GameState exists to hold it")
		return ERR_UNAVAILABLE
