extends CharController

@onready var aim_noise_offset := randi() % 10000

# A Bot need to keep track of the controls by type, hence using a dictionary
# rather than an array as in the case of a Player
var bot_controls = {
	Globals.CharCtrlType.MOVE_F: CharCtrl.new(),
	Globals.CharCtrlType.MOVE_B: CharCtrl.new(),
	Globals.CharCtrlType.MOVE_L: CharCtrl.new(),
	Globals.CharCtrlType.MOVE_R: CharCtrl.new(),
	Globals.CharCtrlType.MOVE_S: CharCtrl.new(),
	Globals.CharCtrlType.MOVE_J: CharCtrl.new(),
	Globals.CharCtrlType.TRIG_P: CharCtrl.new(),
	Globals.CharCtrlType.TRIG_S: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_1: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_2: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_3: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_L: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_R: CharCtrl.new(),
	Globals.CharCtrlType.V_ZOOM: CharCtrl.new(),
}

@export var noise : FastNoiseLite

var aiming_speed : float

@export var nav_agent : NavigationAgent3D

#@onready var update_interval := randi_range(2, 4) # how often to run expansive checks?

var target_character : Character
var target_control_point : ControlPoint
var next_position : Vector3
var following_nav_link := false

enum TargetType {ENEMY, CONTROL_POINT}

var priority_target : TargetType

var cease_fire := false

func on_settings_var_changed(var_name: String, value):
	if var_name == "debug_nav":
		$NavigationAgent3D.debug_enabled = value


func process_hud_update(update: CharHudUpdate) -> void:

	# if someone is shooting at us, we should maybe focus on that someone
	if update.got_damage: # higher damage has a bigger chance of making us focs on the attacker
		if update.got_damage is DamageAttack and update.got_damage.damage_amount > randf() * 100:
			target_character = update.got_damage.attacker
			if priority_target != TargetType.ENEMY:
				priority_target = TargetType.ENEMY

	# extra chance if that someone killed us:
	if update.got_killed:
		if update.got_damage is DamageAttack and randf() < 0.33:
			target_character = update.got_damage.attacker

	# move on to the next target
	if update.did_kill:
		var old_target = target_character
		while target_character == old_target:
			await(get_tree().create_timer(randf_range(0.25, 0.75)).timeout)
			find_new_target()

	# let's check what is the nearessttarget we can chase
	if update.got_spawned:
		target_character = null
		await(get_tree().create_timer(randf_range(0.5, 1.5)).timeout)
		find_new_target()


func _ready():
#	print("Generating bot profile")

#	print("character: ", character)

	assert(character != null, "Bot Controller has no character reference")
	character.profile = CharacterProfile.new()
	character.profile.display_name = NameGenerator.generate()
	character.profile.display_color = Color.from_hsv(randf(), randf(), randf())
	character.profile.badges = [Badges.Badge.BOT]
	character.profile.voice_pitch = randf_range(0.7, 1.3)
	character.apply_profile()
	character.character_hud_update.connect(process_hud_update) # bot controller need to wathc the HUD like a regualr player would
#	character.current_camera = Character.CharacterCurrentCamera.FIRST_PERSON
#	character.first_person = false

	# controls are missing control_type
	for ctrl in bot_controls.keys():
		var type = ctrl
		bot_controls[type].control_type = type

	# AI characters do not assume 1st person view by default

	$NavigationAgent3D.debug_path_custom_color = Color.from_hsv(randf(),1,1)
	$NavigationAgent3D.debug_use_custom = true

	$NavigationAgent3D.debug_enabled = Settings.get_var(&"debug_nav")

	Settings.var_changed.connect(on_settings_var_changed)


func _input(event) -> void:
	# give the parent class a chance to start replay capture/pplayback
	control_replay(event)

	# the Bot does not process any user input


# choose a new enemy to chase
func find_new_target():
	var control_points = []

	for i in get_tree().get_nodes_in_group(&"ControlPoints"):
		if i.team != character.state.team:
			control_points.append(i)
	# pick a random target
	if not control_points.is_empty():
		target_control_point = control_points.pick_random()
	else:
		target_control_point = null

	var enemies = []

	for i in get_tree().get_nodes_in_group(&"Characters"):
		if i.state.team != character.state.team and\
		i.state.alive and i.global_position.distance_to(global_position) < 50 and\
		not i.is_queued_for_deletion():
			enemies.append(i)

