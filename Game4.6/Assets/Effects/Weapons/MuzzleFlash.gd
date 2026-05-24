extends Node3D

var smoke_offset : Vector2

@export var color : Color = Color(1,1,1):
	set(value):
		color = value
		$Flash["instance_shader_parameters/Color"] = value
		$Flash/Light.light_color = value


func shoot():
	if $AnimationPlayer.playback_active:
		$AnimationPlayer.stop()
	$AnimationPlayer.play("Shoot")


	#while $Flash["shader_uniforms/Offset"] == smoke_offset:
#	smoke_offset =  Vector2(randi_range(0,1), randi_range(0,1)) * 0.5
#	$Flash["shader_uniforms/Offset"] = smoke_offset
