extends Camera3D
var character : Character

var target: Node = null

func _on_timer_timeout():
	queue_free()

func _process(delta):
	if character != Globals.current_character:
		return
	if character.state.health > 0:
		return
	if target != null:
		var distance := global_transform.origin.distance_to(target.head.global_transform.origin)
		look_at(target.head.global_transform.origin)
		self.attributes.dof_blur_far_distance = distance + 1
		self.attributes.dof_blur_near_distance = max(distance - 1, 1)
		self.attributes.dof_blur_near_transition = 1
		self.attributes.dof_blur_far_transition = 1
		#printt("distance to killer:", distance, "DOF_far:", self.attributes.dof_blur_far_distance,\
		#"DOF_near:", self.attributes.dof_blur_near_distance)