#	print("Enemies found: ", enemies)

	if not enemies.is_empty():
		target_character = enemies.pick_random()
		target_character.tree_exiting.connect(func(): target_character = null)
#		print("Found new target: ", target)
	else:
		target_character = null
#		print("No enemies in range"

	if target_character and target_control_point:
		priority_target = randi_range(0, 1) as TargetType


func _physics_process(delta: float) -> void:
	if character.state.alive == false:
		return

	if target_character == null and target_control_point == null:
		find_new_target()

	if priority_target == TargetType.CONTROL_POINT:
		if is_instance_valid(target_control_point):
			if target_control_point.team == character.state.team:
				find_new_target()
		else:
			find_new_target()
	elif priority_target == TargetType.ENEMY:
		if is_instance_valid(target_character):
			if is_instance_valid(target_character.state):
				if not target_character.state.alive:
					find_new_target()
			else:
				find_new_target()
		else:
			find_new_target()


#	if not character:
#		return
#	if not is_instance_valid(character):
#	if Engine.get_physics_frames() % update_interval != 0:

#	if target:
#		character.banner.get_node("NameTag").text = character.profile.display_name + " [T: " + target.profile.display_name + "]"
#	else:
#		character.banner.get_node("NameTag").text = character.profile.display_name + " [NO TARGET]"
	var our_pos = character.global_position
	var sorted_control_points = get_tree().get_nodes_in_group(&"ControlPoints")
	sorted_control_points.sort_custom(func(a,b):\
		return our_pos.distance_to(a.global_position) < our_pos.distance_to(b.global_position)\
		)

	for i in sorted_control_points:
		if i.team != character.state.team:
			target_control_point = i
			priority_target = TargetType.CONTROL_POINT
			break

	match priority_target:
		TargetType.CONTROL_POINT:
			if target_control_point:
				nav_agent.target_desired_distance = 0.5
				nav_agent.target_position = target_control_point.global_position
		TargetType.ENEMY:
				nav_agent.target_desired_distance = 3
				if not target_character:
					pass
				elif not is_instance_valid(target_character):
					pass
				elif target_character.is_queued_for_deletion():
					pass
				elif target_character.state.alive: # is it alive and reachable?
					nav_agent.target_position = target_character.global_position

	if not following_nav_link:
		next_position = nav_agent.get_next_path_position()

	# reactionary movement

	# don't process every single frame
	if randf() > 0.3:
		return

	var new_event = CharCtrlEvent.new()

	if not $LedgeRay.is_colliding():
		var cc = CharCtrlChange.new(Globals.CharCtrlType.MOVE_J)
		if next_position.y >= character.global_position.y:
			cc.enabled = true
		else:
			cc.enabled = false
		bot_controls[Globals.CharCtrlType.MOVE_J].enabled = cc.enabled
		new_event.control_changes.append(cc)

	# if (1) we're blocked by an obstacle that can be cleared with a jump or (2) there's nothing beneath us
	if ($StepRay.is_colliding() and not $ClearanceRay.is_colliding()) or not $FallRay.is_colliding():
		var cc2 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_J)
		cc2.enabled = true
		bot_controls[Globals.CharCtrlType.MOVE_J].enabled = true
		new_event.control_changes.append(cc2)

		var cc3 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_F)
		cc3.enabled = true
		bot_controls[Globals.CharCtrlType.MOVE_F].enabled = true
		new_event.control_changes.append(cc3)

		var cc4 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_B)
		cc4.enabled = false
		bot_controls[Globals.CharCtrlType.MOVE_B].enabled = false
		new_event.control_changes.append(cc4)

		var cc5 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_L)
		cc5.enabled = false
		bot_controls[Globals.CharCtrlType.MOVE_L].enabled = false
		new_event.control_changes.append(cc5)

		var cc6 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_R)
		cc6.enabled = false
		bot_controls[Globals.CharCtrlType.MOVE_R].enabled = false
		new_event.control_changes.append(cc6)


	# something's blocking our path!
	if bot_controls[Globals.CharCtrlType.MOVE_F].enabled and $StepRay.is_colliding() and $ClearanceRay.is_colliding():
		var cc7
		var cc8
		var cc9 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_F)
		if not $LeftRay.is_colliding(): # dodge left
			cc7 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_L)
			cc8 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_R)
			bot_controls[Globals.CharCtrlType.MOVE_R].enabled = false
		elif not $RightRay.is_colliding(): # or dodge right
			cc7 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_R)
			cc8 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_L)
			bot_controls[Globals.CharCtrlType.MOVE_L].enabled = false
		else: # we're boxed in? try to go somewhere else
			find_new_target()

		new_event.control_changes.append(cc7)
		if cc7 is CharCtrlChange:
			cc7.enabled = true # activate this
			new_event.control_changes.append(cc8)
		if cc8 is CharCtrlChange:
			cc8.enabled = false # decativeate the other direction
			new_event.control_changes.append(cc9)
		cc9.enabled = false # and stop walking forward so we can strafe


	# random reaction lag
	await get_tree().create_timer(randf_range(0, 0.1)).timeout
	character._controller_event(new_event)

