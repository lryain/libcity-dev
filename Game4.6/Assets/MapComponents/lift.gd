
# The lift sits at its home position (steps[0])
# When triggered by a player, it starts moving up to the next step
# then pause for 'pause_between_steps' seconds. After that, it starts
# moving up again if there are other floors upward, or goes directly down
# to lowest floor if it has reached the top floor already.
# Whenever the player leaves the lift, it returns immediatly to lowest floor.


extends Node3D

# Movement speed (m/s)
@export var speed = 4
# Height of each stop (m). First one is "home". Must be in ascending order.
@export var steps = []
# Pause time between each stop (s)
@export var pause_between_steps = 1.5


var moving = false
var current_step = 0
var step_reached = false
var step_reached_timer = 0


func _process(delta):
	if moving:
		if not step_reached:
			move_to(next_step(), delta)
		else:
			if step_reached_timer >= pause_between_steps:
				step_reached = false
				step_reached_timer = 0
			else:
				step_reached_timer += delta
	else:
		move_to(0, delta)
		step_reached = false


func next_step():
	if current_step < len(steps) - 1:
		return current_step + 1
	else:
		return 0


func move_to(step, delta):
	if position.y < steps[step]:
		translate(Vector3(0, speed * delta, 0))
		if position.y >= steps[step]:
			position.y = steps[step]
			current_step = step
			step_reached = true
	elif position.y > steps[step]:
		translate(Vector3(0, -speed * delta, 0))
		if position.y <= steps[step]:
			position.y = steps[step]
			current_step = step
			step_reached = true


func _on_trigger_area_body_entered(body):
	if body is Character:
		moving = true


func _on_trigger_area_body_exited(body):
	if body is Character:
		moving = false
