extends Control

var players = {} # PID : bool

var players_total := 1
var players_ready := 0

var match_start_countdown_timer : SceneTreeTimer
signal match_start_countdown_over

var local_player_ready := false:
	set(value):
		local_player_ready = value

		$Label/Button/Ready.visible = local_player_ready
		$Label/Button/NotReady.visible = not local_player_ready

		if multiplayer.is_server():
			return


@rpc("any_peer", "call_remote", "reliable")
func set_peer_ready(ready):
	if not multiplayer.is_server():
		return

	var pid = multiplayer.get_remote_sender_id()
	if pid in [0, 1]:
		return

	players[pid] = ready

	update_ready_numbers()
	set_values.rpc(players_total, players_ready)
	update_numbers_label()


func update_ready_numbers():
	players_total = players.keys().size()
	#players.keys().filter(func(x): return players[x]).size()
	var _players_ready : int = 0
	for i in players.keys():
		if players[i]:
			_players_ready += 1

	self.players_ready = _players_ready


@rpc("any_peer", "call_remote", "reliable")
func set_values(num_total : int, num_ready : int):
	if multiplayer.is_server():
		return

	self.players_total = num_total
	self.players_ready = num_ready

	update_numbers_label()


func update_numbers_label():
	$Label/Ready.text = "%d/%d players ready" % [players_ready, players_total]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# initiate the Lobby UI
	local_player_ready = false
	match_start_countdown_timer = get_tree().create_timer(15)
	match_start_countdown_timer.timeout.connect(func(): match_start_countdown_over.emit())
	update_numbers_label()

	$HostPanel.visible = multiplayer.is_server()


func reset():
	local_player_ready = false
#	$Label/Countdown.hide()
	$Label/Button/Ready.hide()
	$Label/Button/NotReady.show()
	for i in players.keys():
		players[i] = false
	update_numbers_label()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if match_start_countdown_timer:
		$Label/Countdown.text = "%d seconds" % [roundi(match_start_countdown_timer.time_left)]

	update_ready_numbers()
	update_numbers_label()


func _on_button_toggled(button_pressed: bool) -> void:
	local_player_ready = button_pressed
	players[multiplayer.get_unique_id()] = button_pressed
	update_numbers_label()

	$Label/Button.text = "I'm" + (" NOT" if button_pressed else "") + " READY!"


func _on_button_pressed() -> void:
	match_start_countdown_over.emit()


func _on_time_limit_value_changed(value: float) -> void:
	MultiplayerState.game_config.match_time_limit_minutes = int(value)
	%TimeLimit/Value.text = str(MultiplayerState.game_config.match_time_limit_minutes) + " min"


func _on_score_limit_value_changed(value: float) -> void:
	MultiplayerState.game_config.match_score_limit = int(value) * 25
	%ScoreLimit/Value.text = str(MultiplayerState.game_config.match_score_limit)