#	if $FallRay.is_colliding():
#		nav_agent.path_desired_distance = 3
#		nav_agent.path_max_distance = 5
#	else:
#		nav_agent.path_desired_distance = 20
#		nav_agent.path_max_distance = 50


	# no? let's get a target!

#	if target == null:
#		next_position = Vector3(randi(), randi(), randi())

# simulated mouse aiming



func _process(delta):
	# do not turn up or down

	if character.state.alive == false:
		return


	var aim := Vector2.ZERO

#	var aim_dir = global_position.direction_to(next_position)
#	aim.y = aim_dir.y
	#aim.x = aim_dir.x / 10
	var time : float = Time.get_ticks_msec() * Engine.time_scale

	# don't change horiontal aim if we're jumping a big gap
	if $FallRay.is_colliding():
		aim.x += noise.get_noise_2d((time - 0.5) / 50 + aim_noise_offset, -1000) / 20

	aim.y += noise.get_noise_2d((time - 0.5) / 50 + aim_noise_offset, 1000) / 20 # aim less up/down than left/right
	aim.y += - character.head.rotation.x / 10 # a tendency to look forward

	aiming_speed = remap(noise.get_noise_1d(float(Time.get_ticks_msec() / 100.0)), -1, 1, 0.25, 50)
#	print("Aiming speed: ", aiming_speed)

	if not next_position.is_zero_approx():
		var loc = Vector3(next_position.x, character.global_position.y, next_position.z)
		if loc.distance_to(character.global_position) > 0.1:
			var target = character.global_transform.looking_at(loc)
			character.global_transform = character.global_transform.interpolate_with(target, delta * aiming_speed)

	# a tendency to aim towards the nav next location

#	character.global_transform.basis.z

#	print("Aim: ", aim)

	var new_event := CharCtrlEvent.new()
	new_event.aim = aim

	_event_index += 1
	new_event.index = _event_index
	new_event.frame = Engine.get_physics_frames()

	if cease_fire:
		return

	# if we are aiming at an enemy - shoot!
	if randf() < 0.25 and $ShapeCast3D.is_colliding():
#		print("Aiming at something")
#		print("Aiming at ", $RayCast3D.get_collider())
		for i in range($ShapeCast3D.get_collision_count()):
			if $ShapeCast3D.get_collider(i) is Character:
	#			print("Aiming at a character")
				if $ShapeCast3D.get_collider(i).state.team != character.state.team:
					# why not start chasing who we already see in front of us?
					if target_character != $ShapeCast3D.get_collider(i) and randf() < 0.9:
						target_character = $ShapeCast3D.get_collider(i)

					# secondary or primary fire
					var cc = CharCtrlChange.new(\
					[Globals.CharCtrlType.TRIG_P, Globals.CharCtrlType.TRIG_S][randi_range(0,1)]\
					)
					bot_controls[cc.control_type].enabled = true

					cc.enabled = true
					cc.changed = true
					new_event.control_changes.append(cc)

					if cc.control_type == Globals.CharCtrlType.TRIG_S:
						cease_fire = true
						get_tree().create_timer(randf_range(0.3, 0.7)).timeout.connect(func(): cease_fire = false)

					break

	emit_signal(&'CharControllerEvent', new_event)

	# don't shoot immedaitelly after we used secondary to not blow ourselves up with the plasma combo
	if cease_fire:
		# let go of the triggers
		var event2 = CharCtrlEvent.new()
		var cc2 = CharCtrlChange.new(Globals.CharCtrlType.TRIG_P)
		cc2.enabled = false
		cc2.changed = true
		event2.control_changes.append(cc2)

		cc2 = CharCtrlChange.new(Globals.CharCtrlType.TRIG_S)
		cc2.enabled = false
		cc2.changed = true
		event2.control_changes.append(cc2)
		emit_signal(&'CharControllerEvent', event2)

		# wait a bit
