class_name Damage

var damage_amount : int
var damage_type : DamageType

func kill_message():
	return "Player died in a generic way"

#enum DamageType {
#	NONE, # unknown damage
#	BULLET, # firearms
#	ENERGY, # plasma, electricity, laser
#	EXPLOSION, # shrapnel, shockwaves etc
#	IMPACT, # fall damage etc.
#	DROWNING, # swimming too deep
#	HAZARD, # bottomless pits, lava etc.
#}
