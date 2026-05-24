extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	Globals.focus = Globals.Focus.GAME
	Globals.current_character = $CharacterPlayer
	MultiplayerState.local_character = $CharacterPlayer


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
