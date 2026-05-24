extends Node3D
class_name Weapon

# this reference is passed to victims when hit
var character : Character:
	set(value):
		character = value
		character_setter()

var controls = {
	Globals.CharCtrlType.TRIG_P : CharCtrl.new(),
	Globals.CharCtrlType.TRIG_S : CharCtrl.new(),
	Globals.CharCtrlType.WEPN_R : CharCtrl.new(),
	Globals.CharCtrlType.V_ZOOM : CharCtrl.new(),
	}

# called after the character is changed
func character_setter():
	pass


var trigger_primary: bool = false:
	get:
		return trigger_primary
	set(value):
		if trigger_primary != value:
			trigger_primary = value
			if value:
				trigger_primary_press()
				if MultiplayerState.role != Globals.MultiplayerRole.NONE:
					trigger_primary_press.rpc()
			else:
				trigger_primary_release()
				if MultiplayerState.role != Globals.MultiplayerRole.NONE:
					trigger_primary_release.rpc()


var trigger_secondary: bool = false:
	get:
		return trigger_secondary
	set(value):
		if trigger_secondary != value:
			trigger_secondary = value
			if value:
				trigger_secondary_press()
				if MultiplayerState.role != Globals.MultiplayerRole.NONE:
					trigger_secondary_press.rpc()
			else:
				trigger_secondary_release()
				if MultiplayerState.role != Globals.MultiplayerRole.NONE:
					trigger_secondary_release.rpc()


var control_reload: bool = false:
	get:
		return control_reload
	set(value):
#		print("Setting control_reload to ", value)
		if control_reload != value:
			control_reload = value
			if value:
				if multiplayer.has_multiplayer_peer():
					reload_press.rpc()
				reload_press()
			else:
				if multiplayer.has_multiplayer_peer():
					reload_release.rpc()
				reload_release()


@rpc("call_remote", "any_peer", "reliable")
func trigger_primary_press():
	pass #print("Primary trigger press")


@rpc("call_remote", "any_peer", "reliable")
func trigger_primary_release():
	pass #print("Primary trigger release")


@rpc("call_remote", "any_peer", "reliable")
func trigger_secondary_press():
	pass #print("Secondary trigger press")

@rpc("call_remote", "any_peer", "reliable")
func trigger_secondary_release():
	pass #print("Secondary trigger release")

@rpc("call_remote", "any_peer", "reliable")
func reload_press():
	pass #print("Reload press")

@rpc("call_remote", "any_peer", "reliable")
func reload_release():
	pass #print("Reload release")

@rpc("call_remote", "any_peer", "reliable")
func deal_damage(target):
	pass

#@rpc("call_remote", "any_peer", "reliable")
#func view_zoom():
#	pass


# stub to be overloaded by subclasses
func process(delta):
	pass


# reset the weapon state - usually after a repawn
func reset():
	print("The reset method must be overloaded on descendant classes")


func _ready() -> void:
	# controls are missing control_type
	for ctrl in controls.keys():
		var type = ctrl
		controls[type].control_type = type


func _controller_event(event: CharCtrlEvent) -> void:
	# apply control changes to locally tracked events
	for cc in event.control_changes:
		if is_instance_valid(cc):
			if cc.control_type in controls.keys():
				controls[cc.control_type].enabled = cc.enabled

	#primary trigger
	if controls[Globals.CharCtrlType.TRIG_P].changed: # changed gets reset to false whenever we check it
		trigger_primary = controls[Globals.CharCtrlType.TRIG_P].enabled #and not controls[Globals.CharCtrlType.V_ZOOM].enabled

	# secondary trigger
	if controls[Globals.CharCtrlType.TRIG_S].changed: # changed gets reset to false whenever we check it
		trigger_secondary = controls[Globals.CharCtrlType.TRIG_S].enabled #and not controls[Globals.CharCtrlType.V_ZOOM].enabled

	# reloading
	if controls[Globals.CharCtrlType.WEPN_R].changed:
#		print("Activating reload")
		control_reload = controls[Globals.CharCtrlType.WEPN_R].enabled #and not controls[Globals.CharCtrlType.V_ZOOM].enabled
