class_name DamageTypeExplosion extends DamageType

func get_type():
	return &"explosion"

func apply_vulnerability(player, damage_amount):
	var computed_damage = damage_amount * player.vulnerability_to(get_type())
	return super.apply_vulnerability(player, computed_damage)
