@tool
extends Node3D

#var owner_pid: int
var character : Character

var bodies_processed = []

@export var damage_amount : int
@export var push_force : float = 10
@export var blast_radius : float = 8.0:
	set(value): # also runs in editor!
		blast_radius = value
		if Engine.is_editor_hint(): # this must only be triggered in editor!
			apply_radius()

@export var blast_duration : float = 0.25

@onready var damage_class = load("res://Assets/Weapons/Damage/DamageExplosion.gd")
@onready var damage_label : PackedScene = load("res://Assets/Weapons/Damage/DamageLabel.tscn")


func apply_radius() -> void:
	$Blast/BlastRadius.shape.radius = blast_radius
	$Rumble/RumbleRadius.shape.radius = blast_radius * 4
	$MeshInstance3D.mesh.radius = blast_radius
	$MeshInstance3D.mesh.height = blast_radius * 2


func _ready() -> void:
#	blast_duration = 10

	if Engine.is_editor_hint():
		return

	apply_radius()
	var tween = create_tween()
	tween.tween_property($Blast/BlastRadius, "disabled", true, blast_duration).from(false) # disable collision after this time
	tween.parallel()
	tween.tween_property($Rumble/RumbleRadius, "disabled", true, blast_duration).from(false) # disable collision after this time
	tween.parallel()
	tween.tween_property($MeshInstance3D, "transparency", 1.0, blast_duration * 2).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(blast_duration * 2)
	tween.parallel()
	tween.tween_property($MeshInstance3D, "scale", Vector3(1,1,1), blast_duration * 4).from(Vector3(0.3,0.3,0.3)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(queue_free)
	tween.play()
#
#
#func _process(delta: float) -> void:
#	if Engine.is_editor_hint():
#		return

#	if damage != 0 and owner_pid != 0:
#		monitoring = true

#func give_damage(target: Node, hit_position: Vector3, hit_normal: Vector3, damage: int, source_position: Vector3, push: float) -> void:
#	if not is_multiplayer_authority():
#		print_debug("Attempting to deal damage from a puppet. Ignoring")
#		return
#	if target != null:
#		if target.has_method(&'take_damage'): # we've hit a player or something else - they will handle everything like effects etc.
#			target.rpc(&'take_damage', owner_pid, hit_position, hit_normal, damage, source_position, type, push)

func spawn_damage_label(hit):
	var label = damage_label.instantiate()

	var factor = 1.0 if hit.collider.state.team != character.state.team else MultiplayerState.game_config.friendy_fire_amount

	label.damage_amount = damage_amount * factor
	label.global_position = hit.position
	Globals.get_spawn_root().add_child(label)


func deal_damage(hit):
	hit["position"] = hit.collider.global_position
	hit["normal"] = (hit["collider"].global_position - global_position).normalized()
	if hit.collider.has_method(&"hurt"):
		var damage = damage_class.new()

		damage.attacker = character
		damage.attacker_pid = int(str(character.name))
		damage.source_position = global_position
		damage.hit_position = global_position #= hit.collider.global_position
		damage.damage_amount = damage_amount
		damage.push_force = push_force

		# only authority deals damage - tit gets propagated over the network by the target character
		if multiplayer.has_multiplayer_peer():
			if character.is_multiplayer_authority():
				hit.collider.hurt.rpc(inst_to_dict(damage))
				hit.collider.hurt(damage)
		else: # local game
			hit.collider.hurt(damage)

	if hit.collider is Character:
#		if hit.collider.state.team:
			# spawn particles only for enemies, or team mates if friendly fire is on
#			if not (hit.collider.state.team == character.state.team and\
#			MultiplayerState.game_config.friendy_fire_amount == 0):
#				spawn_hit_effect(hit, hit.collider.state.team)

		# show damage numbers only for the currently viewed character
		if character == Globals.current_character and hit.collider.state.alive:
			spawn_damage_label(hit)
#	else:
#		spawn_hit_effect(hit, 0)


func _on_rumble_body_entered(body):
	if body.has_method(&"set_rumble_source"):
		var amount : float = remap(damage_amount, 0, 100, 0, 1)
		var decay : float = 4
		var attack : float = 16
		var distance_multiplier : float = $Rumble/RumbleRadius.shape.radius / body.global_position.distance_squared_to(self.global_position)
#		print("Distance mutliplier: ", distance_multiplier)
		amount = clamp(amount * distance_multiplier, 0, 1)

		var rumble = {
			"amount" : amount,
			"decay" : decay,
			"attack" : attack,
		}

		body.set_rumble_source(self.name, rumble)
		body.set_rumble_source.rpc(self.name, rumble)


func _on_blast_body_entered(body):
	if Engine.is_editor_hint():
		return
	if body not in bodies_processed:
		if get_viewport().get_camera_3d():
			var space_state = get_world_3d().direct_space_state
			var physics_ray_query_parameters_3d = PhysicsRayQueryParameters3D.new()
			physics_ray_query_parameters_3d.from = global_position
			# cast ray to character's head if possible
			physics_ray_query_parameters_3d.to = body.head.global_position if body is Character else body.global_position
			var current_character = Globals.current_character

			# is there a character that we're looking at the game throgh the eyes of right now?
			if current_character:
		#		print("Current character exists")
				# does this character use first person camera at the moment?
				if current_character.current_camera == Character.CharacterCurrentCamera.FIRST_PERSON:
		#			print("Current character using first person camera")
					physics_ray_query_parameters_3d.exclude = [body]
		#		else:
		#			print("Current character NOT using first person camera")

			var ray = space_state.intersect_ray(physics_ray_query_parameters_3d)

			if ray.size() > 0:
				return
			else:
				deal_damage({"collider" = body})
				bodies_processed.append(body)
