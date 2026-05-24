@tool
extends Node3D


func _ready() -> void:
	$SunHalo.global_position = $Sun.global_transform.basis.z * 1024
	
	# initialize moon wiht a random rotation
	$Moon.rotate_object_local(Vector3.FORWARD, randf())
	$Moon.rotate_object_local(Vector3.LEFT, randf())
	$Moon.rotate_object_local(Vector3.UP, randf())


func _process(delta):
	# Skybox needs to follow the camera
	if not get_viewport().get_camera_3d():
		return

	if not Engine.is_editor_hint():
		%Skybox.global_position = get_viewport().get_camera_3d().global_position
		
	$Clouds.get_active_material(0).uv1_offset += Vector3(1.0, 0, 0.4) * delta / 350
	$Clouds.get_active_material(0).uv2_offset += Vector3(0.3, 0, 1) * delta / 15
		
	$Moon.rotate_object_local(Vector3.FORWARD, delta * - 0.007)
	$Moon.rotate_object_local(Vector3.LEFT, delta * 0.01)
	$Moon.rotate_object_local(Vector3.UP, delta * -0.025)
