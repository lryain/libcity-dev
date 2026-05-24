extends Camera3D

var target: Node = null

func _on_timer_timeout():
	queue_free()

func _process(delta):
	if target != null:
		var distance := global_transform.origin.distance_to(target.head.global_transform.origin)
		look_at(target.head.global_transform.origin)
		effects.dof_blur_near_distance = max(distance - 1, 0)
		effects.dof_blur_near_transition = max(distance - 2, 0)
		effects.dof_blur_far_distance = distance + 1
		effects.dof_blur_far_transition = distance -1
