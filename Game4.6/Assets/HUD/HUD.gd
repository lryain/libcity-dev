extends Control


#signal show_disconnect_screen(frame_capture: Texture2D)

var environment : Environment:
	set(value):
		environment = value

		# overwrite adjustement settings to provide a consistent death screen look across all levels
		environment.adjustment_enabled = false
		environment.adjustment_saturation = 0.2
		environment.adjustment_brightness = 1.3
		environment.adjustment_contrast = 1.3
		environment.adjustment_color_correction = null

var pain: float = 0:
	set(value):
#		$Overlays/Damage.material.set('shader_param/Damage', value)
#		value = max(0, pain)
		pain = value
#		print("pain: ", pain)
		$Overlays/Damage.color.a = pain
	get:
		return pain
#		return $Overlays/DamageStatic.material.get('shader_param/Damage')

@onready var scoretab_1_header = %Team1ScoreTab.text
@onready var scoretab_2_header = %Team2ScoreTab.text

@onready var tween : Tween
var killed_tween : Tween

var crosshair_dimmed = false

# manage HUD visibility
func _on_focus_changed(new, previous):
	if new in [Globals.Focus.GAME, Globals.Focus.CHAT] and\
	Globals.game_state.current_match_phase == Globals.MatchPhase.GAME:
		show()
		show_hud()
	else:
		hide()


func update_character_profile(character : Character):
	if character:
		if character.profile:
			%CharacterDisplayName.text = character.profile.display_name
			%CharacterDisplayName.modulate = Globals.team_colors[character.state.team]
			%CharacterBadge.texture = Badges.get_top_priority_badge_texture(character.profile.badges)

			if character.state.team == 1:
				%YouAreOnTeam1.show()
				%YouAreOnTeam2.hide()
				%Team1BG.modulate.a = 1
				%Team2BG.modulate.a = 0.5
				%CurrentCharacter.alignment = 0 # ALIGN_BEGIN, but the ENUM doesn't exist
			elif character.state.team == 2:
				%YouAreOnTeam2.show()
				%YouAreOnTeam1.hide()
				%Team2BG.modulate.a = 1
				%Team1BG.modulate.a = 0.5
				%CurrentCharacter.alignment = 2 # ALIGN_END, but the ENUM doesn't exist

		else:
			printerr("HUD trying to update character profile, but the character's profile is ", character.profile)
	else:
		printerr("HUD trying to update character profile, but the character is ", character)


# recieves the signal from Globals
func _on_current_character_changed(new_character: CharacterBody3D, old_character: CharacterBody3D) -> void:
	# disconnect the old character (if exists)
	if old_character:
		old_character.character_hud_update.disconnect(character_hud_update)

	# connect the new character (if exists)
	if new_character:
		new_character.character_hud_update.connect(character_hud_update)
		$DamageCompass.character = new_character
		update_character_profile(new_character)

	# show
	visible = true if new_character and Settings.get_var('render_hud') else false


@rpc("any_peer","call_remote","reliable")
func game_over(winner_team) -> void:
	if multiplayer:
		if multiplayer.get_remote_sender_id() != 1: # called from server
			printerr("Game over called from PID ", multiplayer.get_remote_sender_id(), ". Ignoring")
			return
	print("HUD recieved info that team ", winner_team, " won")
	scoretab(true, winner_team)

	hide_hud()

	# if we're the server, make everyone see the scoretab
	if multiplayer:
		if multiplayer.is_server():
			game_over.rpc(winner_team)


func damage(hp) -> void:
#	print("HUD damage ", hp)
	pain += hp / 20


func hide_hud() -> void:
	$Crosshair.hide()
	$Chat.hide()
	%Stats.hide()

func show_hud() -> void:
	$Crosshair.show()
	$Chat.show()
	%Stats.show()


func _on_settings_var_changed(var_name, value):
	if var_name == 'render_hud':
		visible = value


func on_game_state_changed(new_game_state, old_game_state):
#	print("HUD connecting signals from new GameState")
#	print("Old game state is ", old_game_state, " and new game state is ", new_game_state, " while current game state is ", Globals.game_state)
	assert(new_game_state == Globals.game_state, "on_game_state_changed reports incorrect new game state!")
	assert(is_instance_valid(new_game_state), "HUD trying to connect to a Game State that is " + str(new_game_state))
	if new_game_state:
		new_game_state.match_started.connect(on_match_started)
		new_game_state.match_ended.connect(on_match_ended)
		new_game_state.game_scores_updated.connect(update_scoretab)
		new_game_state.game_scores_updated.connect(update_team_scores)