#		await(get_tree().create_timer(randf_range(0.4, 0.75)).timeout)


func _on_timer_timeout() -> void:
	if replay_playback:
		return

	var new_event := CharCtrlEvent.new()
	_control_changed = false

	# disabling all previously active controls
	for control in bot_controls:
		if bot_controls[control].enabled:
			var cc1 := CharCtrlChange.new(bot_controls[control].control_type)
			cc1.enabled = false
			cc1.changed = true
			new_event.control_changes.append(cc1)
			_control_changed = true
			bot_controls[control].enabled = false

	# enabling a different control
	if randf() < 0.9: # probability of taking action
		var cc2 : CharCtrlChange

#		print("Current weapon empty ", character.weapons.current.is_empty())
		# if the current weapon is empty - reload
		if character.weapons.current.is_empty():
#			print("Bot reloading weapon")
			cc2 = CharCtrlChange.new(Globals.CharCtrlType.WEPN_R)
		elif randf() < 0.1: # otherwise do something else
			cc2 = CharCtrlChange.new(randi_range(1,6))
		elif next_position.distance_to(character.global_position) > 1:
			cc2 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_F)
		else:
			cc2 = CharCtrlChange.new(randi_range(1,4))

		bot_controls[cc2.control_type].enabled = true
		cc2.enabled = true
		cc2.changed = true
		new_event.control_changes.append(cc2)

		# if we're walking forward and going off a ledge and our target is above
		if not $LedgeRay.is_colliding() and\
		bot_controls[Globals.CharCtrlType.MOVE_F].enabled and\
		next_position.y > character.global_position.y:
			# let's jump
			var cc3 : CharCtrlChange
			cc3 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_J)
			cc3.enabled = true
			cc3.changed = true
			new_event.control_changes.append(cc3)
			bot_controls[Globals.CharCtrlType.MOVE_J].enabled = true
			# and jetpack
			cc3 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_S)
			bot_controls[Globals.CharCtrlType.MOVE_S].enabled = true
			new_event.control_changes.append(cc3)
		elif not $LedgeRay.is_colliding() and\
		bot_controls[Globals.CharCtrlType.MOVE_S].enabled and\
		next_position.y < character.global_position.y:

			# if we're above our target location and jetpacking - let's stop
			var cc4 : CharCtrlChange
			cc4 = CharCtrlChange.new(Globals.CharCtrlType.MOVE_S)
			cc4.enabled = false
			cc4.changed = true
			new_event.control_changes.append(cc4)
			bot_controls[Globals.CharCtrlType.MOVE_S].enabled = false

		# switching weapons
		if randf() < 0.1:
			var cc5 : CharCtrlChange

			cc5 = CharCtrlChange.new([\
			Globals.CharCtrlType.WEPN_1,\
			Globals.CharCtrlType.WEPN_2,\
			Globals.CharCtrlType.WEPN_L]\
			.pick_random())

			# press
			cc5.enabled = true
			cc5.changed = true
			new_event.control_changes.append(cc5)
			# release
			cc5.enabled = false
			cc5.changed = true
			new_event.control_changes.append(cc5)

			# no need to remember this
#			bot_controls[cc5.control_type].enabled = true
#			bot_controls[cc5.control_type].enabled = false



		_control_changed = true

	_event_index += 1
	new_event.index = _event_index
	new_event.frame = Engine.get_physics_frames()


	new_event.abs_location = character.global_transform.origin
	new_event.abs_aim.x = character.get_rotation().y # body left/right
	new_event.abs_aim.y = character.head.get_rotation().x # head up/down

	$Timer.wait_time = randf_range(0.25, 2)

	if _control_changed:
#		print("Emitting bot control event")
		emit_signal(&'CharControllerEvent', new_event)

		if replay_capture:
			if replay.size() == 0:
#				print("Recording first frame")
				new_event.use_absolute = true # to reset position and aim for replay playback

#			print("Bot recorded event: ", new_event.index)
			replay.append(new_event)


func _on_navigation_agent_3d_link_reached(details: Dictionary) -> void:
	pass
#	print("Bot reached NavLink: ", details)
#	following_nav_link = true
#	next_position = details.link_exit_position



func _on_navigation_agent_3d_waypoint_reached(details: Dictionary) -> void:
	pass
#	print("Bot reached WayPoint: ", details)
#	following_nav_link = false
