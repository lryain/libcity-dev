class_name ControlPoint extends Node3D

var tween : Tween
@onready var base_pixel_size = $Sprite3D.pixel_size
var pixel_size_factor : float = 2
@onready var base_halo_alpha = 0.5
var halo_alpha_factor : float = 2
@onready var base_beam_transparency = $Beam.transparency
var beam_transparency_factor : float = 0

var colliding_characters : Array[Character]

var team := Globals.Teams.NONE:
	set(value):
		var old_team = team
		team = value
		match team:
			0:
				$Team1.hide()
				$Team2.hide()
				$ScoreTimer.stop()
			1:
				$Team1.show()
				$Team2.hide()
				$ScoreTimer.start()
			2:
				$Team1.hide()
				$Team2.show()
				$ScoreTimer.start()
		$Sprite3D.modulate = Globals.team_colors[team]
		$Sprite3D2.modulate = Globals.team_colors[team]
		$Halo.halo_color = Globals.team_colors[team]
		$Beam.set_instance_shader_parameter(&"team", team)
		if team > 0:
			$Light.light_color = Globals.team_colors[team]
			$Light.show()
			$Beam.show()
			$Halo.show()
		else:
			$Light.hide()
			$Beam.hide()
			$Halo.hide()

		if team == old_team:
			return

		if tween:
			tween.kill()


		tween = create_tween()
		tween.tween_property($Sprite3D, "pixel_size", base_pixel_size, 0.5).from(base_pixel_size * pixel_size_factor).set_ease(Tween.EASE_OUT)
		tween.parallel()
		tween.tween_property($Sprite3D2, "pixel_size", base_pixel_size, 0.5).from(base_pixel_size * pixel_size_factor).set_ease(Tween.EASE_OUT)
		tween.parallel()
		tween.tween_property($Halo, "halo_alpha", base_halo_alpha , 0.5).from(base_halo_alpha * halo_alpha_factor).set_ease(Tween.EASE_OUT)
		tween.parallel()
		tween.tween_property($Beam, "transparency", base_beam_transparency , 0.5).from(base_beam_transparency * beam_transparency_factor).set_ease(Tween.EASE_OUT)


		tween.play()

		$AudioStreamPlayer3D.play()


@rpc("any_peer","call_local","reliable")
func set_team(new_team) -> void:
	team = new_team


@rpc("any_peer","call_remote","reliable")
func update_remote_team(pid) -> void:
#	print("Control point", name, " UPDATES remote one about it's team, whihc is ", Globals.Teams.keys()[team])
	set_team.rpc_id(pid, team)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not MultiplayerState.game_config.game_mode in [ Globals.GameMode.CONTROL_POINTS, Globals.GameMode.KING_OF_THE_HILL ]:
		printerr("Control Point despawning because game mode is ", Globals.GameMode.keys()[MultiplayerState.game_config.game_mode])
		queue_free()
		return
	team = Globals.Teams.NONE

	if Globals.game_state:
		if not Globals.game_state.map.map_is_ready:
#			print("Control Point sees map is not ready, disabling capture")
			$Area3D/CollisionShape3D2.disabled = true
			await Globals.game_state.map.map_ready
#			print("Control Point sees map got ready, enabling capture")
			$Area3D/CollisionShape3D2.disabled = false
	else:
		$Area3D/CollisionShape3D2.disabled = false

	# request the server to send us the current CP state
	if multiplayer:
		if not multiplayer.is_server():
			update_remote_team.rpc_id(1, multiplayer.get_unique_id())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
#		print("Control Point IGNORING touch from team ", Globals.Teams.keys()[team])
		return
	if body is Character:
		colliding_characters.append(body)
		body.connect(&"character_died", check_for_capture)
		check_for_capture()


func check_for_capture():
	if not multiplayer.is_server():
		return

	var teams_present = {
		0: false,
		1: false,
		2: false,
		}

	for i in colliding_characters:
		if not is_instance_valid(i):
			continue
		if not i.state.alive:
			continue

		teams_present[i.state.team] = true

	if teams_present[1] and not teams_present[2]:
		team = Globals.Teams.LIME
	elif teams_present[2] and not teams_present[1]:
		team = Globals.Teams.PLUM
	else:
		return

	set_team.rpc(team)


func _on_score_timer_timeout() -> void:
	if multiplayer:
		if not multiplayer.is_server():
			return
	if Globals.game_state:
		if Globals.game_state.current_match_phase == Globals.MatchPhase.GAME:
			Globals.game_state.increment_team_score(team, self)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body in colliding_characters:
		colliding_characters.erase(body)
		body.disconnect(&"character_died", check_for_capture)

	check_for_capture()
