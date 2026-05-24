extends PhysicalBone3D

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if state.get_contact_count() == 0:
		return
	
	var largest_impulse : float = 0
	for i in range(state.get_contact_count()):
		largest_impulse = max(largest_impulse, state.get_contact_impulse(i).length())
	
	print("Bone ", self.name, " largest impuse: ", largest_impulse)
