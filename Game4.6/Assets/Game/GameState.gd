extends Node3D
class_name GameState

signal map_loaded
signal map_spawned

signal peer_profile_updated(pid: int)

signal game_scores_updated
#signal game_is_over()

signal match_started
signal match_ended(winner_team: int)

#signal match_timer_updated(time_left_seconds : int)

signal match_phase_changed

var current_match_phase : Globals.MatchPhase:
	set(value):
		if current_match_phase == value:
			return

		current_match_phase = value
		match_phase_changed.emit(value)

		match current_match_phase:
			Globals.MatchPhase.LOBBY:
				%Lobby.show()
				%HUD.hide()
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

			Globals.MatchPhase.GAME:
				%Lobby.hide()
				%HUD.show()
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		%Lobby.update_numbers_label()


@onready var spawner : MultiplayerSpawner = $CharacterSpawner
@onready var characters_root = $CharactersRoot

# node to parent effects, projectiles etc to so they can be easily disposed of or hidden
@onready var spawn_root = $SpawnRoot

#@export var game_mode : Globals.GameMode

var match_timer : SceneTreeTimer

# should maps be loaded in the main thread or a separate one?
var threaded_map_loading : bool = true

#var map_music_tree : AnimationTree

var updating_bots = false

var characters = [] # an array that holds all characters present in the game

@export var scores_by_team = {
	0 : 0,
	1 : 0,
	2 : 0,
}

var characters_by_team = {
	0: [],
	1: [],
	2: [],
} # a dictionary binding team to an array of characters for fast lookup

# this could be done by checking for nodes, but this seems more robust - unfa
var characters_by_pid = {} # a dictionary for looking up characters by PID
var bots_by_pid = {} # a dictionary for looking up bot players by (fake) PID

var profiles_by_pid = {} # a dictionary for looking up character profiles by pid

@export var map : Node3D
@onready var hud := $HUD

@export var map_path : String:
	set(value):

		if value == map_path:
			#push_warning("Trying to load the same map again")
			return

#		if multiplayer.has_multiplayer_peer():
#			prints("Changing map_path to", value, "on peer", MultiplayerState.peer.get_unique_id())

		map_path = value

		if map:
			unload_map()

		if not map_path.is_empty():
			load_map(threaded_map_loading)


@rpc("authority", "call_remote", "reliable")
func end_match(winner_team: int) -> void:
#	print("Team ", str(Globals.Teams.keys()[winner_team]), " wins!")
	current_match_phase = Globals.MatchPhase.LOBBY
	match_ended.emit(winner_team)
	get_tree().paused = true

	match_timer = null

	var tween = create_tween()
	tween.tween_interval(15)
	tween.finished.connect(start_match)
	tween.play()

	Globals.current_character = null
	for i in characters_by_pid.keys():
		free_character(i)

	map.get_node("Camera3D").set_current(true)

	# propagate this even to all peers
	if multiplayer.is_server():
		rpc(&"end_match", winner_team)

	%Lobby.reset()


func check_win_condition() -> void:
	for i in scores_by_team.keys():
		if scores_by_team[i] >= MultiplayerState.game_config.match_score_limit:
			end_match(i)
			return


#@rpc("any_peer","call_local","reliable")
func increment_team_score(team: int, who_requests: Node) -> void:
	if MultiplayerState.game_config.game_mode in [ Globals.GameMode.TEAM_DEATHMATCH, Globals.GameMode.DEATHMATCH, Globals.GameMode.DUEL ]:
		if not who_requests is Character:
#			printerr("GameState rejecting a score increment request from ", who_requests," because the game mode is ", Globals.GameMode.keys()[MultiplayerState.game_config.game_mode])
			return
	elif MultiplayerState.game_config.game_mode in [ Globals.GameMode.CONTROL_POINTS ]:
		if not who_requests is ControlPoint:
#			printerr("GameState rejecting a score increment request from ", who_requests," because the game mode is ", Globals.GameMode.keys()[MultiplayerState.game_config.game_mode])
			return
