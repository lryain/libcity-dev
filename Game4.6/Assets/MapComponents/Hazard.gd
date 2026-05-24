extends Area3D

func _on_Hazard_body_entered(body) -> void: # Player did fall down
	if body is Character:
		var damage = DamageFall.new()
		damage.damage_amount = body.max_health * 2

		body.hurt(damage)
		body.hurt.rpc(inst_to_dict(damage))

#		body.die()
#		body.die.rpc()
