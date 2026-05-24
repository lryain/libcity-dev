# this class contains all infomation that a character controller can produce within one frame (aiming, activating/decatinvating binary controls fro movement, weapons etc.)
class_name CharCtrlEvent

# this array should contain a list of CharacterCOntrolleChanges - key presses, releaes etc.
var control_changes : Array[CharCtrlChange]

# relative change in degrees. pre-multipied with sensitivity for mouse look
var aim : Vector2

# apply absolute changes
var use_absolute : bool = false

# absolute aim
var abs_aim : Vector2 # x = character.y rotation; y = head.x_rotation

# absolute, world-space location
var abs_location : Vector3

# message to be sent in chat
var chat_send : String

# for tracking event order
var index : int = 0

# for timing playback
var frame : int = 0

# bit-shifting to encode all binary controls in a 4-byte integer
func encode() -> int:
	var buf = 0
	for cc in control_changes:
		buf += 1 << cc.control_type

	return buf

# bit-shifting to decode all binary controls from a 4-byte integer
func decode(buf: int) -> void:
	for type in Globals.CharCtrlType:
		var mask = 1 << Globals.CharCtrlType[type]
		var cc = CharCtrlChange.new(Globals.CharCtrlType[type])
		cc.enabled = true if mask & buf != 0 else false
		control_changes.append(cc)

#	for cc in control_changes:
#		buf += 1 << cc.control_type


#const buf_compression : bool = true
#const buf_compression_mode : int = 1
#
#const buf_size = 16 + 64 + 64
#
#func encode() -> PackedByteArray:
#	var buf : PackedByteArray
#	buf.resize(buf_size)
#	buf.encode_u16(0, index)
#	buf.encode_float(16,		aim.x)
#	buf.encode_float(16 + 64,	aim.y)
#
#	#buf.set(32 + 64 + 1, )
#
#	print("encoded uncompressed size: ", buf.size())
#	if buf_compression:
#		buf = buf.compress(buf_compression_mode)
#		print("encoded compressed size: ", buf.size())
#	return buf
#
#func decode(buf: PackedByteArray) -> void:
#	if buf_compression:
#		buf = buf.decompress(buf_size, buf_compression_mode)
#
#	assert (typeof(buf) == TYPE_PACKED_BYTE_ARRAY and buf.size() == buf_size, "Invalid CharacterControlEvent binary data. Cannot decode.")
##	print("decode")
#	index = buf.decode_u16(0)
#	aim.x = buf.decode_float(16)
#	aim.y = buf.decode_float(16 + 64)