#		new_game_state.match_timer_updated.connect(match_timer_updated)

#	return
	if is_instance_valid(old_game_state):
		old_game_state.match_started.disconnect(on_match_started)
		old_game_state.match_ended.disconnect(on_match_ended)
		old_game_state.game_scores_updated.disconnect(update_scoretab)
		old_game_state.game_scores_updated.disconnect(update_team_scores)
#		old_game_state.match_timer_updated.disconnect(match_timer_updated)

#	update_scoretab()
	update_team_scores()

	# initial updates to catch up to existing remote game state

func on_match_started() -> void:
#	pass
#	update_scoretab()
	update_team_scores()


func on_match_ended() -> void:
#	pass
	update_scoretab()
	update_team_scores()


func _ready() -> void:
	# hud is invisible by default, only shows when gets a character to follow
	hide()

	Globals.current_character_changed.connect(_on_current_character_changed)
	Globals.focus_changed.connect(_on_focus_changed)

	Settings.var_changed.connect(_on_settings_var_changed)

	# to catch future changes
	Globals.game_state_changed.connect(on_game_state_changed)
	# to catch up to changes made before this scene was instantiated
	if is_instance_valid(Globals.game_state):
		on_game_state_changed(Globals.game_state, null)

	$TopBar.show()
	$Overlays.show()
	$RespawnCountdown.hide()
	$Crosshair.show()

	$TeamLabel.hide()
	$KilledAndKilledBy.show() # this has to be visible, but the children are hidden until needed
	%KilledBy.hide()
	%Killed.hide()
	scoretab(false)

	%YouAreOnTeam1.color = Globals.team_colors[1]
	%YouAreOnTeam2.color = Globals.team_colors[2]

	%Team1BG.color = Globals.team_colors[1]
	%Team2BG.color = Globals.team_colors[2]

	pain = 0


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action("show_scoretab"):
		scoretab(event.is_pressed())


func get_pid_info(pid: int) -> Dictionary:
	# fallback data
	var pid_info = {
		'name' = "---",
		'color' = Color.from_hsv(0,0, 0.5),
		'team' = 0,
		'ping' = "?",
		'loss' = "?",
		}

	if not Globals.game_state.characters_by_pid[pid]:
		return pid_info

	if Globals.game_state.characters_by_pid[pid].is_queued_for_deletion():
		return pid_info

	if Globals.game_state.characters_by_pid.has(pid):
		if Globals.game_state.characters_by_pid[pid].profile:
			pid_info.name = Globals.game_state.characters_by_pid[pid].profile.display_name
			pid_info.color = Globals.game_state.characters_by_pid[pid].profile.display_color
			pid_info.team = Globals.game_state.characters_by_pid[pid].state.team

	var ping = Globals.game_state.characters_by_pid[pid].state.ping
	if not ping:
		ping = "?"
	var packet_loss = Globals.game_state.characters_by_pid[pid].state.packet_loss
	if not packet_loss:
		packet_loss = "?"
	return pid_info


func update_scoretab() -> void:
	if not is_instance_valid(Globals.game_state):
		return

	if Globals.game_state.current_match_phase != Globals.MatchPhase.GAME:
		return

#		if not is_instance_valid(Globals.game_state.scores_by_team):
#			printerr("HUD trying to access team scores but they are ", Globals.game_state.scores_by_team)
#			return

	%Team1ScoreTab.clear()
	%Team2ScoreTab.clear()
	%Team1ScoreTab.append_text(scoretab_1_header + "   : " + str(Globals.game_state.scores_by_team[1]) + "\n\n")
	%Team2ScoreTab.append_text(scoretab_2_header + "   : " + str(Globals.game_state.scores_by_team[2]) + "\n\n")
