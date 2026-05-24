extends "res://Assets/Weapons/WeaponTypes/ShootingWeapon/ShootingWeapon.gd"

@export var damage_amount : int = 25
@export var full_auto := false
@export var projectile_velocity : float = 15

@onready var anim : AnimationPlayer = $AnimationPlayer
#@onready var hit_effect : PackedScene = load("res://Assets/Effects/BulletHitEffect.tscn")
#@onready var projectile = load("res://Assets/Weapons/WeaponTypes/ProjectileShootingWeapon/Projectiles/Projectile.tscn")
#@onready var projectile2 = load("res://Assets/Weapons/WeaponTypes/ProjectileShootingWeapon/Projectiles/Projectile2.tscn")
#@onready var bullet_tracer : PackedScene = load("res://Assets/Effects/BulletTracer.tscn")
#@onready var flyby_sound : PackedScene = load("res://Assets/Audio/BulletFlyBySoundPlayer.tscn")

#@onready var damage_label : PackedScene = load("res://Assets/Weapons/Damage/DamageLabel.tscn")

var damage_class = preload("res://Assets/Weapons/Damage/DamageShot.gd")


@export var ammo_display_mesh_instance : NodePath
@onready var ammo_display : MeshInstance3D = get_node(ammo_display_mesh_instance)

#var primary_trigger_held := false
#var secondary_trigger_held := false

#func deal_damage(hit):
#	var damage = damage_class.new()
#
#	damage.attacker = character
#	damage.source_position = $Barrels/Barrel1/ProjectileSpawner.to_global(Vector3(0.0, 0.0, 0.0))
#	damage.hit_position = hit.position
#	damage.damage_amount = damage_amount

	# only authority deals damage - tit gets propagated over the network by the target character
#	if multiplayer.has_multiplayer_peer():
#		if character.is_multiplayer_authority():
#			hit.collider.hurt.rpc(inst_to_dict(damage))
#			hit.collider.hurt(damage)
#	else: # local game
#		hit.collider.hurt(damage)

#	if hit.collider.state.team:
#		# spawn particles only for enemies, or team mates if friendly fire is on
#		if not (hit.collider.state.team == character.state.team and\
#		MultiplayerState.game_config.friendy_fire_amount == 0):
#			spawn_hit_effect(hit, hit.collider.state.team)

	# show damage numbers only for the currently viewed character
#	if character == Globals.current_character:
#		spawn_damage_label(hit)


# unused
#@rpc("call_remote", "any_peer", "reliable")
#func spawn_hit_effect(hit, team: int):
#	var effect = hit_effect.instantiate()
#	effect.team = team
#	get_tree().root.add_child(effect)
#	effect.global_position = hit.position
#	if -0.95 < hit.normal.dot(Vector3.UP) and\
#		0.95 > hit.normal.dot(Vector3.UP):
#		effect.look_at(hit.position + hit.normal)
#	else:
#		effect.look_at(hit.position + hit.normal, Vector3.FORWARD)
#	effect.trigger()


# unused
#@rpc("call_remote", "any_peer", "reliable")
#func spawn_damage_label(hit):
#	var label = damage_label.instantiate()
#
#	var factor = 1 if hit.collider.state.team != character.state.team else MultiplayerState.game_config.friendy_fire_amount
#
#	label.damage_amount = damage_amount * factor
#	label.global_position = hit.position
#	get_tree().root.add_child(label)

#@rpc("call_remote", "any_peer", "reliable")
#func spawn_bullet_tracer(target):
#	var tracer = bullet_tracer.instantiate()
#	get_tree().root.add_child(tracer)
#	tracer.global_transform = global_transform
#	tracer.look_at(target)
#	print("Bullet tracer spawned: ", tracer, " on peer ", multiplayer.get_unique_id(), " on behalf of ", multiplayer.get_remote_sender_id())

#@rpc("call_remote", "any_peer", "reliable")
#func spawn_bullet_flyby_sound(target):
#	if Globals.current_character:
#		var flyby_camera = get_tree().get_root().get_camera_3d()
#
#		# TODO
#		# if flyby_camera == camera: # don't spawn flyby sound for the shooter
#		# 	return
#
#		var x := Vector3.ZERO
#		var A = global_position
#		var B = target
#		var C = flyby_camera.global_transform.origin
#
#		var d0 = (B - A).dot(A - C)
#		var d1 = (B - A).dot(B - C)
#
#		if d0 < 0 and d1 < 0:
#			pass #print("Firing away from the camera")
#		elif d0 > 0 and d1 > 0:
#			pass #print("Bullet hit before passing by")
#		else:
#			var X = d0/(d0-d1)
#			var flyby = flyby_sound.instantiate()
#			get_tree().root.add_child(flyby)
#			flyby.global_transform.origin = A + X * (B - A)


