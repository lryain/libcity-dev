class_name DamageType

func get_type():
	return &"generic"

func apply_vulnerability(player, damage_amount):
	return damage_amount * player.vulnerability_to(get_type())
