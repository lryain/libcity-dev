extends "res://Assets/Characters/CharacterController.gd"
class_name CharControllerPlayer

# Players don't need to keep track of the controls by type, hence using an array
# instead of a dictionary as used for Bots

var player_controls = [
	CharCtrl.new(Globals.CharCtrlType.MOVE_F, &'move_forward'),
	CharCtrl.new(Globals.CharCtrlType.MOVE_B, &'move_backward'),
	CharCtrl.new(Globals.CharCtrlType.MOVE_L, &'move_left'),
	CharCtrl.new(Globals.CharCtrlType.MOVE_R, &'move_right'),
	CharCtrl.new(Globals.CharCtrlType.MOVE_S, &'move_special'),
	CharCtrl.new(Globals.CharCtrlType.MOVE_J, &'move_jump'),
	CharCtrl.new(Globals.CharCtrlType.TRIG_P, &'trigger_primary'),
	CharCtrl.new(Globals.CharCtrlType.TRIG_S, &'trigger_secondary'),
	CharCtrl.new(Globals.CharCtrlType.WEPN_1, &'weapon_1'),
	CharCtrl.new(Globals.CharCtrlType.WEPN_2, &'weapon_2'),
	CharCtrl.new(Globals.CharCtrlType.WEPN_3, &'weapon_3'),
	CharCtrl.new(Globals.CharCtrlType.WEPN_L, &'weapon_last'),
	CharCtrl.new(Globals.CharCtrlType.WEPN_R, &'weapon_reload'),
	CharCtrl.new(Globals.CharCtrlType.WEPN_P, &'weapon_previous'),
	CharCtrl.new(Globals.CharCtrlType.WEPN_N, &'weapon_next'),
	CharCtrl.new(Globals.CharCtrlType.V_ZOOM, &'view_zoom'),
]
const MOUSE_SENSITIVITY = 0.0085

# we're buffering values from Settings to avoid polling them every frame
@export var mouse_sensitivity : float = 1
@export var mouse_invert_x : bool = false
@export var mouse_invert_y : bool = false


func _ready():
#	if is_multiplayer_authority(): # is this the locally controlled character?
#		Globals.current_character = character
	assert(character != null, "Player Controller has no character reference!")

	Settings.var_changed.connect(_on_settings_var_changed)

	mouse_sensitivity = Settings.get_var("input_mouse_sensitivity")
	mouse_invert_x = Settings.get_var("input_mouse_invert_x")
	mouse_invert_y = Settings.get_var("input_mouse_invert_y")

# this is overloading a method called in CharacterController's character variable setter
#func _on_character_set() -> void:
#	# override the current camera with the one belonging
#	# to a player-controlled character, assuming there's only one of those
#	# this solution is temporary, and only makes sense for testing
#	character.camera.current = true


func _on_settings_var_changed(variable: String, value):
	if variable == 'input_mouse_sensitivity':
		if MultiplayerState.local_character == character:
			mouse_sensitivity = value
	elif variable == 'input_mouse_invert_x':
		mouse_invert_x = value
	elif variable == 'input_mouse_invert_y':
		mouse_invert_y = value


func _input(event) -> void:

	# give the parent class a chance to start replay capture/pplayback
	control_replay(event)

	if replay_playback:
		return

	# input processing
	if MultiplayerState.local_character == character and character.is_controllable: #and Globals.focus == Globals.Focus.GAME:
		# toggle between 1st and 3rd person camera mode
		if Input.is_action_just_pressed(&"view_camera"):
			if character.current_camera == Character.CharacterCurrentCamera.FIRST_PERSON:
				character.current_camera = Character.CharacterCurrentCamera.THIRD_PERSON
			elif character.current_camera == Character.CharacterCurrentCamera.THIRD_PERSON:
				character.current_camera = Character.CharacterCurrentCamera.FIRST_PERSON
#			character.first_person = not character.first_person

		var new_event = CharCtrlEvent.new()

		_control_changed = false if _event_index > 0 else true

		var mouse_motion = event as InputEventMouseMotion
		if mouse_motion:
			new_event.aim = event.relative * MOUSE_SENSITIVITY * mouse_sensitivity

			# applying mouse axis inversions
			new_event.aim.x *= -1.0 if mouse_invert_x else 1.0
			new_event.aim.y *= -1.0 if mouse_invert_y else 1.0

			new_event.aim *= -1
			_control_changed = true

		for control in player_controls:
			var cc = control.get_control_change()
			if cc.is_changed():
				_control_changed = true
	#			print("Control change added: ", cc, "; changed: ", cc.changed)
				new_event.control_changes.append(cc)

		# TODO: optimize by merging events occuring inside a single physics frame

		if _control_changed:
			new_event.index = _event_index
			_event_index += 1
			new_event.frame = Engine.get_physics_frames() - replay_frame_offset
			CharControllerEvent.emit(new_event)

			if replay_capture:
				if replay.size() == 0:
	#				print("Recording first frame")
					new_event.use_absolute = true # to reset position and aim for replay playback

				# store the absolute location and rotation for each frame so we can verify the replay accuracy later
				new_event.abs_location = character.global_transform.origin
				new_event.abs_aim.x = character.get_rotation().y # body left/right
				new_event.abs_aim.y = character.head.get_rotation().x # head up/down

				replay.append(new_event)