#	%Team1Score.text = str(Globals.game_state.scores_by_team[1])
#	%Team1Score.text = str(Globals.game_state.scores_by_team[2])

	var scores = []

	for pid in Globals.game_state.characters_by_pid.keys():
		if is_instance_valid(Globals.game_state.characters_by_pid[pid]):
			if is_instance_valid(Globals.game_state.characters_by_pid[pid].state):
				scores.append(Globals.game_state.characters_by_pid[pid].state.kills)
			else:
				printerr("Scoreboard trying to access character state that doesn't exist any more")
		else:
			printerr("Scoreboard trying to access character that doesn't exist any more")

	scores.sort()
	scores.reverse()

	var done = []

	for score in scores:
		for pid in Globals.game_state.characters_by_pid.keys():
			if is_instance_valid(Globals.game_state.characters_by_pid[pid]):
				if Globals.game_state.characters_by_pid[pid].state.kills == score:
					if pid not in done:
						var info = get_pid_info(pid)

						# until ping and packet loss measurnments are working, let's not show them
	#					var entry = "[b][color=\"%s\"]%s[/color][/b]\t(%s ms · %s)\n" % [
						var entry = "[b][color=\"%s\"]%s[/color][/b]\n" % [
							Color(info.color).to_html(),
							info.name
	#						str(info.ping),
	#						str(info.loss)
						]

						var label = %Team1ScoreTab if info.team == 1 else %Team2ScoreTab

						label.append_text("[b]" + str(score) + "[/b]")
						if Globals.game_state.characters_by_pid[pid].profile:
							label.add_image(Badges.get_top_priority_badge_texture(Globals.game_state.characters_by_pid[pid].profile.badges), 16, 16, Color.from_hsv(0,0,1,1), INLINE_ALIGNMENT_CENTER)
						else:
							label.add_image(Badges.get_badge_texture(Badges.Badge.ERROR), 16, 16, Color.from_hsv(0,0,1,1), INLINE_ALIGNMENT_CENTER)

						label.append_text(entry)
						done.append(pid)


func check_match_over() -> void:
	if not multiplayer.is_server():
		return

	if Globals.game_state.scores_by_team[1] >= MultiplayerState.game_config.match_score_limit:
		game_over(1)
	elif Globals.game_state.scores_by_team[2] >= MultiplayerState.game_config.match_score_limit:
		game_over(2)
	elif Globals.game_state.match_timer:
		if Globals.game_state.match_timer.time_left <= 0:
			if Globals.game_state.scores_by_team[1] > Globals.game_state.scores_by_team[2]:
				game_over(1)
			elif Globals.game_state.scores_by_team[1] < Globals.game_state.scores_by_team[2]:
				game_over(2)


func update_team_scores():
#	return
	if is_instance_valid(Globals.game_state):
		if Globals.game_state.current_match_phase != Globals.MatchPhase.GAME:
			return

#		print("Team scores are: ", Globals.game_state.scores_by_team)
		%Team1Score.text = str(Globals.game_state.scores_by_team[1])
		%Team2Score.text = str(Globals.game_state.scores_by_team[2])
#		else:
#			printerr("HUD trying to access team scores but they are ", Globals.game_state.scores_by_team)


func scoretab(show: bool, winner_team = null) -> void:
#	update_team_scores()

	if show:
		update_scoretab()
		$ScoreTable.show()
	else:
		$ScoreTable.hide()

	if winner_team:
		%ScoreTabHeader.text = "Match over! Team %s won!" % str(Globals.Teams.keys()[winner_team])
	else:
		if Globals.game_state:
			%ScoreTabHeader.text = "Playing %s until %s points or %s minutes" % [
				str(Globals.GameMode.keys()[MultiplayerState.game_config.game_mode]).capitalize(),
				str(MultiplayerState.game_config.match_score_limit),
				str(MultiplayerState.game_config.match_time_limit_minutes),
				]


func check_scoreboard() -> void:
	if Globals.game_state.characters.size() <= 1:
		return # if we're the sole player in the server, stop here

#	var pid : int = MultiplayerState.peer.get_unique_id()
	var player = MultiplayerState.local_character

	# SCORE, RANK, GAP/LEAD
	get_node("ScoreRank").text = "SCORE: " + str(player.state.kills)

	var score : int = player.state.kills
	var scores = []

	for i in Globals.game_state.characters:
		scores.append(i.state.kills)

	scores.sort()
	scores.reverse()
	var rank = scores.find(score) + 1

	scores.remove_at(scores.find(score))
	scores.sort()
	scores.reverse()

	var lead = score - scores[0]

	get_node("ScoreRank").text = "SCORE: %s\nRANK: " % str(score)

	if lead > 0:
		get_node("ScoreRank").text	+= "%s\nLEAD: %s" % [str(rank), str(lead)]
	else:
		get_node("ScoreRank").text	+= "%s\nGAP: %s" % [str(rank), str(-lead)]


func _process(delta) -> void:
	if pain > 0:
		pain = lerpf(pain, 0, delta)

