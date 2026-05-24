extends Node3D

const SPEED: float = 175

func _ready() -> void:
	#translate_object_local(Vector3.FORWARD * SPEED / 60 * randf_range(0, 1)) # randomize starting point
	$RayCast3D.target_position = - Vector3.FORWARD * SPEED  / 30

	# terminate a tracer after 1 second if it doesn't hit anything
	get_tree().create_timer(1).timeout.connect(queue_free)

func _process(delta) -> void:
	if $RayCast3D.is_colliding():
		queue_free()
	else:
		translate_object_local(Vector3.FORWARD * SPEED * delta)
