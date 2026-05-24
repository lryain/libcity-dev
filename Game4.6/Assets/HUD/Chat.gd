extends Control

const MAX_CHAT_LINES = 10
const MAX_CHAT_RECORDS = 50

var logger: Node

@onready var chat_history : RichTextLabel = $VBoxContainer/ChatHistory
@onready var chat_typing = $VBoxContainer/Typing
@onready var chat_editor = $VBoxContainer/Typing/Editor
@onready var chat_label = $VBoxContainer/Typing/Label
@onready var chat_editor_bg = $VBoxContainer/Typing/Editor/Panel

var fade_tween : Tween

# this will store raw chat message commands that will be replayed to newly joining peers
var chat_record = []

enum ChatState {INACTIVE, TYPING_ALL, TYPING_TEAM}


var state = ChatState.INACTIVE :
	set(new_state):
		state = new_state
		match new_state:
			ChatState.INACTIVE:
				chat_typing.hide()
				chat_editor.release_focus()
			ChatState.TYPING_ALL:
				chat_label.text = "to all: "
				chat_typing.show()
				chat_editor.grab_focus()
				chat_editor.text = ''
				chat_editor_bg.modulate = Globals.team_colors[0]
#				chat_label.modulate = chat_editor_bg.modulate
			ChatState.TYPING_TEAM:
				chat_label.text = "to team: "
				chat_typing.show()
				chat_editor.grab_focus()
				chat_editor.text = ''
				chat_editor_bg.modulate = Globals.team_colors[Globals.current_character.state.team]
#				chat_label.modulate = chat_editor_bg.modulate


func _on_peer_profile_updated(pid: int):
	pass
#	print("Chat got info that profile is now available for pid ", pid, " and their name is ", Globals.game_state.profiles_by_pid[pid].display_name)


func _on_peer_connected(pid: int):
	while not Globals.game_state.profiles_by_pid.keys().has(pid):
#		print("Chat is waiting for new peer profile. pid ", pid)
		await Globals.game_state.peer_profile_updated

	var disp_name : String = Globals.game_state.profiles_by_pid[pid].display_name
	var disp_color : Color = Globals.game_state.profiles_by_pid[pid].display_color
#	print("Sending notification about peer joining with name ", disp_name)
	for i in Globals.game_state.characters_by_pid.keys():
		if i != pid:
			chat_notification.rpc_id(i, "Player [color=" + disp_color.to_html(false) +"]" + Globals.game_state.profiles_by_pid[pid].display_name + "[/color] joined")
		else:
			chat_notification.rpc_id(i, Settings.get_var("host_welcome_message"))


func _on_peer_disconnected(pid):
	var disp_name : String = Globals.game_state.profiles_by_pid[pid].display_name
	var disp_color : Color = Globals.game_state.profiles_by_pid[pid].display_color
	chat_notification.rpc("Player [color=" + disp_color.to_html(false) +"]" + Globals.game_state.profiles_by_pid[pid].display_name + "[/color] left")


# fade the chat transparency in and out
func chat_fade(auto_dim : bool = true, dim_only : bool = false):
	if fade_tween is Tween:
		if fade_tween.is_running():
			fade_tween.kill()

	if not dim_only:
		fade_tween = create_tween()
		fade_tween.tween_property(chat_history, "modulate", Color.WHITE, 0.05)

	if auto_dim == true:
		fade_tween.tween_interval(3)

	if auto_dim == true or dim_only == true:
		fade_tween.tween_property(chat_history, "modulate", Color(1, 1, 1, 0.5), 1)


func _ready() -> void:
	logger = get_node("/root/Logger")
	# remove any development text
	chat_history.clear()

	# skip the rest if we're offline
	if not multiplayer.has_multiplayer_peer():
		return

	if MultiplayerState.role == Globals.MultiplayerRole.NONE:
		return

	# if we're the server, listen on for newly connected peers
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		# wait for GameState to report recieving the character profile for this peer
		# so that we can show a name
		Globals.game_state.peer_profile_updated.connect(_on_peer_profile_updated)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


	# pad all lines to be empty to force mesages to appear from the bottom
	for i in range(1, MAX_CHAT_LINES):
		chat_history.newline()

	# ensure chat is hidden
	state = ChatState.INACTIVE

	if multiplayer.is_server():
		# send the chat record to new peers
		multiplayer.peer_connected.connect(send_chat_record_to_peer)


