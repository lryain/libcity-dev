extends MultiplayerSpawner

#var game_state : GameState # reference passed to spawned characters

# {&"owner_pid": int, &"team": int}
func _spawn_custom(params):
	if typeof(params.owner_pid) != TYPE_INT:
		push_error("Invalid player spawn received")
		return
	var character = preload("res://Assets/Characters/Character.tscn").instantiate()
	var controller_scene : PackedScene

	if params.bot:
#		print("Spawner spawning a Bot")
		controller_scene = preload("res://Assets/Characters/CharacterControllerBot.tscn")
	else:
		controller_scene = preload("res://Assets/Characters/CharacterControllerPlayer.tscn")

	character.controller_scene = controller_scene
	character.game_state = Globals.game_state
	character.state = CharacterState.new()
	character.state.team = params.team

#	if params.bot:
#		var fake_bot_pid : int
#		while fake_bot_pid in Globals.game_state.characters_by_pid.keys():
#			fake_bot_pid = randi_range(-1, - (2 << 15))
#
#		params.owner_pid = fake_bot_pid
#		print("Generated fake bot PID: ", fake_bot_pid)

#	if params.owner_pid == MultiplayerState.peer.get_unique_id():
#		character.profile = MultiplayerState.user_character_profile

	# check if needed profile exists locally
	if Globals.game_state.profiles_by_pid.find_key(params.owner_pid):
#		print("Setting character pid ", params.owner_pid, " profile to ", Globals.game_state.profiles_by_pid[params.owner_pid])
		character.profile = Globals.game_state.profiles_by_pid[params.owner_pid]
#		print("Character profile is now ", character.profile, " Triggering apply_profile")
		var err = character.apply_profile()
#		print("Apply profile completed with result ", error_string(err))
#	else:
#		print("GameState couldn't find profile for character ", params.owner_pid)


	# add the new character to the local GameState registry
	Globals.game_state.characters_by_team[params.team].append(character)
	Globals.game_state.characters.append(character)

	Globals.game_state.characters_by_pid[params.owner_pid] = character

	character.global_transform = Globals.game_state.get_spawn_transform(params.team)
	character.set_character_owner(params.owner_pid)

	# register bots separately to facilitate easy spawning/despawning
	if params.bot:
		Globals.game_state.bots_by_pid[params.owner_pid] = character

	return character # custom spawner is required to return the spawned node by the engine
