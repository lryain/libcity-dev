extends Node3D

@onready var source = $DamageSource
@onready var character = $Character
@onready var compass = $Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _input(event: InputEvent) -> void:
	var mouse_motion = event as InputEventMouseMotion
	if mouse_motion:
		character.rotate_y(-event.relative.x / 100)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
#	character.rotate(Vector3.UP, delta/4)

	var move := Vector3.ZERO

	if Input.is_action_pressed("move_left"):
		move.x -= 1
	if Input.is_action_pressed("move_right"):
		move.x += 1
	if Input.is_action_pressed("move_forward"):
		move.z -= 1
	if Input.is_action_pressed("move_backward"):
		move.z += 1

	character.translate(move * delta * 10)

	var loc_a = Vector2(character.position.x, character.position.z)
	print("Loc a: ", loc_a)

	var loc_b = Vector2(source.position.x, source.position.z)
	print("Loc b: ", loc_b)

	var distance = log(loc_a.distance_to(loc_b) * 10 + 1) * 30

	$Control/ColorRect.position.x = distance + 50
	$Control/ColorRect.size.y = 25

	var angle = loc_a.rotated(character.rotation.y).angle_to_point(loc_b.rotated(character.rotation.y))

	compass.rotation = angle

