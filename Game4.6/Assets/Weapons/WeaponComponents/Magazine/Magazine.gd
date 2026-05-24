extends Node3D
class_name Magazine

@export_range(0, 255, 1)
var clip_size : int = 0 # 0 for infinite clip size

@onready var remaining_shots : int = clip_size

var is_reloading = false

func is_empty() -> bool:
	return remaining_shots == 0 and clip_size != 0


func reload(on_completed : Signal):
	remaining_shots = clip_size
	is_reloading = true
	await(on_completed)
	is_reloading = false


# reset to initial state, usually after a respawn
func reset() -> void:
	remaining_shots = clip_size
	is_reloading = false


func feed_into_slide(amount: int = 1):
#	print("Feeding into slide")
	if clip_size == 0:
		return true
	else:
#		print("Magazing checks remaining shots: ", remaining_shots)
#		print("Magazing checks ammo cost: ", amount)
		if remaining_shots >= amount:
			remaining_shots -= amount
#			print("Magazing can shoot!")
			return true
		else:
#			print("Magazing doens't have enough ammo to shoot!")
			return false
