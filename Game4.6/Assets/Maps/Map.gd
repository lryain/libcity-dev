@tool
extends Node3D

@onready var spawnpoints = $SpawnPoints

@export var overview_camera : Camera3D

signal map_ready

var map_is_ready := false

@onready var loading_screen = get_tree().root.get_node("Main/LoadingScreen")

signal _reflection_probes_updated


func update_reflection_probes(var_name, value: bool) -> void:
	if var_name == &"render_refprobes":
		get_node("ReflectionProbes").visible = value


func set_reflection_probe_render_layers(layers: int):
#	print("Updating reflection probe layers to ", layers, "... ")

	# set the layers
	for i in $ReflectionProbes.get_children():
		if i is ReflectionProbe:
			i.hide()
			i.layers = layers
			i.cull_mask = layers # only render static objects into reflection probles
#			print("frame ", "%8d" % Engine.get_frames_drawn(), ": hidden and updated refrobe ", i )
#			for j in range(6):
#				await(get_tree().process_frame)

	# force refreshing cached cubemaps
	var steps_per_probe : int = 6 * 10
	var total_steps : int = $ReflectionProbes.get_children().filter(func(x): return x is ReflectionProbe).size() * steps_per_probe
	var step : int = 0

	for i in $ReflectionProbes.get_children():
		if i is ReflectionProbe:
			i.show()
#			print("frame ", "%8d" % Engine.get_frames_drawn(), ": shown refrobe ", i )
			for j in range(steps_per_probe): # let it render 6 faces of the cubemap
				if is_instance_valid(loading_screen):
					loading_screen.set_progress(step as float / total_steps)
				step += 1
				await(get_tree().process_frame)

	_reflection_probes_updated.emit()

# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.is_editor_hint():
		return
#	print("Making map overview camera current")
	overview_camera.make_current()

	Settings.var_changed.connect(update_reflection_probes)

	if Settings.get_var(&"render_refprobes") == true:
		set_reflection_probe_render_layers(1 + 2 + 4) # capture and pply to first 3 layers
		await _reflection_probes_updated

	if Settings.get_var(&"render_refprobes") == false:
		get_node("ReflectionProbes").hide()

	# place the sun halo so that it does coicide with the Sun lamp's angle


	map_is_ready = true
	map_ready.emit()


func start_match():
	randomize()
#	prints("Start match called on map", name)


func get_spawn_transform(for_team: int = 0) -> Transform3D:
#	assert(for_team != 0, "Map got a spawn transform request but no team provided")
#	var free_spawnpoint_found := false
	var shuffled_spawnpoints = spawnpoints.get_children()
	shuffled_spawnpoints.shuffle()

#	assert(len(shuffled_spawnpoints) > 0, "Map found no spawnpoints to pick from")

	for i in shuffled_spawnpoints:
		if i.is_free and i.team != 3: # check if the spawnpoint isn't occupied or disabled
#			print("Map checking spawnpoint ", i.name, ". Is free: ", i.is_free, "; team: ", i.team)
			if i.team == for_team or i.team == 0 or for_team == 0: # check if it allows the requested team
				return i.global_transform

#	for i in shuffled_spawnpoints:
#		print("Map checked spawnpoint ", i.name, ". Is free: ", i.is_free, "; team: ", i.team)

	push_error("Map found no free spawnpoints! Choosing a random one...")
	return spawnpoints.get_children().pick_random().global_transform
