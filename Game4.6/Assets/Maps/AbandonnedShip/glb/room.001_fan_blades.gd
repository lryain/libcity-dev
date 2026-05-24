extends Node3D

var speed = 1

func _process(delta):
	rotate(Vector3.UP, -speed * delta)
