extends Node3D


func ready():
	pass

func _unhandled_key_input(event):
	Settings.apply_display_fullscreen(true)
	Engine.time_scale = $Label/HSlider.value
	$AnimationPlayer.play("Ragdoll")
	var damage = Damage.new()
	damage.damage_amount = 100
#	$Character.jetpack_active = true
	$Character.die(damage)
	await get_tree().create_timer(3).timeout
	Engine.time_scale = 1
#	$AnimationPlayer.play("RESET")
