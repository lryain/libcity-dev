class_name DamageHit extends DamageAttack

# Any damage resulting from a hit from a specific direction are described by this class or subclasses
# This includes flame throwers, explosions, bullets, etc.
# Damage resulting from status effects after a hit (like burn) are not described by this class

var source_position: Vector3 # location the target was hit from. Used for damage indicator
var hit_position: Vector3 # location on target that was hit
var push_force: float # amount of pushback applied to target

func kill_message():
	return "Player died from being hit by TODO"
