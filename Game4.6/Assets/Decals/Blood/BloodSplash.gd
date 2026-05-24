extends Decal

func _ready() -> void:
	global_rotate(Vector3.UP, randf_range(0, PI * 2))
