class_name CharCtrlChange

var enabled : bool
var changed : bool
var control_type : Globals.CharCtrlType

func _init(control_type: Globals.CharCtrlType):
	self.control_type = control_type
	self.enabled = false
	self.changed = false

func is_enabled() -> bool:
	return self.enabled


func is_changed() -> bool:
	return self.changed


func set_enabled(value: bool) -> void:
	self.enabled = value


func set_changed(value: bool) -> void:
	self.changed = value

#func encode() -> PackedByteArray:
#	var buf: PackedByteArray
#	buf.resize(2)
#	buf.set(0, enabled)
#	buf.set(1, changed)
#	return buf
#
#func decode(data: PackedByteArray) -> void:
#	assert(data.size() == 2, "Invalid data packet size! Expected 2 bytes.")
#
#	enabled = true if data[0] == 1 else false
#	changed = true if data[1] == 1 else false
