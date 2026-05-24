extends "res://Assets/Weapons/Weapon.gd"

func process(delta):
	#primary trigger
	if character.controls[Globals.CharCtrlType.TRIG_P].changed: # changed gets reset to false whenever we check it
		if character.controls[Globals.CharCtrlType.TRIG_P].enabled:
			pass # trigger was just pulled
		elif not character.controls[Globals.CharCtrlType.TRIG_P].enabled:
			pass # trigger was just released

	# secondary trigger
	if character.controls[Globals.CharCtrlType.TRIG_S].changed: # changed gets reset to false whenever we check it
		if character.controls[Globals.CharCtrlType.TRIG_S].enabled:
			pass # trigger was just pulled
		elif not character.controls[Globals.CharCtrlType.TRIG_S].enabled:
			pass # trigger was just released

	# reloading
	if character.controls[Globals.CharCtrlType.WEPN_R].changed:
		if character.controls[Globals.CharCtrlType.WEPN_R].enabled:
			pass # reload was just pressed

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
