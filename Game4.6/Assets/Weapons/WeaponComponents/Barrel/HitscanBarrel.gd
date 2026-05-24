extends Barrel

@export var penetrating : bool = false
@export_flags_3d_physics var collision_mask : int = 0xFFFFFFFF

# Returns list of players shot
func cast_ray(from : Vector3, to : Vector3):
	var hits = []
	var ray_targets = []
	var exclude = [character]

	while true:
		var space_state = get_world_3d().direct_space_state

		var random_spread = Vector3.FORWARD\
		.rotated(Vector3.UP, randf_range(-PI, PI))\
		.rotated(Vector3.FORWARD, randf_range(-PI, PI))\
		.rotated(Vector3.LEFT, randf_range(-PI, PI))\
		* randf_range(0,1)\
		* 100 * inaccuracy

		var ray_params = PhysicsRayQueryParameters3D.\
		create(from, to + random_spread, collision_mask, exclude)
		
		var ray = space_state.intersect_ray(ray_params)
		ray_targets.append(ray_params.to)

		if ray == {}:
			return  { "hits" : hits, "targets": ray_targets }
		if not penetrating:
			hits.append(ray)
			return  { "hits" : hits, "targets": ray_targets }
		if ray.collider is Character:
			hits.append(ray)
			ray_params.from = ray.position
			exclude.append(ray.collider)
			ray_params.exclude = exclude
		else:
			return  { "hits" : hits, "targets": ray_targets }


func can_shoot():
	return slide.shoot()

 
func shoot():
	var spawner = $ProjectileSpawner
	var from = spawner.to_global(Vector3(0.0, 0.0, 0.0))
	var to = spawner.to_global(Vector3(-1000.0, 0.0, 0.0))

	for i in $ProjectileSpawner.get_children():
		if i is AudioStreamPlayer3D:
			i.play()
			for j in i.get_children():
				if j is AudioStreamPlayer3D:
					j.play()

	$ProjectileSpawner/MuzzleFlash.shoot()

	var raycast_result = cast_ray(from, to)
	return raycast_result
