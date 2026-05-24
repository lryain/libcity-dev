extends Node3D

func _ready() -> void:
	$Gibs.emitting = true

func _on_Timer_timeout() -> void:
	queue_free()
