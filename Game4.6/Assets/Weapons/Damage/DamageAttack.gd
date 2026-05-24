class_name DamageAttack extends Damage

# Any damage dealt by an attacker is described by this class or a subclass
# Damage dealt by environmental hazards (so without an attacker) are not described by this class

var attacker : Node # damage in this category is dealt by attacking players.
var attacker_pid : int # damage in this category is dealt by attacking players.

func kill_message():
	return "Player died from being attacked"