#	$Overlays/Damage.material["shader_params/Amount"] = 1.0

	if MultiplayerState.role == Globals.MultiplayerRole.NONE: # don't do anything if we're offline
		return

	if Globals.current_character:
		var cur_char_state : CharacterState = Globals.current_character.state

		if cur_char_state.spawn_time > 0 and not cur_char_state.alive:
			var countdown : float = max(0, cur_char_state.spawn_time - (Time.get_ticks_msec() / 1000.0))
#			print(cur_char_state.spawn_time," ",Time.get_ticks_msec())
			$RespawnCountdown.text = "RESPAWNING IN %1.2f SECONDS..." % float(countdown)
	#		$RespawnCountdown.visible = true
	#	else:
	#		$RespawnCountdown.visible = false

	%ScoreLimit.text = str(MultiplayerState.game_config.match_score_limit)

	if $ScoreTable.visible: # update the scores every frame when player is watching the score table
		update_scoretab()

	if Globals.game_state:
#		update_team_scores()
#		check_match_over()
		if Globals.game_state.match_timer:
			update_match_timer(roundi(Globals.game_state.match_timer.time_left * 1000))
#
#	if Globals.current_character:
#		update_character_profile(Globals.current_character)


	# scrolling the scoretab

#	if Input.is_action_pressed("ui_page_up"):
#		print("HUD: scroll up")
#		%ScoreTabScrollContainer.scroll_vertical -= delta * 100
#	elif Input.is_action_pressed("ui_page_down"):
#		print("HUD: scroll down")
#		%ScoreTabScrollContainer.scroll_vertical += delta * 100

	# time heals pain

#	if MultiplayerState.local_character != null: # alive
#	else: # dead
#		pain *= 1 - delta / MultiplayerState.respawn_delay


func dim_crosshair(enable := true) -> void:
	if enable:
		$Crosshair.modulate = Color(Color.WHITE, 0.05)
		crosshair_dimmed = true
	else:
		$Crosshair.modulate = Color(Color.WHITE, 1)
		crosshair_dimmed = false


# this function recieves and processes updates from the current game character
func character_hud_update(update: CharHudUpdate) -> void:

	if update.special_type != CharMovement.SpecialType.NONE:
		var special_name = str(CharMovement.SpecialType.keys()[update.special_type])
		$Stats/JetpackBar.value = update.special_amount
		$Stats/JetpackBar/Label.text = special_name.to_upper() + ": " + str(round(update.special_amount * 100)).lpad(3, " ") + "%"

#	print("HUD got update, current weapon: ", update.current_weapon)

	if update.zoom:
		if update.zoom_amount > 0:
			dim_crosshair(true)
			$Overlays/Vignette.modulate = Color(Color.WHITE, smoothstep(0, 1, update.zoom_amount))
		else:
			dim_crosshair(false)
			$Overlays/Vignette.modulate = Color(Color.WHITE, 0)

	elif update.current_weapon == Weapons.Weapon.NONE: # dim croshair when no weapon is equipped
			dim_crosshair(true)
	elif update.current_weapon != null: # undim when a weapon is ready
			dim_crosshair(false)


	if update.got_damage or update.got_healing or update.got_spawned:
		var health_bar = get_node("Stats").get_node("HealthBar")
		health_bar.get_node("Label").text = "HP: " + str(update.state.health).lpad(3, " ") + " / " + str(update.character.max_health).lpad(3, " ")
		health_bar.value = update.state.health
		health_bar.max_value = update.character.max_health

		if update.got_damage:
#			print("Adding damage to pain: ", update.got_damage.damage_amount)
			pain += clampf(update.got_damage.damage_amount / 50.0, 0.33, 1.5) * 3
