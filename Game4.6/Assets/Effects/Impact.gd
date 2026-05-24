extends Node3D

@export var lifetime : float = 15

var check_overlap = true

var particle_amount_factor : float = 1

var character : Character:
	set(value):
		character = value
		if get_node_or_null("Explosion"):
			$Explosion.character = character


func _ready():

	get_tree().create_timer(lifetime).timeout.connect(queue_free)

	for i in $GpuParticles.get_children(): # activate all top-level particle systems secondary ones should be parented to the primary ones
#		if i is GPUParticles3D:
		if not Settings.get_var("render_particles_fallback"):
			i.amount = max(1, round(i.amount * particle_amount_factor * Settings.get_var("render_particles_amount")))
			i.emitting = true
		else:
			i.queue_free()

#		for i in $CpuParticles.get_children(): # activate all top-level particle systems secondary ones should be parented to the primary ones
#	#		if i is GPUParticles3D:
#			i.amount = max(1, round(i.amount * particle_amount_factor * Settings.get_var("render_particles_amount")))
#			i.emitting = true
#	#self.look_at(get_viewport().get_camera_3d().global_transform.origin)


func remove_overlap():
	if get_node_or_null("Smoke"):
		$Smoke.queue_free()
	$AnimationPlayer2.speed_scale = 16.0


func _on_area_3d_area_entered(area):
	if check_overlap:
		if is_instance_valid(area.get_parent()):
			return

		if not area.get_parent.has_method(&"remove_overlap"):
			return

		area.get_parent().remove_overlap()


func _on_check_overlap_timeout():
	check_overlap = false
