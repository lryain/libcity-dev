extends Node3D

func fail():
	get_tree().quit(1)


func succeed():
	get_tree().quit(0)


func _ready() -> void:
	if randf() < 0.5:
		fail()
	else:
		succeed()
