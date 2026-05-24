#@tool
extends MeshInstance3D

@export var halo_color := Color.WHITE:
	set(value):
		halo_color = value
		set_instance_shader_parameter("Color", halo_color)

#@export var halo_depth_offset : float = 0:
#	set(value):
#		halo_depth_offset = value
#		mesh.center_offset.z = halo_depth_offset

var ray_previously := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	halo_color = halo_color


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if get_viewport().get_camera_3d():
		var space_state = get_world_3d().direct_space_state
		var physics_ray_query_parameters_3d = PhysicsRayQueryParameters3D.new()
		physics_ray_query_parameters_3d.from = global_transform.origin
		physics_ray_query_parameters_3d.to = get_viewport().get_camera_3d().global_transform.origin
		var current_character = Globals.current_character

		# is there a character that we're looking at the game throgh the eyes of right now?
		if current_character:
	#		print("Current character exists")
			# does this character use first person camera at the moment?
			if current_character.current_camera == Character.CharacterCurrentCamera.FIRST_PERSON:
	#			print("Current character using first person camera")
				physics_ray_query_parameters_3d.exclude = [current_character]
	#		else:
	#			print("Current character NOT using first person camera")

		var ray = space_state.intersect_ray(physics_ray_query_parameters_3d)

		if ray.size() > 0 and not ray_previously:
			hide()
			ray_previously = true
		elif not ray.size() > 0 and ray_previously:
			show()
			ray_previously = false

	#	var visual_ray = RenderingServer.instances_cull_ray(\
	#	get_viewport().get_camera_3d().global_transform.origin,
	#	global_position,
	#	get_tree().root.find_world_3d().scenario)
	##	print("Visual ray cull result: ", visual_ray)
	#
	#	if Engine.get_frames_drawn() % 120 == 0:
	#		print_rich("Visual ray intesected:")
	#		for i in visual_ray:
	#			print(instance_from_id(i))
	#		print("---")
	#
	#	if visual_ray.size() <= 20:
	#		show()
	#		ray_previously = false
	#	else:
	#		hide()
	#		ray_previously = true


	#	if ray.size() > 0:
	#		ray_previously = true
	#	else:
	#		ray_previously = false

#		if visible:
#			var fade = 1 - clamp(pow(physics_ray_query_parameters_3d.from.distance_to(physics_ray_query_parameters_3d.to), 1.5) / 800, 0, 1)
#			get_surface_override_material(0)["emission"] = halo_color * fade
