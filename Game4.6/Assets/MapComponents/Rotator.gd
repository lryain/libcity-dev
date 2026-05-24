extends Node3D

@export var speed : float = 1
@export var character : Character

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if character:
		character.get_node("SpawnFX").hide()
	rotate_y(speed * delta)
