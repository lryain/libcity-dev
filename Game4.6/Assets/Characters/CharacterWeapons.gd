class_name CharWeapons extends Node3D

const SWITCH_DOWN_DURATION = 0.1 # time to put away current weapon
const SWITCH_UP_DURATION = 0.2 # time to take out new weapon

var character : Character
signal character_hud_update(update: CharHudUpdate)

#var hands_global_position : Vector3
#var previous_hands_global_position : Vector3
#var head_previous_position : Vector3
#var head_previous_rotation : Vector3

var hands_linear_velocity := Vector3.ZERO
#var hands_angular_velocity := Vector3.ZERO

# carefully tuned factors - do not touch
#var hands_spring_factor : float = 1.5
#var hands_damping_factor : float = 20
#var hands_overshoot_factor : float = 25
#var hands_max_distance : float = 0.05
var hands_spring_factor : float = 5
var hands_damping_factor : float = 30
var hands_overshoot_factor : float = 25
#var hands_max_distance : float = 0.05




var weapons_root : Node3D:
	set(value):
		weapons_root = value
		#print_debug(value)
		initialize()

var current : Weapon
var switching : bool: # if this is true, weapons can't be switched or controlled
	set(value):
		if switching == value:
			return

		switching = value

		var update = CharHudUpdate.new()
		update.character = character
		update.state = character.state

		if switching:
			update.current_weapon = Weapons.Weapon.NONE
		else:
			var current_weapon : Weapons.Weapon
			if current == primary:
				current_weapon = character.loadout.primary
			elif current == secondary:
				current_weapon = character.loadout.secondary
			else:
				current_weapon = character.loadout.tertiary
			update.current_weapon = current_weapon
#		print("Sending weapon switching HUD update")
		character_hud_update.emit(update)

var last : Weapon

var primary : Weapon
var secondary : Weapon
var tertiary : Weapon



func initialize():
#	hands_global_position = character.hands.global_position

	if character.loadout == null:
		print_debug("Missing loadout")
		return

	var loadout : CharLoadout = character.loadout

	if loadout.primary == Weapons.Weapon.NONE or loadout.primary == null:
		pass
#		print_debug("Primary weapon is none")
	else:
		var primary_resource = load(Weapons.WeaponScenePaths[loadout.primary])
		primary = primary_resource.instantiate()
		weapons_root.add_child(primary)
		primary.global_transform = weapons_root.global_transform
		primary.character = character
		switch_weapon(primary)

	if loadout.secondary == Weapons.Weapon.NONE or loadout.secondary == null:
		pass
#		print_debug("Secondary weapon is none")
	else:
		var secondary_resource = load(Weapons.WeaponScenePaths[loadout.secondary])
		secondary = secondary_resource.instantiate()
		weapons_root.add_child(secondary)
		secondary.global_transform = weapons_root.global_transform
		secondary.character = character
		secondary.hide()
#	print("tertiary weapon is ", loadout.tertiary)
	if loadout.tertiary == Weapons.Weapon.NONE or loadout.tertiary == null:
		pass
#		print_debug("tertiary weapon is none")
	else:
		var tertiary_resource = load(Weapons.WeaponScenePaths[loadout.tertiary])
		tertiary = tertiary_resource.instantiate()
		weapons_root.add_child(tertiary)
		tertiary.global_transform = weapons_root.global_transform
		tertiary.character = character
		tertiary.hide()

	hands_linear_velocity = Vector3.ZERO
#	hands_angular_velocity = Vector3.ZERO
#	hands_previous_position =


func switch_weapon(weapon: Weapon):
	if weapon == current:
#		print_debug("Trying to switch to the current weapon")
		return
	else:
#		print("Switching to weapon: ", weapon.name)

		# weapon switching animation
		var position_up = weapons_root.position
		var position_down = position_up + Vector3.DOWN
		var tween = weapons_root.create_tween()

		if current:
			switching = true
			current.trigger_primary = false
			current.trigger_secondary = false
			tween.tween_property(weapons_root, "position", position_down, SWITCH_DOWN_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
			await tween.finished
			current.hide()
#			current.is_current = false
			last = current

		current = weapon
		current.show()
		var tween2 = weapons_root.create_tween()
		tween2.tween_property(weapons_root, "position", position_up, SWITCH_UP_DURATION).from(position_down).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		await tween2.finished
		switching = false


#@rpc("call_remote", "any_peer", "reliable")
#func _controller_event_remote(event_packed: PackedByteArray):
#	var event : CharCtrlEvent = bytes_to_var(event_packed)
#	_controller_event(event)


func _controller_event(event: CharCtrlEvent) -> void:
	if current is Weapon and switching == false:

		# filter events removing anything that's not relavant to an individual weapon control
		for cc in event.control_changes:
			if not is_instance_valid(cc):
				continue
			if cc.control_type not in [
				Globals.CharCtrlType.TRIG_P,
				Globals.CharCtrlType.TRIG_S,
				Globals.CharCtrlType.WEPN_R,
				Globals.CharCtrlType.V_ZOOM,
				]:
				event.control_changes.erase(cc)
		# pass the input event to the currently weilded weapon
		current._controller_event(event)


func process(delta):
	if character.is_queued_for_deletion():
		return

	if current and not switching:
		current.process(delta)

	# can't switch weapons if previous switch didn't finish
	if not switching:
		# selected primary weapon
		if character.controls[Globals.CharCtrlType.WEPN_1].changed and \
			character.controls[Globals.CharCtrlType.WEPN_1].enabled:
#				print("Switching to primary weapon")
				switch_weapon(primary)

		# selected secondary weapon
		if character.controls[Globals.CharCtrlType.WEPN_2].changed and \
			character.controls[Globals.CharCtrlType.WEPN_2].enabled:
#				print("Switching to secondary weapon")
				switch_weapon(secondary)

		# selected tertiary weapon
		if character.controls[Globals.CharCtrlType.WEPN_3].changed and \
			character.controls[Globals.CharCtrlType.WEPN_3].enabled:
#				print("Switching to tertiary weapon")
				switch_weapon(tertiary)

		# selected last used weapon
		if character.controls[Globals.CharCtrlType.WEPN_L].changed and \
			character.controls[Globals.CharCtrlType.WEPN_L].enabled and \
			last != null:
#				print("Switching to last used weapon")
				switch_weapon(last)

		if character.controls[Globals.CharCtrlType.WEPN_P].changed and \
			character.controls[Globals.CharCtrlType.WEPN_P].enabled:
				var previous : Weapon

				if current == primary:
					previous = tertiary
				elif current == secondary:
					previous = primary
				else:
					previous = secondary

				switch_weapon(previous)

		if character.controls[Globals.CharCtrlType.WEPN_N].changed and \
			character.controls[Globals.CharCtrlType.WEPN_N].enabled:
				var next : Weapon

				if current == primary:
					next = secondary
				elif current == secondary:
					next = tertiary
				else:
					next = primary

				switch_weapon(next)
