extends Node
class_name CameraShake

@export var enabled := false:
	set(value):
		if enabled != value:
			set_process(value)
			enabled = value

# add the shake on top of existing offest, rather than replacing them
@export var additive : bool = false:
	set(value):
		additive = value
		additive_factor = 1 if value else 0

@export var camera : Camera3D = get_owner()

@export var shake_amount := 0.0 # how muhc of the effect is applied?
@export var shake_trim := 0.01 # multiplier that defines where 1.0 amount is 
@export var shake_horizontal := 1.0
@export var shake_vertical := 1.0
@export var shake_roll := 0.0


@export var shake_decay := 0.0 # how quicky does the shake amount go towards 0?

@export var noise : FastNoiseLite

@onready var additive_factor = 1 if additive else 0


func _ready():
	set_process(enabled)


func _process(delta):
	# first check if it make sense to do any work at all
	
	if get_viewport().get_camera_3d() == camera:
#		print("Camera rotation Z: ", camera.rotation.z)
		if shake_amount > 0:
			var time : float = Time.get_ticks_msec() * Engine.time_scale
			camera.h_offset = (camera.h_offset * additive_factor) + shake_amount * shake_trim * shake_horizontal *\
				noise.get_noise_2dv(Vector2(0.3, 0.7).normalized() * time / 10.0)
			camera.v_offset = (camera.v_offset * additive_factor) + shake_amount * shake_trim * shake_vertical *\
				noise.get_noise_2dv(Vector2(0.7, 0.3).normalized() * (time + 92019) / 10.0)
			camera.rotation.z = shake_amount * shake_trim * shake_roll *\
				noise.get_noise_2dv(Vector2(0.5, 0.5).normalized() * (time + 32919) / 10.0)
			
			shake_amount -= delta * shake_decay
			shake_amount = clampf(shake_amount, 0, 1)
				
		elif not additive: # reset the values to ensure other shakes applied after this one won't cause drift
			camera.h_offset = 0
			camera.v_offset = 0
