extends Node3D

@export var slide_speed = 4.
@export var slide_distance = 1.3

var moving = false
var opening = false
var closed_position

func _ready():
	closed_position = position.x

func _process(delta):
	if opening and moving:
		if slide_distance > 0:
			translate(Vector3(slide_speed * delta, 0, 0))
			if position.x >= closed_position + slide_distance:
				position.x = closed_position + slide_distance
				moving = false
		if slide_distance < 0:
			translate(Vector3(-slide_speed * delta, 0, 0))
			if position.x <= closed_position + slide_distance:
				position.x = closed_position + slide_distance
				moving = false
	elif not opening and moving:
		if slide_distance > 0:
			translate(Vector3(-slide_speed * delta, 0, 0))
			if position.x <= closed_position:
				position.x = closed_position
				moving = false
		if slide_distance < 0:
			translate(Vector3(slide_speed * delta, 0, 0))
			if position.x >= closed_position:
				position.x = closed_position
				moving = false


func _on_trigger_area_body_entered(body):
	if body is Character:
		opening = true
		moving = true
	


func _on_trigger_area_body_exited(body):
	if body is Character:
		opening = false
		moving = true