#			print("HUD spawns a damage compass marker")
			$DamageCompass.add_marker(update.got_damage)

			if update.got_killed:
				pain += 1

		elif update.got_spawned:
			pain = 0

	if update.got_killed:
		$DamageCompass.hide()
		environment = get_viewport().find_world_3d().environment
		if environment:
			environment.adjustment_enabled = true

		if update.got_damage is DamageAttack:
			%KilledBy/Attacker/Badge.texture =\
			Badges.get_top_priority_badge_texture(update.got_damage.attacker.profile.badges)

			if update.got_damage.attacker == update.character:
				%KilledBy/Attacker/Name.text = "yourself"
				%KilledBy/Attacker/Name.label_settings.font_color = Color(0,0,0)
				%KilledBy/Attacker/Badge.hide()
				$KilledAndKilledBy/KilledBy/Attacker/Margin.hide()
			else:
				%KilledBy/Attacker/Name.text = update.got_damage.attacker.profile.display_name
				%KilledBy/Attacker/Name.label_settings.font_color = update.got_damage.attacker.profile.display_color
				%KilledBy/Attacker/Badge.show()
				$KilledAndKilledBy/KilledBy/Attacker/Margin.show()


		elif update.got_damage is DamageFall:
			%KilledBy/Attacker/Name.text = update.got_damage.kill_message()
			%KilledBy/Attacker/Name.label_settings.font_color = Color(1,1,1)
			%KilledBy/Attacker/Badge.hide()
		else:
			%KilledBy/Attacker/Name.text = "something"
			%KilledBy/Attacker/Name.label_settings.font_color = Color(0.5,0.5,0.5)
			%KilledBy/Attacker/Badge.hide()

		var killer_tween = create_tween()
		%KilledBy/Attacker/Name.visible_ratio = 0
		%KilledBy.show()
		killer_tween.tween_property(%KilledBy/Attacker/Name, "visible_ratio", 1, 1)
		killer_tween.play()
		$Crosshair/Baseline.hide()
		$Stats.hide()
		$RespawnCountdown.show()
#		environment.adjustment_saturation = 0
#		environment.adjustment_contrast = 1.5
	elif update.got_spawned and environment:
		environment.adjustment_enabled = false
#		environment.adjustment_saturation = 1
#		environment.adjustment_contrast = 1

	if update.did_damage:
		$Crosshair.hit()
	elif update.did_kill:
		$Crosshair.kill()

		%Killed/Victim/Name.text = update.did_kill.profile.display_name
		%Killed/Victim/Name.label_settings.font_color = update.did_kill.profile.display_color

		%Killed/Victim/Badge.texture =\
		Badges.get_top_priority_badge_texture(update.did_kill.profile.badges)
		%Killed/Victim/Badge.show()

		if killed_tween is Tween:
			if killed_tween.is_running():
				killed_tween.kill()

		killed_tween = create_tween()
		%Killed/Victim/Name.visible_ratio = 0
		%Killed.modulate = Color(1,1,1,1)
		killed_tween.tween_property(%Killed/Victim/Name, "visible_ratio", 1, 0.25)
		killed_tween.tween_property(%Killed, "modulate", Color(1,1,1,0), 1)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_delay(1)
		killed_tween.finished.connect(%Killed.hide)
		killed_tween.play()
		%Killed.show()


	if update.got_spawned:
		update_character_profile(update.character)
		update_team_scores()

		$Crosshair/Baseline.show()

		$Stats.show()
		$RespawnCountdown.hide()
		%KilledBy.hide()
		$DamageCompass.clear_markers()
		$DamageCompass.show()

		$TeamLabel.text = "YOU ARE ON TEAM %s" % [Globals.Teams.keys()[update.state.team]]
		$TeamLabel.label_settings.font_color = Globals.team_colors[update.state.team]
		if tween:
			if tween.is_running():
				tween.kill()
		$TeamLabel.modulate = Color.WHITE
		tween = create_tween()
		tween.tween_property($TeamLabel.label_settings, "font_size", 44 , 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).from(91)
		tween.tween_interval(2)
		tween.tween_property($TeamLabel, "modulate", Color(1,1,1,0),1)
		tween.finished.connect($TeamLabel.hide)
		$TeamLabel.show()
		tween.play()


func _on_visibility_changed() -> void:
	if visible: # can't show if HUD is disabled
		if Settings.get_var('render_hud') == false:
			visible = false

#		update_character_profile()


func update_match_timer(time_remaining_msec : int) -> void:
	if time_remaining_msec >= 0:
		%Time.text = "%02d%s%02d" % [
			roundi(time_remaining_msec as float / 1000 / 60), # minutes
			":", #if time_remaining_seconds % 2 == 0 else " ", # blinking colon
			roundi(time_remaining_msec as float / 1000) - (roundi(time_remaining_msec as float / 1000 / 60) * 60) # remainder
		]
	else:
		%Time.text = "OVER"

	if time_remaining_msec as float / 1000 <= 60:
		%Time.modulate = Color(1,0,0)
	elif time_remaining_msec as float / 1000 <= 180:
		%Time.modulate = Color(1,1,0)
	else:
		%Time.modulate = Color(1,1,1)
