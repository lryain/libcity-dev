extends Control

@onready var marker_scene = load("res://Assets/HUD/DamageCompassMarker.tscn")

var character : Character

func add_marker(damage: Damage) -> void:
	var marker = marker_scene.instantiate()
#	var marker = load("res://Assets/HUD/DamageCompassMarker.tscn").instantiate()
	marker.character = character
	marker.damage = damage
	add_child.call_deferred(marker)


func clear_markers():
#	print("Damage compass clearing all markers")
	for marker in get_children():
		marker.queue_free()
