extends Node3D
class_name Barrel

@export_range(0.0, 1)
var inaccuracy = 0.0


@export_node_path
var slide_path : NodePath

@onready
var slide : Slide = get_node(slide_path)


#@onready
var character : Character #get_parent().get_parent().get_parent()


func random_inaccuracy():
	# TODO: turn ProjectileSpawner randomly
	pass


func shoot():
	return false
