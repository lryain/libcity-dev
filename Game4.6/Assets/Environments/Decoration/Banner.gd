extends MeshInstance3D

# add a random per-instance time offset to the shader animation
func _ready():
	set_instance_shader_parameter(&"RandomTimeOffset", randf_range(0, 10000))
