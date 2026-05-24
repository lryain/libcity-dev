extends Node3D

@export var team : int

@onready var decal = $Decal

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in get_children(): # activate all top-level particle systems secondary ones should be parented to the primary ones
		if i is GPUParticles3D or i is CPUParticles3D:
			i.amount = max(1, round(i.amount * Settings.get_var("render_particles_amount")))

func trigger() -> void:
	match team:
		0:
			if Settings.get_var("render_particles_fallback"):
				$Team0.emitting = true
			$HitWall.play()
		1:
			$Team1.emitting = true
			$HitCharacter.play()
			$WallEffect.queue_free()
			$Decal.hide()
		2:
			$Team2.emitting = true
			$HitCharacter.play()
			$WallEffect.queue_free()
			$Decal.hide()
#	return

	var tween = create_tween()
	tween.tween_interval(0.75)
	tween.chain()
	tween.tween_property(decal, "distance_fade_begin", 0, 10)
	tween.chain()
	tween.tween_property(decal, "distance_fade_length", 0, 3)
	tween.finished.connect(queue_free)