# reset after respawn
func reset() -> void:
	update_ammo_display(1.0) # show full clip

	for m in $Magazines.get_children():
		m.reset()


func _ready():
	reset()


func update_ammo_display(ammo_amount = null):
	if not ammo_display:
		return

	if not ammo_amount: # find out the ammo amount if nothing is provided
		ammo_amount = float($Magazines.get_child(0).remaining_shots) / float($Magazines.get_child(0).clip_size)
#		print("Caclulated ammo amount for display update: ", ammo_amount)

	# set the shader parameter
	ammo_display.set_instance_shader_parameter("Value", ammo_amount)


func shoot(from_barrel = barrel):
	# ensure we're not currently reloading

	if not from_barrel.trigger_is_held:
		return

	if magazine.is_reloading:
		return

	# ensure we're not empty - of we are, reload instead
	if is_empty():
		reload_press()
		if multiplayer.has_multiplayer_peer():
			reload_press.rpc()
		return

	# ensure the gun is ready to shoot (slide returned etc)
	var can_shoot = from_barrel.can_shoot()
#	print("Barrel ", from_barrel.name, " can shoot: ", can_shoot)
	if not can_shoot:
		return

	# shoot
	#from_barrel.projectile = from_barrel.projectile
#	from_barrel.projectile_velocity = projectile_velocity
#	print("Shooting barrel ", from_barrel)
	from_barrel.shoot()
#	var hits : Array = shot.hits
#	var target : Vector3 = shot.targets[0]

#	update_ammo_display()

	# play the shoot animation
	if anim.is_playing():
		anim.stop()
	anim.play(from_barrel.shoot_animation)

	# now process what did we hit (if anything)
#	if not hits.is_empty():
#		for hit in hits:
#			if hit.collider is Character:
				# only the authority processes the logic here, non-authorities only execute an RPC
#				if MultiplayerState.role != Globals.MultiplayerRole.NONE:
#					if character.is_multiplayer_authority():
#				deal_damage(hit)
#			else:
				# this is done on all peers indepndently because it's not crucial to get synced right
#				spawn_hit_effect(hit, 0)

#	spawn_bullet_tracer(target)

#	if str(multiplayer.get_remote_sender_id()) == character.name:
#		spawn_bullet_flyby_sound(target)
#	print("Berrel: ", from_barrel.name, " Trigger is held? ", from_barrel.trigger_is_held)
	if full_auto and from_barrel.trigger_is_held and character.state.alive:
		await from_barrel.slide.slide_returned
		shoot(from_barrel)


@rpc("call_remote", "any_peer", "reliable")
func trigger_primary_press():
#	print("Trigger primary press")
#	primary_trigger_held = true
	$Barrels/Barrel1.trigger_is_held = true
	shoot($Barrels/Barrel1)


@rpc("call_remote", "any_peer", "reliable")
func trigger_primary_release():
#	print("Trigger primary release")
#	primary_trigger_held = false
	$Barrels/Barrel1.trigger_is_held = false


@rpc("call_remote", "any_peer", "reliable")
func trigger_secondary_press():
#	print("Trigger secondary press")
#	secondary_trigger_held = true
	$Barrels/Barrel2.trigger_is_held = true
	shoot($Barrels/Barrel2)


@rpc("call_remote", "any_peer", "reliable")
func trigger_secondary_release():
#	print("Trigger secondary release")
	$Barrels/Barrel2.trigger_is_held = false
#	secondary_trigger_held = false


@rpc("call_remote", "any_peer", "reliable")
func reload_press():
#	print("Reload pressed")
	if magazine.is_reloading:
		return

	if anim.is_playing():
		return

	for m in $Magazines.get_children():
		m.reload(anim.animation_finished) # pass signal to wait for
		if anim.is_playing():
			anim.stop()
		anim.play("Reload")


func character_setter():
#	print("Projectile shooting weapon forwards character reference to barrel")
	for i in $Barrels.get_children():
		i.character = character
