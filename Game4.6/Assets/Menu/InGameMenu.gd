extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_switch_teams_pressed():
	var character = MultiplayerState.local_character

	if not character:
		print("Trying to switch teams on a non-existent local character")
		return

	# move character from one team to another
	var new_team = 2 if character.state.team == 1 else 1

	Globals.game_state.change_character_team(multiplayer.get_unique_id(), new_team)
	Globals.game_state.change_character_team.rpc(multiplayer.get_unique_id(), new_team)

	# get back to the game
	Globals.focus = Globals.Focus.GAME