func _unhandled_input(_event) -> void:
	if state == ChatState.INACTIVE:
		if Input.is_action_just_pressed("say_all"):
			Globals.focus = Globals.Focus.CHAT
			state = ChatState.TYPING_ALL
			get_tree().get_root().set_input_as_handled()
			chat_fade(false)

		if Input.is_action_just_pressed("say_team"):
			Globals.focus = Globals.Focus.CHAT
			state = ChatState.TYPING_TEAM
			get_tree().get_root().set_input_as_handled()
			chat_fade(false)

	elif Input.is_action_just_pressed("say_cancel"):
			Globals.focus = Globals.focus_previous
			state = ChatState.INACTIVE
			get_tree().get_root().set_input_as_handled()
			chat_fade(false, true)

	# don't pass through events if the chat is active
	if state != ChatState.INACTIVE:
		get_tree().get_root().set_input_as_handled()


#@rpc("call_remote", "any_peer", "reliable")
func send_chat_record_to_peer(peer_id: int):
	if chat_record.is_empty():
		return

#	print("Getting new peer ", peer_id, " up to speed on the chat...")
	for i in chat_record:
		# send all recorded messages in silent mode
		if Globals.game_state.characters_by_pid[i.sender_pid]:
			chat_message.rpc_id(peer_id, i.sender_pid, i.recipient_team, i.message, true)
		else:
			pass # skipping messages sent from plaayers who already left
#		print("Sent message ", i)


func clip_chat_history():
	if chat_history.get_line_count() > MAX_CHAT_LINES: #if w have more than 10 lines:
		chat_history.remove_paragraph(0)

	# for servers we also clip the chat_record
	if multiplayer.is_server():
		if chat_record.size() > MAX_CHAT_RECORDS:
			chat_record.remove_at(0)


@rpc("call_local", "any_peer", "reliable")
func chat_message(sender_pid: int, recipient_team, message: String, silent : bool = false) -> void:
	# if we are the server here...
	var sender_name = Globals.game_state.profiles_by_pid[sender_pid].display_name
	print(["chat message: \"", message, "\" from ", sender_name, " (PID ", sender_pid,") to ", recipient_team])
	logger.event(["chat message: \"", message, "\" from ", sender_name, " (PID ", sender_pid,") to ", recipient_team])
	if multiplayer.is_server():
		# we should also record the messages to replay them to newly joined peers
		var record = {
			&'sender_pid' : sender_pid,
			&'recipient_team' : recipient_team,
			&'message' : message,
		}
		chat_record.append(record)

	# this variable will let us apply additional text styling to ensure we see that it's a team message
	var is_team_message : bool
	if recipient_team == 0: # this message is for everyone
		is_team_message = false
	elif recipient_team == Globals.current_character.state.team:
		is_team_message = true # this message is for our team
	else:
		return # this message is not intended for our team

	var sender : Character = Globals.game_state.characters_by_pid[sender_pid]
	print("Chat message revieved from PID ", sender_pid, " name: ", sender.profile.display_name)
	if not chat_history.text.is_empty():
		chat_history.newline() # after previous message (if any)

	# insert typing character's badge (should probably be avatar, or both?)
	chat_history.add_image(Badges.get_top_priority_badge_texture(sender.profile.badges), 16, 16, Color.from_hsv(0,0,1,1), INLINE_ALIGNMENT_CENTER)

	var msg_color : Color # color of the message text
	var msg_style_in : String # opening style markup
	var msg_style_out : String # closing style markup

	if is_team_message:
		msg_color = Globals.team_colors[recipient_team]
		msg_style_in = "[i][b]"
		msg_style_out = "[/b][/i]"

		if not silent:
			$Message.pitch_scale = 0.9
			$Message.play()
	else:
		msg_color = Globals.team_colors[0]
		msg_style_in = "[i]"
		msg_style_out = "[/i]"

		if not silent:
			$Message.pitch_scale = 1
			$Message.play()

	chat_history.append_text(' [b][color=' + sender.profile.display_color.to_html() +']' +\
	str(sender.profile.display_name) + '[/color][/b] : ' + msg_style_in +\
	'[color=' + msg_color.to_html() + ']' + message + '[/color]' + msg_style_out)

	# ensure we're not over the line limit
	clip_chat_history()

	chat_fade()


@rpc("call_local", "any_peer", "reliable")
func chat_notification(message: String) -> void:
	logger.event(["chat notification: \"", message, "\""])
	chat_history.append_text('\n · ' + '[i]' + message + '[/i]')
	# ensure we're not over the line limit
	clip_chat_history()

	$Message.pitch_scale = 1.1
	$Message.play()

	chat_fade()


func _on_Editor_text_submitted(new_text: String) -> void:
	if new_text.is_empty():
		pass
	else:
		var sender_id = multiplayer.get_unique_id()
		var team : int
		if state == ChatState.TYPING_ALL:
			team = 0
		elif state == ChatState.TYPING_TEAM:
			team = Globals.current_character.state.team

		chat_message.rpc(sender_id, team, new_text)
		chat_editor.text = ""

	state = ChatState.INACTIVE
	Globals.focus = Globals.Focus.GAME

	chat_fade()