#	else:
#		print("GameState taking a score increment request from ", who_requests," because the game mode is ", Globals.GameMode.keys()[MultiplayerState.game_config.game_mode])

	scores_by_team[team] += 1
	game_scores_updated.emit()

	if multiplayer: # don't process the resst if this was not a remote call
		if multiplayer.get_remote_sender_id() != 0:
			return

	if multiplayer.is_server():
		check_win_condition()
	else:
		increment_team_score.rpc_id(1, team)


func _ready():
	set_process(false)
	spawner.spawn_function = spawner._spawn_custom

	if not map:
		map_path = "res://Assets/Maps/%s.tscn" % [MultiplayerState.game_config.map]
#		print("Map path: ", map_path)
	else:
#		print("GameState: Map overide present: ", map.name)
		return # workaround menu BG map trouble

	if multiplayer.has_multiplayer_peer():
		# copy local characetr profile to GameState's
		profiles_by_pid[MultiplayerState.peer.get_unique_id()] = MultiplayerState.user_character_profile
		profiles_by_pid[0] = MultiplayerState.user_character_profile
		if multiplayer.is_server():
			# send profiles for all known characters to the newly connecteded client
			multiplayer.peer_connected.connect(send_character_profiles_to_peer)

	%Lobby.reset()


func _process(delta):
	if ResourceLoader.load_threaded_get_status(map_path) == ResourceLoader.THREAD_LOAD_LOADED:
		map_loaded.emit()


func mute_game_sound(mute: bool):
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == "SFX":
			AudioServer.set_bus_mute(i, mute)


# by default use threaded resource loader
func load_map(threaded := false):
	if has_map():
		unload_map()

	var map_resource : PackedScene

	print("Starting map loading in %s mode..." % ["threaded" if threaded else "blocking"] )
	var time = Time.get_ticks_msec()
	if threaded:
		ResourceLoader.load_threaded_request(map_path, "PackedScene", true)
		set_process(true)
		await(map_loaded)
		set_process(false)
		map_resource = ResourceLoader.load_threaded_get(map_path)
	else:
		map_resource = load(map_path)

	# fallback, because sometimes the above fails :/
	if not map_resource:
		map_resource = load(map_path)

	time = Time.get_ticks_msec() - time
	prints("Map loaded in", time,"miliseconds")
	print("Loaded map: ", map_resource)
	map = map_resource.instantiate()
	map.name = "Map"
	add_child(map)
	$CharactersRoot.hide()
	$SpawnRoot.hide()

	mute_game_sound(true)

	print("Map spawned")
