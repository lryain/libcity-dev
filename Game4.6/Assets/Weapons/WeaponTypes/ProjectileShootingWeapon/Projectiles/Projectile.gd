class_name Projectile extends Area3D

signal pool_free(node : Node)

@export var damage_amount : int = 25
@export var push_force : float = 10
@export var max_distance : float = 200 :
	#returns the max_distance squared to be used to compare distance at lower perfomance
	get: return max_distance * max_distance

var damage_class = preload("res://Assets/Weapons/Damage/DamageShot.gd")
@export_file("*.tscn") var hit_effect_scene_path : String
var hit_effect : PackedScene #= load(hit_effect_scene_path)
var damage_label : PackedScene = preload("res://Assets/Weapons/Damage/DamageLabel.tscn")

var character : Character
var source_position : Vector3

var linear_velocity : Vector3

var initial_position : Vector3

enum ProjectileType {PLASMA_SMALL, PLASMA_BIG}
@export var projectile_type : ProjectileType

var combo_scene = preload("res://Assets/Effects/PlasmaComboExplosion.tscn")

var check_distance_tween : Tween


func _enter_tree():
#	print("Requesting loading resource ", hit_effect_scene_path)
	ResourceLoader.load_threaded_request(hit_effect_scene_path)


func _ready() -> void:
#	print("Fetching loaded resource ", hit_effect_scene_path)
	hit_effect = ResourceLoader.load_threaded_get(hit_effect_scene_path)
	if not hit_effect:
		printerr("Requested resource ", hit_effect_scene_path, " is not there! Falling back to regular load")
		ResourceLoader.load(hit_effect_scene_path)
		hit_effect = ResourceLoader.load_threaded_get(hit_effect_scene_path)
		if not hit_effect:
			printerr("Requested resource ", hit_effect_scene_path, " failed fallback load! Using last resort regular load...")
			hit_effect = load(hit_effect_scene_path)

	on_start()
	#get_tree().create_timer(30).timeout.connect(queue_free) #Testing distance based instead

func on_start(): #this function runs on ready, but gets recalled when object is pulled from pool
	initial_position = global_position

	if $ShapeCast3D:
		$ShapeCast3D.shape = $CollisionShape3D.shape
		$ShapeCast3D.target_position = linear_velocity
		$ShapeCast3D.collision_mask = collision_mask
	else:
		printerr("Projectile's ShapeCast3D is not there!")

	# Check distance every (provided) time in seconds
	if check_distance_tween != null : check_distance_tween.stop()
	check_distance_tween = create_tween().set_loops()
	check_distance_tween.tween_callback(check_distance_and_free).set_delay(0.1)

	# Kill projectiles on a timer
	#get_tree().create_timer(600).timeout.connect(queue_free)


func _physics_process(delta):
#	if $ShapeCast3D:
#		if $ShapeCast3D.is_colliding():
#			if $ShapeCast3D.get_collider(0) != character:
#				deal_damage({"collider" = $ShapeCast3D.get_collider(0)})
	global_position += linear_velocity * delta


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


@rpc("call_remote", "any_peer", "reliable")
func spawn_hit_effect(hit, team: int):
#	print("Projectile spawning hit effect")
	var effect = hit_effect.instantiate()
	effect.character = character # pass reference to who we are
#	effect.team = team
	get_tree().root.add_child(effect)
	effect.global_position = hit.position
	if -0.95 < hit.normal.dot(Vector3.UP) and\
		0.95 > hit.normal.dot(Vector3.UP):
		effect.look_at(hit.position + hit.normal)
	else:
		effect.look_at(hit.position + hit.normal, Vector3.FORWARD)
#	effect.trigger()


func queue_free_with_pooling(what = self) -> void:
	if Settings.get_var("use_pooling"):
		emit_signal(&"pool_free", what)
	else:
		what.queue_free()


@rpc("call_remote", "any_peer", "reliable")
func spawn_damage_label(hit):
	var label = damage_label.instantiate()

	var factor = 1.0 if hit.collider.state.team != character.state.team else MultiplayerState.game_config.friendy_fire_amount

	label.damage_amount = damage_amount * factor
	label.global_position = hit.position
	get_tree().root.add_child(label)


func deal_damage(hit):
	hit.position = global_position
	hit.normal = linear_velocity.normalized() # use movement direction for normal
#	hit.normal = (hit.collider.global_position - hit.position).normalized() # use direction towards collider center as normal
	if not is_instance_valid(hit.collider):
		printerr("Projectile tries to deal damage btu the collider is ", hit.collider)
		return

	if hit.collider.has_method(&"hurt"):
		var damage = damage_class.new()

		if is_instance_valid(character):
			if not character.is_queued_for_deletion():
				damage.attacker = character
				damage.attacker_pid = int(str(character.name))
		damage.source_position = source_position
		damage.hit_position = position
		damage.damage_amount = damage_amount
		damage.push_force = push_force
		# only authority deals damage - it gets propagated over the network by the target character
		if multiplayer.has_multiplayer_peer():
			if is_instance_valid(character):
				if character.is_multiplayer_authority():
					hit.collider.hurt(damage)
					hit.collider.hurt.rpc(inst_to_dict(damage))
		else: # local game
			print("Sending only local damage")
			hit.collider.hurt(damage)

	if hit.collider is Character:
#		if hit.collider.state.team:
#			# spawn particles only for enemies, or team mates if friendly fire is on
#			if not (hit.collider.state.team == character.state.team and\
#			MultiplayerState.game_config.friendy_fire_amount == 0):
		spawn_hit_effect(hit, hit.collider.state.team)

		# show damage numbers only for the currently viewed character
		if is_instance_valid(character):
			if character == Globals.current_character and hit.collider.state.alive:
				spawn_damage_label(hit)
	else:
		spawn_hit_effect(hit, 0)

	queue_free_with_pooling()


@rpc("call_remote", "any_peer", "reliable")
func combo_explosion(attacker: Character):
	var combo = combo_scene.instantiate()

	combo.character = attacker
	combo.global_transform = global_transform
	get_tree().root.add_child(combo)
	queue_free_with_pooling()


func _on_body_entered(body: Node) -> void:
#	print("Projectile hit a body!")
	if body == character: # can't hit yourself
		return
	deal_damage({"collider" = body})


func _on_area_entered(area):
	if character == null : return #This is just to avoid null character on loading screen
#	print("Projectile hit an area!")
	if area is Projectile:
		if area.projectile_type == ProjectileType.PLASMA_SMALL\
		and projectile_type == ProjectileType.PLASMA_BIG:
			combo_explosion(area.character)
			if character.name == str(multiplayer.get_unique_id()):
				rpc(&"combo_explosion", area.character)

			queue_free_with_pooling(self)
			#rpc(&"queue_free_with_pooling")

			#queue_free_with_pooling(area)
			#area.queue_free_with_pooling.rpc()

			#if Settings.test_settings["use_pooling"]:
				#emit_signal(&"pool_free", area)
			#else:
				#queue_free()
#				area.queue_free.rpc()
			return


func check_distance_and_free():
	if global_position.distance_squared_to(initial_position) > max_distance:
		queue_free_with_pooling()
