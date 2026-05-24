class_name DamageShot extends DamageHit


# This class describes damage from being shot

func _init():
	damage_type = DamageTypeShot.new()

func kill_message():
	return "Player was shot by TODO"
