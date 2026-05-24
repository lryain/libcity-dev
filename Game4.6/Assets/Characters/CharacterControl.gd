class_name CharCtrl

var control_type : Globals.CharCtrlType
var action : StringName

var enabled : bool:
	set(value):
		if self.enabled != value:
			enabled = value
			changed = true

	get:
		self.changed = false
		return enabled

var changed : bool


func _init(control_type_new := Globals.CharCtrlType.UNDEFINED, action_new : StringName = &'') -> void:
	if control_type_new:
		self.control_type = control_type_new

	if action_new != &'':
		self.action = action_new


# evaluate this control's input
func get_control_change() -> CharCtrlChange:
	#print("get_input_change, action: ", var_to_str(action), "; enabled: ", enabled, "; changed: ", changed, "; ctrl_type: ", control_type)
	assert(self.action is StringName, "CharacterControl has NO assigned action. Cannot check input change!")
	assert(self.action != &"", "CharacterControl has an EMPTY assigned action. Cannot check input change!")
	var control_change = CharCtrlChange.new(control_type)
	if Input.is_action_just_pressed(self.action):
		control_change.enabled = true
		control_change.changed = true
	elif Input.is_action_just_released(self.action):
		control_change.enabled = false
		control_change.changed = true
	else:
		control_change.changed = false
	self.enabled = control_change.enabled
	self.changed = control_change.changed
	return control_change