#	map.connect("match_finished", end_match)

	if not map.map_is_ready:
		await(map.map_ready)
		$CharactersRoot.show()
		$SpawnRoot.show()
		mute_game_sound(false)

	map.get_node("Music").volume_db = -80
	map.get_node("Music").play()
	var tween = create_tween()
	tween.tween_property(map.get_node("Music"), "volume_db", 0, 4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.play()

	await get_tree().process_frame
	map_spawned.emit()

	update_bots()

	$Lobby.connect("match_start_countdown_over", start_match)

#	map_music_tree = map.get_node("Music").get_node("AnimationTree") as AnimationTree

#	map_music_tree.active = true
#	map_music_tree[&"parameters/conditions/a"] = false
#	map_music_tree[&"parameters/conditions/b"] = false
#	map_music_tree[&"parameters/conditions/c"] = false
#	map_music_tree[&"parameters/conditions/d"] = false
#	map_music_tree[&"parameters/conditions/e"] = false

#	await(map.ready)
#	Globals.focus = Globals.Focus.GAME


func has_map():
	return map != null and is_instance_valid(map)


func unload_map():
	if map:
		if is_instance_valid(map):
			map.queue_free()


@rpc("any_peer", "call_remote", "reliable")
func start_match():
#	if not is_instance_valid(scores_by_team):

	for i in scores_by_team.keys():
		scores_by_team[i] = 0

	for i in characters:
		if is_instance_valid(i):
			if is_instance_valid(i.state):
				i.state.kills = 0
				i.state.deaths = 0

	map.start_match()

	if multiplayer:
		if multiplayer.is_server(): # only game host can set the timer
			set_match_timer(MultiplayerState.game_config.match_time_limit_minutes * 60 * 1000)

	get_tree().paused = false

	current_match_phase = Globals.MatchPhase.GAME
	update_bots()
	match_started.emit()

#func request_character_profiles():
#	send_character_profiles_to_peer.rpc_id(1, MultiplayerState.peer.get_unique_id())


func _exit_tree() -> void:
	if not map: # workaround menu BG map trouble
		Globals.current_character = null
		MultiplayerState.local_character = null

	# disabling posible leftover postprocess (death effect)
	var environment = get_viewport().find_world_3d().environment
	if environment:
		environment.adjustment_enabled = false


#@rpc("call_remote", "any_peer", "reliable")
func send_character_profiles_to_peer(pid : int):
			# send all known character profiles to the newly joined client
	for i in profiles_by_pid.keys():
#		print("Server sending profile ", i, " to new peer ", pid, ". Profile: ", profiles_by_pid[i])
#		print("Profile as str: ", var_to_str(profiles_by_pid[i]))
		var profile = inst_to_dict(profiles_by_pid[i])
#		print("Profile as dict: ", profile)
		update_character_profile.rpc_id(pid, i, profile)


func game_config_changed():
	update_bots()


# spawn and despawn bots accorgng to GameConfig
func update_bots():
	if not is_inside_tree():
		return

	if updating_bots: # this can only run once at a time
		return

	if multiplayer:
		if not multiplayer.is_server(): # only game server can manage bots
			return

	updating_bots = true

#	print("GameState updating bots")
	var target_bot_amount = MultiplayerState.game_config.bot_amount
#	print("user-defined target_bot_amount ", target_bot_amount)
	var current_bot_amount = bots_by_pid.size()
#	print("current_bot_amount ", current_bot_amount)
	# there is always at least one player - otherwise why are we even here?
	var current_player_amount = max(1, characters_by_pid.keys().filter(func(pid): return pid > 0).size())
#	print("current_player_amount ", current_player_amount)
#	print("Current bot amount: ", current_bot_amount)

	if MultiplayerState.game_config.bots_fill_vacant:
#		print("Bots fill vacant spaces")
		target_bot_amount = max((target_bot_amount + 1) - current_player_amount, 0)

#	print("Target bot amount: ", target_bot_amount)

	# too many bots
	while current_bot_amount > target_bot_amount:
#		print("Removing a bot")
		await(get_tree().create_timer(0.1).timeout)
		var bot = bots_by_pid.keys().pick_random()
		if bot:
			free_character(bot)
			current_bot_amount -= 1
		else:
			printerr("GameState tried to free a bot character that was ", bot)

	# not enough bots
	while current_bot_amount < target_bot_amount:
#		print("Adding a bot")
		await(get_tree().create_timer(0.1).timeout)
		spawn_character(0, true)
		current_bot_amount += 1

	# balancing teams

	# for -vs- mode all we do is move the bots to team PLUM
	if MultiplayerState.game_config.bots_vs_humans:
		for i in bots_by_pid.keys(): # iterate to find a bot on the right team
			if bots_by_pid[i].state.team == Globals.Teams.LIME:
#				print("Moving bot ", bots_by_pid[i].profile.display_name, " to team PLUM")
				change_character_team(i, Globals.Teams.PLUM)
	else: # for non-vs mode we need to do more work
		var teams_balanced = false
		while not teams_balanced:
#			print("Balancing teams")
			var team_lime = characters_by_team[Globals.Teams.LIME].size()
			var team_plum = characters_by_team[Globals.Teams.PLUM].size()

#			print("Team LIME: ", team_lime, " Team PLUM: ", team_plum)

			# does either team have sigificantly more players+bots than the other one?
			if team_lime - 1 > team_plum:
#				print("Lime has too many")
				for i in bots_by_pid.keys(): # iterate to find a bot on the right team
					if bots_by_pid[i].state.team == Globals.Teams.LIME:
#						print("Moving bot ", bots_by_pid[i].profile.display_name, " to team PLUM")
						change_character_team(i, Globals.Teams.PLUM)
						break # we only need one

			elif team_plum - 1 > team_lime:
#				print("Plum has too many")
				for i in bots_by_pid.keys(): # iterate to find a bot on the right team
					if bots_by_pid[i].state.team == Globals.Teams.PLUM:
#						print("Moving bot ", bots_by_pid[i].profile.display_name, " to team LIME")
						change_character_team(i, Globals.Teams.LIME)
						break # we only need one
			else:
#				print("Teams are balanced now!")
				teams_balanced = true

	updating_bots = false


func get_spawn_transform(for_team: int = 0) -> Transform3D:
	if is_instance_valid(map):
		return map.get_spawn_transform(for_team)
	else:
		printerr("GameState spawning character before the map is spawned!")
		return Transform3D.IDENTITY


@rpc("call_remote", "any_peer", "reliable")
func spawn_character(pid: int, bot: bool = false):

	# can't spawn any characters until the map is ready
	assert(is_instance_valid(map))

	if not map.map_is_ready:
		await(map.map_ready)

#	print("GameState spawning character for PID ", pid, ". Requested by PID ", multiplayer.get_remote_sender_id())

	if multiplayer.get_remote_sender_id() != 0 and multiplayer.get_remote_sender_id() != pid:
		push_error("Remote peer ", multiplayer.get_remote_sender_id(), " tries to spawn a character for PID ", pid ,". Ignoring.")
		return


	if multiplayer.is_server():
		var team : int

		# decide what team to put the character on
		if not MultiplayerState.game_config.bots_vs_humans:
			if characters_by_team[1].size() > characters_by_team[2].size():
				team = 2 # team 1 had more people
			elif characters_by_team[1].size() < characters_by_team[2].size():
				team = 1 # team 2 had more people
			else:
				team = randi_range(1,2) # both teams had the same amount of people
		else: # in vs mode bots go to one team and humans to another
			if bot:
				team = 2
			else:
				team = 1
		if bot:
#			print("Spawning a bot character")
			var profile = CharacterProfile.new()
			profile.badges.append(Badges.Badge.BOT)
			profile.display_name = NameGenerator.generate()
			profile.display_color = Color.from_hsv(randf(), randf_range(0.6, 0.9), randf_range(0.6,1))
			profile.voice_pitch = randf_range(0.5, 1.5)

#			print("Generated bot profile: ", profile)
			pid = - (bots_by_pid.size() + 1)

#			print("Generated bot PID: ", pid)

			update_character_profile(pid, profile)
			update_character_profile.rpc(pid, inst_to_dict(profile))

		# bot tells the spawner what CharacterController will be spawned
#		print("GameState calls spawn() for character PID ", pid, " team ", team, " that ", "IS" if bot else "is not", "a bot")

		if current_match_phase != Globals.MatchPhase.GAME:
			await $Lobby.match_start_countdown_over

		$CharacterSpawner.spawn({&"owner_pid" : pid, &"team" : team, &"bot" : bot})

	# try to fix possible active camera issues after spawning a new character
	# this will cause a redundant 2nd call to make_current when starting a server,
	# but otherwise new characters will steal the camera
	if Globals.current_character:
		Globals.current_character.update_camera()

	update_bots()


@rpc("any_peer", "call_remote", "reliable")
func set_match_timer(timer_msec: int, weight : float = 1.0) -> void:
	if not multiplayer:
		return

#	print("GameState on PID, ", multiplayer.get_unique_id(), " recieved request to change match timer to ", timer_msec, " sent from PID ", multiplayer.get_remote_sender_id(), " with weight ", weight)

	var time_left : float

	if match_timer:
		time_left = match_timer.time_left
	else:
		time_left = timer_msec as float / 1000

	time_left =  lerp(time_left, timer_msec as float / 1000, clamp(0, 1, weight))

	match_timer = get_tree().create_timer(time_left, true, false, true)
	match_timer.timeout.connect(check_win_condition)


func set_match_timer_on_peer(pid: int) -> void:
	if not multiplayer:
		return

	if not multiplayer.is_server():
		push_warning("Client's GameState trying to set match timer. Only host is supposed to do this. Ignoring")
		return

#	print("Server setting timer on peer ", pid)
	var refine_passes : int = 4
	_set_match_timer_refine(pid, 0, refine_passes)


func _set_match_timer_refine(pid, i, refine_passes):

#	print("Refine pass ", i)
	var network_peer = MultiplayerState.peer.get_peer(pid)
	if not network_peer or not is_instance_valid(match_timer):
#		print("Clock sync failed. PID ", pid, " is gone.")
		return

	var ping = network_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)

	set_match_timer.rpc_id(pid, round(match_timer.time_left * 1000 - (ping / 2)), (refine_passes as float - i as float / refine_passes as float))

	i += 1

	if i < refine_passes:
		get_tree().create_timer(1).timeout.connect(_set_match_timer_refine.bind(refine_passes).bind(i).bind(pid))
	else:
		# refine the clock forever, but less often with the smallest weight
		get_tree().create_timer(5).timeout.connect(_set_match_timer_refine.bind(refine_passes).bind(refine_passes).bind(pid))


