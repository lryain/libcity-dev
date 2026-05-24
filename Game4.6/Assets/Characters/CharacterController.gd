class_name CharController
extends Node3D

signal CharControllerEvent

@export var character : Character:
	set(value):
		character = value
		# overloaded by descendants, as it's impossibe to overload a setter
		_on_character_set()

var _event_index : int = 0
var _control_changed : bool

var replay_capture : bool = false:
	set(value):
		# starting capture
		if replay_capture == false and value == true:
			replay.clear()
			replay_frame_offset = Engine.get_physics_frames()
		replay_capture = value

		if replay_capture and replay_playback:
			replay_playback = false

var replay_playback : bool = false:
	set(value):
		# starting playback
		if replay_playback == false and value == true:
			replay_event_idx = 0
			replay_frame_offset = Engine.get_physics_frames()

		replay_playback = value

		if replay_capture and replay_playback:
			replay_capture = false


var replay : Array[CharCtrlEvent]
var replay_event_idx : int = 0
var replay_frame_offset : int = 0


# descendants can override this to update their members
# when the controlled character reference is passed
func _on_character_set() -> void:
	pass


func _check_control_changed(control : CharCtrl) -> void:
	if not _control_changed:
		if control.changed:
			_control_changed = true


# handle input for replay capture/playback
func control_replay(_event):
	# this is intended for testing only, disable in release builds
	if not OS.has_feature('debug'):
		return
#	print("Replay control triggered on node ", self)

	# replay capture/playback control
	if Input.is_action_just_pressed(&'replay_capture'):
		if not replay_capture:
			replay_capture = true
			replay_playback = false
#			print("Capturing replay...")

	elif Input.is_action_just_pressed(&'replay_playback'):
#		if not replay_playback:
		replay_playback = true
		replay_capture = false
		replay_event_idx = 0
		replay_frame_offset = Engine.get_physics_frames()
#		print("Playing back replay...")


func playback_replay(delta: float) -> void:
	if replay_playback:
#		print("Current playback frame: ", Engine.get_physics_frames() - replay_frame_offset)
		while replay[replay_event_idx].frame <= Engine.get_physics_frames() - replay_frame_offset:
#			print("Replaying event #", replay_event_idx, "; ", var_to_str(replay[replay_event_idx]))
			CharControllerEvent.emit(replay[replay_event_idx])
			replay_event_idx += 1

			if replay_event_idx >= replay.size():
				replay_playback = false
#				print("End of replay. Stopping playback")
				break


func _physics_process(delta):
	playback_replay(delta)
