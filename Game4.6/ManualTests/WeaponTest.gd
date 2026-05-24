extends Node3D

@onready var weapon : Weapon = $Weapon

@onready var event = CharCtrlEvent.new()

# control change for TRIGER
@onready var cct = CharCtrlChange.new(Globals.CharCtrlType.TRIG_S)

# control change for RELOAD
@onready var ccr = CharCtrlChange.new(Globals.CharCtrlType.WEPN_R)


# Called when the node enters the scene tree for the first time.
func _ready():
	cct.changed = true
	cct.enabled = true

	ccr.changed = true
	ccr.enabled = false

	event.control_changes.append(cct)
	event.control_changes.append(ccr)

	weapon.character = Character.new()
	weapon.character.state = CharacterState.new()
#	weapon.character.state.team = 1

	# make the character current (so we see the world from it's perspective)
	#Globals.current_character = $Character

func _on_timer_timeout():
	event.control_changes[0].enabled = not event.control_changes[0].enabled

#	if weapon.control_reload == true:
#		weapon.control_reload == false

	if event.control_changes[1].enabled:
		event.control_changes[1].enabled = false
		event.control_changes[1].changed = true

	# this doesn't work
	if weapon.is_empty() and not weapon.control_reload:
#		prints("Weapon empty")
		event.control_changes[1].enabled = true
		event.control_changes[1].changed = true
		#weapon.control_reload = true
#		print(var_to_str(event.control_changes))

	weapon._controller_event(event)
