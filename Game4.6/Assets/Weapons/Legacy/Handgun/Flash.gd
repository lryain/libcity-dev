extends Node3D

@export var smoke_color : Color
@export var smoke_velocity : float

func _ready():
	if Settings.get_var('render_particles_extra'):
		var pmat = $Smoke.process_material.duplicate()
		$Smoke.process_material = pmat
		$Smoke.emitting = true
	else:
		$Smoke.hide()
	
	$GPUParticles3D.emitting = true
	$AnimationPlayer.play("Flash")

func _process(_delta):
	if Settings.get_var('render_particles_extra'):
		$Smoke.process_material.color = smoke_color
		$Smoke.process_material.initial_velocity_min = smoke_velocity * 0.9
		$Smoke.process_material.initial_velocity_max = smoke_velocity * 1.1
		$Smoke.process_material.scale_min = smoke_velocity * 0.4
		$Smoke.process_material.scale_max = smoke_velocity * 0.5

func _on_Timer_timeout():
	queue_free()