@rpc("call_remote", "any_peer", "reliable")
func free_character(pid: int):
#	print("GameState freeing character for PID ", pid, ". Requested by PID ", multiplayer.get_remote_sender_id())

	# only accept a local call or a remote call from the server
	var sender = multiplayer.get_remote_sender_id()
	if not sender in [0,1]:
		push_warning("PID ", sender, " tried to free character for PID ", pid, " request denied.")
		return

	if characters_by_pid.has(pid):
		if is_instance_valid(characters_by_pid[pid]):
			characters_by_pid[pid].queue_free()
			characters_by_pid.erase(pid)
			if pid < 0: # PIDs below zero are fake bot IDs
				bots_by_pid.erase(pid)
	update_bots()

	#Globals.current_character.update_camera()


@rpc("call_remote", "any_peer", "reliable")
func change_character_team(pid: int, new_team: int):
	var old_team = characters_by_pid[pid].state.team

#	print("Erasaing character ", pid, " from old team ", str(Globals.Teams.keys()[old_team]))
#	print("Characters by team before: ", characters_by_team)

	if characters_by_pid[pid] in characters_by_team[old_team]:
		characters_by_team[old_team].erase(characters_by_pid[pid])

	characters_by_team[new_team].append(characters_by_pid[pid])
	characters_by_pid[pid].state.team = new_team

#	print("Characters by team after: ", characters_by_team)

	var character : Character = characters_by_pid[pid]

	# we need to clear this
	character.state.kills = 0
	character.state.deaths = 0

	# force a respawn
	character.respawn()
	character.apply_team_state()

	update_bots()


@rpc("call_remote", "any_peer", "reliable")
func update_character_profile(pid : int, _profile):
	var profile : CharacterProfile

	if _profile is CharacterProfile:
		profile = _profile
	elif _profile is Dictionary:
		profile = dict_to_inst(_profile)
	else:
#		push_error("GameState recived an invalid char profile update")
		return

	# if the profile was not present before
#	if not profiles_by_pid.keys().has(pid):
#		print("Game state: new peer's profile added for PID ", pid)

	profiles_by_pid[pid] = profile

	peer_profile_updated.emit(pid)
#	print("Game state: peer's profile updated for PID ", pid)

	var character = characters_root.get_node_or_null(str(pid))

	if character:
#		print("Found character node ", character.name, " and applying profile")
		character.profile = profile
		character.apply_profile()
#	else:
#		print_debug("GameState updated profile for character ", pid," that isn't spawned yet")


