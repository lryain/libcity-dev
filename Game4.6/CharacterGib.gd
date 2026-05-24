extends RigidBody3D

@export var lifetime : float = 7

@export var emission_start : float = 7

@export var use_camera : bool = false

@export var fire_light_animation : FastNoiseLite

var character : Character # who's gibs are these?
var tween : Tween
#var team : int = 0:
#	set(value):
#		team = value
#		$MeshInstance3D.set_instance_shader_parameter(&"Team", team)
#var color : Color:
#	set(value):
#		color = value
#		$MeshInstance3D.set_instance_shader_parameter(&"Color", color)
#
var emission : float:
	set(value):
		emission = value
		$MeshInstance3D.set_instance_shader_parameter(&"Emission", emission)

var transparency : float:
	set(value):
		transparency = value
		$MeshInstance3D.transparency = value
		$Sparks.transparency = value
		$Smoke.transparency = value

# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
#	pass

func _exit_tree() -> void:
	if tween:
		if tween.is_running():
			tween.kill()

#	if use_camera and character == Globals.current_character:
#		$Camera.clear_current()


func emit_sparks(_parameter):
	$Sparks.amount = randi_range(3, 15) * Settings.get_var("render_particles_amount")
	$Sparks.emitting = true
	$SparkSFX.play()
	await(get_tree().process_frame)
	$Sparks.emitting = false


func check_for_respawn(update: CharHudUpdate):
	if update.got_spawned:
		if get_node("Grain"):
			$Grain.hide()
			$Grain.queue_free()
		if get_node("Camera"):
			$Camera.queue_free()
		set_sfx_mute(false)

		if get_node("AudioStreamPlayer"):
			$AudioStreamPlayer.stop()
			$AudioStreamPlayer.queue_free()


func trigger():
	lifetime *= randf_range(0.8, 1.2)

	var variant = randf()
	if variant > 0.6:
		$Fire.emitting = true
		$Fire.amount *= Settings.get_var("render_particles_amount")
		$FireLight.show()
		$FireSFX.play()
		$FireSFX.pitch_scale *= randf_range(0.9, 1.1)
		
		$Smoke.emitting = false
	elif variant < 0.3:
		$Smoke.emitting = true
		$Smoke.amount *= Settings.get_var("render_particles_amount")
		
		$Fire.emitting = false
		$FireLight.hide()
		$FireSFX.stop()
	else:
		$Fire.emitting = false
		$Smoke.emitting = false
		$FireLight.hide()
		$FireSFX.stop()


	tween = create_tween()
	$MeshInstance3D.set(&"instance_shader_parameters/team", character.state.team)
#	$MeshInstance3D.set_instance_shader_parameter(&"Team", int(character.state.team))
	$MeshInstance3D.set_instance_shader_parameter(&"Color", character.profile.display_color)
#	$MeshInstance3D.set_instance_shader_parameter(&"Emission", emission)
	tween.tween_property(self, "emission", 0.0, lifetime).from(emission_start).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.parallel()
	tween.tween_property(self, "transparency", 1.0, lifetime / 4).from(0.0).set_delay((lifetime / 4) * 3).set_ease(Tween.EASE_OUT_IN)
	tween.parallel()
	tween.tween_property($Smoke,"transparency", 1.0, lifetime / 4).from(0.0).set_delay((lifetime / 4) * 3).set_ease(Tween.EASE_OUT_IN)
	tween.parallel()
	tween.tween_property($Fire, "transparency", 1.0, lifetime / 4).from(0.0).set_delay((lifetime / 4) * 3).set_ease(Tween.EASE_OUT)
	tween.parallel()
	tween.tween_property($FireLight, "omni_range", 0, lifetime / 4).from_current().set_delay((lifetime / 4) * 3).set_ease(Tween.EASE_OUT)
	tween.parallel()
	tween.tween_property($FireSFX, "volume_db", 0, lifetime / 4).from_current().set_delay((lifetime / 4) * 3).set_ease(Tween.EASE_IN)

	if $Smoke.emitting:
		tween.parallel()
		tween.tween_property($Smoke, "emitting", false, 0).set_delay(randf_range(1, lifetime))
	elif $Fire.emitting:
		tween.parallel()
		tween.tween_property($Fire, "emitting", false, 0).set_delay(randf_range(lifetime * 0.66, lifetime))

	var sparks_cycle : float = 0
	var duration

	while sparks_cycle < lifetime / randf_range(1, 3):
		duration = randf_range(1, lifetime / 2.0)
		sparks_cycle += duration
		tween.parallel()
		tween.tween_method(emit_sparks, null, null, 0).set_delay(sparks_cycle)
#		tween.chain()
#		tween.tween_property($Sparks, "emitting", false, duration / 2.0)

	tween.finished.connect(queue_free)
	tween.play()

	if use_camera and character == Globals.current_character:
		scale *= 4
		$Camera.make_current()
		$Grain.show()
		character.character_hud_update.connect(check_for_respawn)
		set_sfx_mute(true)
		$AudioStreamPlayer.play(randf())
	else:
#		$Camera.queue_free()
		$Grain.hide()
#		$Grain.queue_free()
#		$AudioStreamPlayer.queue_free()

func set_sfx_mute(muted: bool):
	var bus_idx = AudioServer.get_bus_index(&"SFX")
	AudioServer.set_bus_mute(bus_idx, muted)


func _process(delta: float) -> void:
	if use_camera:
		# limit the rotatinoal speed to avoid nausea
		angular_velocity = angular_velocity.limit_length(10)

	if $FireLight.visible:
		$FireLight.light_energy = clamp (remap(\
		fire_light_animation.get_noise_1d(Time.get_ticks_msec()),
		0, 1, 0.3, 1.0) * (emission / emission_start), 0, 1)


@rpc("call_remote", "any_peer", "reliable")
func hurt(_damage) -> void:
	var damage : Damage
	if _damage is Damage:
		damage = _damage
	elif _damage is Dictionary:
		damage = dict_to_inst(_damage)

	if damage is DamageHit:
		apply_central_impulse((self.global_position - damage.hit_position).normalized() * damage.push_force / 8.0)
