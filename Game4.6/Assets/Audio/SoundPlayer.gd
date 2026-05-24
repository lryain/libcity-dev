extends Node3D
# This Scene is meant for playing back sound groups. For simple, singular sound effects use stock Godot nodes, this is meant to play a random sound among a group with variations.
signal SoundPlayer_finished
@onready var player = $AudioStreamPlayer3D

@export_dir var path := "res://Assets/SFX" # all sound clips must reside somewhere in this directory
@export_file("*01*.wav") var SoundClip := path + "/" + "Test_01.wav"
@export var AutoPlay := false
@export var MinimumRandomDistance := 0.35 # gives optimal playback repetition for sound clip groups of different sizes.
@export var PlayUntilEnd := false # determines if the play() function is allowed to sop a previously started sound
@export var MinDelay := 0.0 # determines how many seconds must pass before the sound can be triggered again
@export var PitchScale := 1.0
@export var RandomizePitch := 0.0
@export var Voice_Count := 1
var min_distance = 0 # this  determines how ofte na sound is allowed to play (any Nth time) this is calculated automatically based on maximum_repetition
var clips = [] # holds loaded sound stream resources
var recently_played = [] # holds indexes of recently played
var ready_to_play = true # used as a semaphor for MinDelay

@export var debug = false
@export var unit_db : int = 0:
	set(value):
		rpc(&'set_unit_db', value)


func _ready() -> void:
	var files = []

	var dir = DirAccess.open(path)
	dir.list_dir_begin()

	player.max_polyphony = Voice_Count

	if debug:
		print ("--------")

	if debug:
		print("SoundClip: ", SoundClip)

	var filename = SoundClip.trim_prefix("res://").trim_suffix('.wav').get_file()

	var layer : String
	var index : String

	if debug:
		print_debug("Filename: ", filename)
	var slices = filename.rsplit('_', false)
	slices.reverse() # we need to read the slices bacwards
	if not slices[0].is_valid_int() and slices[1].is_valid_int(): # check if the last part is layer and next-to-last is number
		layer = slices[0]
		index = slices[1]
		if debug:
			print("Filename defines a layer: ", layer, " and index: ", index)
		slices.remove_at(0) # cut off layer
		slices.remove_at(0) # cut off index
	elif slices[0].is_valid_int():
		index = slices[0]
		layer = ""

		if debug:
			print("Filename defines index: ", index, " and no layer.")
		slices.remove_at(0) # cut off index
	else:
		assert(false, "SoundPlayer cannot parse the file name")

	var group : String = ""
	slices.reverse() # to reconstruct the string, we want toread the slices in the correct order

	for s in slices:
		group = group + s + "_"
	group = group.trim_suffix("_") # remove the last trailing '_'

	if debug:
		print ("Group is ", group)

	if debug:
		print ("--------")

	# Find all files matching selected group and optionally layer
	while true:
		var file = dir.get_next()
		if file.begins_with("."):
			pass # skip any hidden files
		elif file.begins_with(group):
			if layer == "" and file.ends_with(".wav"): # match if layer is none
				files.append(file)
			elif layer != "" and file.ends_with(layer + ".wav"):
				files.append(file)
		elif file == "": # dir listing reached the end
			break
	dir.list_dir_end()

	if debug:
		print("files in list: \n", files)

	for f in files:
		var res_file = path.path_join(f)
		var clip = load(res_file)
		if clip:
			clips.append(clip)
		else:
			push_warning("SoundPlayer attempted to load invalid clip from file ", res_file)
		if debug:
			print("loading ", res_file, "; result: ", clip)

	# make sure the base selected clip fro the group is loaed as well
	var base_clip = load(SoundClip)
	if not base_clip in clips:
		clips.append(base_clip)

	var clip_count = len(clips)

	if MinimumRandomDistance:
		min_distance = floor(clip_count * MinimumRandomDistance)
	else:
		min_distance = 0

	if debug:
		print("Clips: ", len(clips))
		print("min_distance: ", min_distance)

	# prepare voices - TODO: this does not work! as aworkaround I've duplicated the secondary AudioStreamPlayer3D manually
#	if Voice_Count > 1:
#		for i in range(1, Voice_Count):
#			var new_voice = $AudioStreamPlayer3D.duplicate()
#			add_child(new_voice)
#
#	for i in get_children():
#		voices.append(i)

	if len(clips) < 1:
		push_error("SoundPlayer: ", name, " has no clips available for filename: ", filename)

	if AutoPlay:
		play()

func pick_random():
	if debug:
		print_debug("Picking random clip from ", clips)
	#assert(len(clips) > 0, "SoundPlayer has no clips to choose from")
	var clip = randi() % len(clips)
	if debug:
		print_debug("Picked clip: ", clips[clip], " out of ", clips)
	return clip


@rpc("call_remote", "any_peer", "reliable")
func set_unit_db(value) -> void:
	$AudioStreamPlayer3D.unit_db = value

@rpc("call_remote", "any_peer", "reliable")
func play_clip(clip_idx, pitch):
	assert(clip_idx is int, "clip_idx is not int!")
	if clip_idx > len(clips):
		print_debug("Attempting to play an audio clip out of bounds: ", clip_idx," available clips: ", clips)
		clip_idx = clip_idx % len(clips) # failsafe

	$AudioStreamPlayer3D.stream = clips[max(clip_idx -1, 0)]
	$AudioStreamPlayer3D.pitch_scale = pitch
	$AudioStreamPlayer3D.play()

func play():
	if len(clips) < 1:
		push_error("SoundPlayer: ", name, " tried to play but has no clips available")
		return

	if not is_multiplayer_authority():
		if debug:
			print_debug("Sound ", name, " triggered from puppet, ignoring")
		return

	if debug:
		print("playing ", name)

	if PlayUntilEnd:
		if player.playing:
			return 1

	if MinDelay > 0:
		if not ready_to_play:
			return 2

	var clip_idx

	if len(clips) > 1:
		clip_idx = pick_random()

		while recently_played.has(clip_idx):
			clip_idx = pick_random()

		recently_played.append(clip_idx)

		if len(recently_played) > min_distance:
			recently_played.remove_at(0)
	else:
		push_warning("SoundPLayer ", name, " has only one clip to play")
		clip_idx = 0

	var pitch : float

	if RandomizePitch != 0:
		pitch = PitchScale + randf_range(-RandomizePitch /2, RandomizePitch/2)
	else:
		pitch = PitchScale

	rpc(&'play_clip', clip_idx, pitch)

	ready_to_play = true

	# TODO: implement final randomization algorithm


func _on_AudioStreamPlayer3D_finished() -> void:
	emit_signal(&"SoundPlayer_finished")
