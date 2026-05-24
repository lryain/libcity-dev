extends Node3D

func _ready() -> void:
	print("Spawned bullet FLYBY sound: ", name)

func _on_SoundPlayer_SoundPlayer_finished():
	pass


func _on_audio_stream_player_3d_finished() -> void:
#	return
	queue_free()
