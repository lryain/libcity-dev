extends Barrel

@export var projectile : PackedScene = preload("res://Assets/Weapons/WeaponTypes/ProjectileShootingWeapon/Projectiles/Projectile.tscn")
@export var projectile_velocity : float = 15
@export var shoot_animation : String = "Shoot"

@onready var pooler: Node = $Pooler
@onready var mag_size = $"../../Magazines".get_child(0).clip_size #I think there should be a better of getting this


var trigger_is_held : bool = false


#@export
#var penetrating : bool = false

# Returns list of players shot
#func cast_ray(from : Vector3, to : Vector3):
#	var hits = []
#	var ray_targets = []
#	var exclude = [character]
#
#	while true:
#		var space_state = get_world_3d().direct_space_state
#
#		var physics_ray_query_parameters_3d = PhysicsRayQueryParameters3D.new()
#
#		var random_spread = Vector3.FORWARD\
#		.rotated(Vector3.UP, randf_range(-PI, PI))\
#		.rotated(Vector3.FORWARD, randf_range(-PI, PI))\
#		.rotated(Vector3.LEFT, randf_range(-PI, PI))\
#		* randf_range(0,1)\
#		* 100 * inaccuracy
#
#		physics_ray_query_parameters_3d.from = from
#		physics_ray_query_parameters_3d.to = to + random_spread
#		physics_ray_query_parameters_3d.exclude = exclude
#
#		var ray = space_state.intersect_ray(physics_ray_query_parameters_3d)
#
#		ray_targets.append(physics_ray_query_parameters_3d.to)
#
#		if ray == {}:
#			return  { "hits" : hits, "targets": ray_targets }
#		if not penetrating:
#			hits.append(ray)
#			return  { "hits" : hits, "targets": ray_targets }
#		if ray.collider is Character:
#			hits.append(ray)
#			physics_ray_query_parameters_3d.from = ray.position
#			exclude.append(ray.collider)
#			physics_ray_query_parameters_3d.exclude = exclude
#		else:
#			return  { "hits" : hits, "targets": ray_targets }

func _ready() -> void:
	Settings.connect(&"test_var_changed", on_test_var_changed)

func on_test_var_changed(var_name, value):
	if var_name != "use_pooling" : return
	
	if value: pooler.initialize(projectile, mag_size)
	else: pooler.reset_pooler()

func can_shoot():
#	print("Barrel ", name, " checks if it can shoot")
	return slide.shoot()



func shoot():
	var projectile_instance : Projectile
	if not Settings.test_settings["use_pooling"]:
		projectile_instance = projectile.instantiate()
		Globals.get_spawn_root().add_child(projectile_instance)
	else:
		projectile_instance = pooler.spawn_projectile()
		
	projectile_instance.global_transform = $ProjectileSpawner.global_transform
	projectile_instance.character = character
	projectile_instance.source_position = character.global_position
	# FIXME the shooting direction should be -Z, not -X basis component:
	projectile_instance.linear_velocity = - $ProjectileSpawner.global_transform.basis.x * projectile_velocity
	
#	projectile_instance.gravity_scale = 0
	#	var from = spawner.to_global(Vector3(0.0, 0.0, 0.0))
	#	var to = spawner.to_global(Vector3(-1000.0, 0.0, 0.0))

	for i in $ProjectileSpawner.get_children():
		if i is AudioStreamPlayer3D:
			i.play()
			for j in i.get_children():
				if j is AudioStreamPlayer3D:
					j.play()

	$ProjectileSpawner/MuzzleFlash.shoot()

#	var raycast_result = cast_ray(from, to)
#	return raycast_result
