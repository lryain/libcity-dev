@tool
extends MeshInstance3D

@export var texture : Texture2D

#@onready var streak = get_node_or_null("HorizontalStreak")

@export var hide_show_time : float = 0.1

@export var fade_factor := 1.0#:
	#set(value):
		#fade_factor = value
		#for subhalo in get_children():
			#if subhalo is MeshInstance3D:
				#subhalo.fade_factor = fade_factor

var is_on_screen = true#:
	#set(value):
		#is_on_screen = value
		#for subhalo in get_children():
			#if subhalo is MeshInstance3D:
				#subhalo.is_on_screen = is_on_screen

var hide_show_tween : Tween

@export var halo_size := 1.0:
	set(value):
		halo_size = value
		mesh.size = Vector2(value, value) * 2.0

		#for subhalo in get_children():
			#if subhalo is MeshInstance3D:
				#subhalo.halo_size = halo_size

#@export var horizontal_streak := 1.0:
	#set(value):
		#horizontal_streak = value
#
		#if is_instance_valid(streak):
			#if horizontal_streak > 0:
				#streak.transparency = clamp(1 - horizontal_streak, 0, 1)
				#streak.show()
			#else:
				#streak.hide()
#		mesh.size = Vector2(value, value) * 2.0
		#for subhalo in get_children():
			#if subhalo is MeshInstance3D:
				#subhalo.horizontal_streak = horizontal_streak

#@onready var halo_transform = global_transform

@export var halo_color := Color.WHITE:
	set(value):
		halo_color = value
		get_surface_override_material(0)["emission"] = value

		#for subhalo in get_children():
			#if subhalo is MeshInstance3D:
				#subhalo.halo_color = halo_color

var halo_alpha_max := halo_alpha

@export var halo_alpha := 1.0:
	set(value):
		halo_alpha = clampf(value, 0, 1)
		transparency = 1.0 - halo_alpha

		#for subhalo in get_children():
			#if subhalo is MeshInstance3D:
				#subhalo.transparency = 1.0 - (subhalo.halo_alpha * halo_alpha)


#@export var halo_depth_offset : float = 0:
#	set(value):
#		halo_depth_offset = value
#		mesh.center_offset.z = halo_depth_offset

var ray_previously := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
#		hide()
#	else:
#		show()

	mesh = mesh.duplicate()
	var halo_material = get_surface_override_material(0).duplicate()
	set_surface_override_material(0, halo_material)

	# trigger setters
	halo_color = halo_color
	halo_size = halo_size
	halo_alpha = halo_alpha
	fade_factor = fade_factor
	#horizontal_streak = horizontal_streak
#	halo_depth_offset = halo_depth_offset

	#for subhalo in get_children():
		#if not subhalo is MeshInstance3D:
			#continue
		#subhalo.sorting_offset = sorting_offset
		#subhalo.visibility_range_begin = visibility_range_begin
		#subhalo.visibility_range_begin_margin = visibility_range_begin_margin
		#subhalo.visibility_range_end = visibility_range_end
		#subhalo.visibility_range_end_margin = visibility_range_end_margin


# we need a way to hide the mesh without really hiding it because of the visibility notifier
func tween_mesh_size(target: Vector2, duration: float, ease_type, trans_type):
	if hide_show_tween is Tween:
		if hide_show_tween.is_running():
			hide_show_tween.kill()

	hide_show_tween = create_tween()
	hide_show_tween.tween_property(mesh, "size", target, duration).set_ease(ease_type).set_trans(trans_type)
	hide_show_tween.play()


func hide_halo():
	tween_mesh_size(Vector2.ZERO, hide_show_time, Tween.EASE_IN, Tween.TRANS_SINE)


func show_halo():
	tween_mesh_size(Vector2(halo_size, halo_size) * 2.0, hide_show_time, Tween.EASE_OUT, Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_on_screen:
		hide_halo()
		return


	if get_viewport().get_camera_3d():
		var space_state = get_world_3d().direct_space_state
		var physics_ray_query_parameters_3d = PhysicsRayQueryParameters3D.new()
		physics_ray_query_parameters_3d.from = global_position
		physics_ray_query_parameters_3d.to = get_viewport().get_camera_3d().global_position
		physics_ray_query_parameters_3d.hit_from_inside = true

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
			hide_halo()
			ray_previously = true
		elif not ray.size() > 0 and (ray_previously or is_on_screen):
			show_halo()
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

		if visible:
			var fade = 1 - clamp((pow(physics_ray_query_parameters_3d.from.distance_to(physics_ray_query_parameters_3d.to), 1.5) / 800) * fade_factor, 0, 1)
			get_surface_override_material(0)["emission"] = halo_color * fade


func _on_visible_on_screen_notifier_3d_screen_entered():
	is_on_screen = true

func _on_visible_on_screen_notifier_3d_screen_exited():
	is_on_screen = false
