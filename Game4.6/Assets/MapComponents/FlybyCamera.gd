extends Path3D

@onready var follow := $FlybyCameraFollow
@onready var pivot := $FlybyCameraFollow/Pivot
@onready var camera := $FlybyCameraFollow/Pivot/Camera

@export var speed : float = 1

@export var smooth := 2.0

func _process(delta):
	camera.current = true

	# Animate the Camera movement along the path
	follow.progress += delta * speed
	pivot.global_transform.origin = pivot.global_transform.origin.slerp(follow.global_transform.origin, delta / smooth)
	pivot.global_transform.basis = pivot.global_transform.basis.orthonormalized().slerp(follow.global_transform.basis.orthonormalized(), delta / smooth)
