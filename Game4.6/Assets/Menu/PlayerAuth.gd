extends Control

signal auth_menu_closed

var password_salt : String
var password_hash : String
var username : String
var password : String
var password1 : String
var password2 : String

var taken_usernames : Array[String]

const COLOR_OK = Color(0.5, 1, 0.5)
const COLOR_OK_STRONG = Color(0.5, 3, 0.5)
const COLOR_ERROR = Color(1, 0.5, 0.5)
const COLOR_ERROR_STRONG = Color(3, 0.5, 0.5)

var create_account_alter_colors = true

var username_error := false:
	set(value):
		if username_error == value:
			return # no change
		username_error = value
		var tween = create_tween()
		if value:
			$CenterContainer/Create/UserNameError.show()
			if create_account_alter_colors:
				$CenterContainer/Create/UserName.modulate = COLOR_ERROR_STRONG
				tween.tween_property($CenterContainer/Create/UserName, "modulate", COLOR_ERROR, 0.5).set_trans(Tween.TRANS_EXPO)

		else:
			$CenterContainer/Create/UserNameError.hide()
			if create_account_alter_colors:
				$CenterContainer/Create/UserName.modulate = COLOR_OK_STRONG
				tween.tween_property($CenterContainer/Create/UserName, "modulate", COLOR_OK, 0.5).set_trans(Tween.TRANS_EXPO)


var password1_error := false:
	set(value):
		if password1_error == value:
			return
		password1_error = value
		var tween = create_tween()
		if value:
			$CenterContainer/Create/Password1Error.show()
			if create_account_alter_colors:
				$CenterContainer/Create/Password1.modulate = COLOR_ERROR_STRONG
				tween.tween_property($CenterContainer/Create/Password1, "modulate", COLOR_ERROR, 0.5).set_trans(Tween.TRANS_EXPO)
		else:
			$CenterContainer/Create/Password1Error.hide()
			if create_account_alter_colors:
				$CenterContainer/Create/Password1.modulate = COLOR_OK_STRONG
				tween.tween_property($CenterContainer/Create/Password1, "modulate", COLOR_OK, 0.5).set_trans(Tween.TRANS_EXPO)


var password2_error := false:
	set(value):
		if password2_error == value:
			return
		password2_error = value
		var tween = create_tween()
		if value:
			$CenterContainer/Create/Password2Error.show()
			$CenterContainer/Create/Password2.modulate = COLOR_ERROR_STRONG
			tween.tween_property($CenterContainer/Create/Password2, "modulate", COLOR_ERROR, 0.5).set_trans(Tween.TRANS_EXPO)
		else:
			$CenterContainer/Create/Password2Error.hide()
			$CenterContainer/Create/Password2.modulate = COLOR_OK_STRONG
			tween.tween_property($CenterContainer/Create/Password2, "modulate", COLOR_OK, 0.5).set_trans(Tween.TRANS_EXPO)


func hash_password(pw, salt):
	var time_start = Time.get_ticks_msec()
	var new_hash = ""
	for i in range(0, pow(2,12)):
		new_hash = str(pw + salt + new_hash).sha256_text() # this is weak, only for testing

	prints("Hashing password took", Time.get_ticks_msec() - time_start, "ms")
	prints("Hashed password using salt:", salt,"got hash:", new_hash)
	return new_hash



func _ready():
	# These two are always hidden at the start, no matter what:
	$CenterContainer/AuthInfo.hide()
	$CenterContainer/Create.hide()

	# check the "don't ask again
	if Settings.get_var('auth_enabled_remember'):
		$CenterContainer/LoginOrNot.hide()
		if Settings.get_var('auth_enabled'):
			#MultiplayerState.auth_use = true
			$CenterContainer/Login.show()
			$CenterContainer/LoginOrNot/HBoxContainer2/DontAskAgain.button_pressed = true
		else:
			MultiplayerState.auth_enabled = false
			hide()
			auth_menu_closed.emit()
	else:
		$CenterContainer/Login.hide()
		$CenterContainer/LoginOrNot.show()

	if Settings.get_var('auth_username_remember'):
		$CenterContainer/Login/RememberMe.button_pressed = true
		$CenterContainer/Login/UserName.text = Settings.get_var('auth_username')


func _on_account_pressed():
	Settings.set_var('auth_enabled', true)
	if $CenterContainer/LoginOrNot/HBoxContainer2/DontAskAgain.button_pressed: # save the preference
		Settings.set_var('auth_enabled_remember', true)

	$CenterContainer/LoginOrNot.hide()
	$CenterContainer/Login.show()


func _on_cancel_pressed():
	$CenterContainer/Login.hide()
	$CenterContainer/LoginOrNot.show()


func _on_create_pressed():
	create_account_alter_colors = true
	$CenterContainer/LoginOrNot.hide()
	$CenterContainer/Create.show()

func _on_cancel_create_pressed():
	$CenterContainer/Create.hide()
	$CenterContainer/LoginOrNot.show()

	create_account_alter_colors = false

	$CenterContainer/Create/UserName.clear()
	$CenterContainer/Create/Password1.clear()
	$CenterContainer/Create/Password2.clear()

	$CenterContainer/Create/UserNameError.hide()
	$CenterContainer/Create/Password1Error.hide()
	$CenterContainer/Create/Password2Error.hide()

	$CenterContainer/Create/UserName.modulate = Color.WHITE
	$CenterContainer/Create/Password1.modulate = Color.WHITE
	$CenterContainer/Create/Password2.modulate = Color.WHITE

	$CenterContainer/Create/CreateError.hide()

func _on_create_confirm_pressed():
	username = $CenterContainer/Create/UserName.text
	password1 = $CenterContainer/Create/Password1.text
	password2 = $CenterContainer/Create/Password2.text

	# trigger verification to check for missing data
	_on_user_name_text_changed(username)
	_on_password_1_text_changed(password1)
	_on_password_2_text_changed(password2)

	if username_error or password1_error or password2_error:
		print("Invalid data, cannot create account. Fix errors and try again")
		return
	else:
		$CenterContainer/Create/UserName.editable = false
		$CenterContainer/Create/Password1.editable = false
		$CenterContainer/Create/Password2.editable = false

		var crypto = Crypto.new()

		var buf : PackedByteArray = crypto.generate_random_bytes(256 - 64)
		buf.resize(256)
		buf.encode_float(256 - 64, Time.get_unix_time_from_system())
		password_salt = Marshalls.raw_to_base64(buf)

		password_hash = hash_password(password1, password_salt)

		print("Salt: ", password_salt)
		print("Hash: ", password_hash)

		var request = ["create_account",
		{
			"peer_id": InfraServer.peer.get_unique_id(),
			"username": username,
			"password_hash": password_hash,
			"password_salt": password_salt,
			}
		]

		InfraServer.peer.put_var(request)
		print("Sent request.")

func process_create_account_reply(reply: int):
	var tween = create_tween()
	if reply == OK:
		$CenterContainer/Create/CreateConfirm.text = "Account Created!"
		$CenterContainer/Create/CreateConfirm.modulate = COLOR_OK_STRONG
		tween.tween_property($CenterContainer/Create/CreateConfirm, "modulate", COLOR_OK, 1).set_trans(Tween.TRANS_EXPO)
		$CenterContainer/Create/CreateConfirm.disabled = true
		$CenterContainer/Create/CancelCreate.hide()
		$CenterContainer/Create/GoToLogin.show()
		# the user can't go back to creating an account after just making one
		$CenterContainer/LoginOrNot/HBoxContainer/Create.hide()
		$CenterContainer/Login/Label.text = "Please log into your new account"

		$ConfettiL.emitting = true
		tween.tween_property($ConfettiR, "emitting", true, 0.5)
		tween.play()
	elif reply == ERR_ALREADY_IN_USE:
#		$CenterContainer/Create/CreateError.text = ""
#		$CenterContainer/Create/CreateError.show()
		$CenterContainer/Create/UserName.editable = true
		$CenterContainer/Create/Password1.editable = true
		$CenterContainer/Create/Password2.editable = true

		# chosen user name is already in use - add it to the list
		taken_usernames.append(username)
		_on_user_name_text_changed(username)
	elif reply == ERR_INVALID_DATA:
		$CenterContainer/Create/UserName.editable = true
		$CenterContainer/Create/Password1.editable = true
		$CenterContainer/Create/Password2.editable = true
		$CenterContainer/Create/CreateError.show()
		$CenterContainer/Create/CreateConfirm.modulate = COLOR_ERROR_STRONG
		tween.tween_property($CenterContainer/Create/CreateConfirm, "modulate", Color.WHITE, 3).set_trans(Tween.TRANS_EXPO)
		# trigger re-evaluateion of the username validity to display the error

func _on_user_name_text_changed(new_text):
	if new_text.is_empty():
		$CenterContainer/Create/UserNameError.text = "Please provide a user name"
		username_error = true
	elif new_text in taken_usernames:
		$CenterContainer/Create/UserNameError.text = "User name is already taken"
		username_error = true
	elif new_text.replace(" ", "") != new_text:
		$CenterContainer/Create/UserNameError.text = "No white characters"
		username_error = true
	elif new_text.rstrip("@!?<>[]{}#$%^&*()-=+|\\/,`~") != new_text:
		$CenterContainer/Create/UserNameError.text = "No special characters"
		username_error = true
	elif len(new_text) < 4:
		$CenterContainer/Create/UserNameError.text = "At least 4 characters"
		username_error = true
	elif len(new_text) > 24:
		$CenterContainer/Create/UserNameError.text = "No more than 24 characters"
		username_error = true
	elif new_text.to_lower() in ["username", "user", "player", "login", "name"]:
		$CenterContainer/Create/UserNameError.text = "Not personal enough"
		username_error = true
	else:
		username_error = false


func _on_password_1_text_changed(new_text):
	if new_text.is_empty():
		$CenterContainer/Create/Password1Error.text = "Please provide a password"
		password1_error = true
	elif len(new_text) < 7:
		$CenterContainer/Create/Password1Error.text = "At least 7 characters"
		password1_error = true
	else:
		password1_error = false


func _on_password_2_text_changed(new_text):
	if new_text.is_empty():
		$CenterContainer/Create/Password2Error.text = "Please retype your password"
		password2_error = true
	elif new_text != $CenterContainer/Create/Password1.text:
		$CenterContainer/Create/Password2Error.text = "The passwords do not match"
		password2_error = true
	else:
		password2_error = false


func _on_player_auth_resized():
	# position confetti in the bottom corners of the viewport
	$ConfettiL.position = Vector2(-100, 50 + get_viewport_rect().size.y)
	$ConfettiR.position = Vector2(100 + get_viewport_rect().size.x, 50 + get_viewport_rect().size.y)


func _on_go_to_login_pressed():
	$CenterContainer/Create.hide()
	$CenterContainer/Login.show()


func _on_timer_timeout():
	if InfraServer.peer.get_connection_status() == 0: # if we're disconnected, there's no point in polling the peer
		return

	InfraServer.peer.poll()

	if InfraServer.peer.get_available_packet_count() > 0:
		var reply = InfraServer.peer.get_var()
		if reply is Array: # a bool sometimes appeared here
			print("Reply: ", reply)
			if reply[0] == "create_account":
				print("Recieved reply to create account: ", reply)
				process_create_account_reply(reply[1])
				#var  = PlayerAccounts.create_player_account(reply[1]["username"], reply[1]["password_hash"], reply[1]["password_salt"])
			elif reply[0] == "user_login":
				print("Recieved reply to login a user: ", reply)
				if reply[1].is_empty():
					$CenterContainer/Login/Login.text = "USERNAME BAD"
					$CenterContainer/Login/UserName.editable = true
					$CenterContainer/Login/Password.editable = true
					$CenterContainer/Login/Login.disabled = false
				else:
					var request = [
						"user_auth",
						{
							"peer_id" : InfraServer.peer.get_unique_id(),
							"username_hash" : username.sha256_text(),
							# send back password hashed with the has we got from the server
							"password_hash" : hash_password(password, reply[1]),
						}
						]
					InfraServer.peer.put_var(request)
			elif reply[0] == "user_auth":
				print("Recieved reply for request to authenticate a user: ", reply)
				if reply[1][1] == ERR_UNAUTHORIZED:
					print("Login failed.")
					$CenterContainer/Login/Login.text = "PASSWORD BAD"
					$CenterContainer/Login/UserName.editable = true
					$CenterContainer/Login/Password.editable = true
					$CenterContainer/Login/Login.disabled = false
				else:
					print("Login successful.")
					$CenterContainer/Login/Login.text = "SUCCESS!"
					MultiplayerState.auth_tokens.append(reply[1])
					MultiplayerState.auth_username = username
					MultiplayerState.auth_enabled = true
					if $CenterContainer/Login/RememberMe.button_pressed:
						Settings.set_var('auth_username', username)
						Settings.set_var('auth_username_remember', true)
					else:
						Settings.set_var('auth_username', "")
						Settings.set_var('auth_username_remember', false)
					hide()
					$Timer.stop()
					auth_menu_closed.emit()

func _on_login_pressed():
	$CenterContainer/Login/UserName.editable = false
	$CenterContainer/Login/Password.editable = false
	$CenterContainer/Login/Login.disabled = true

	username = $CenterContainer/Login/UserName.text
	password = $CenterContainer/Login/Password.text

	assert(username.is_empty() == false, "Attempting login with an empty username!")

	var request = ["user_login",
	{
		"peer_id" : InfraServer.peer.get_unique_id(),
		"username_hash" : username.sha256_text(),
	}]
	InfraServer.peer.put_var(request)


func _on_why_pressed():
	$CenterContainer/AuthInfo.show()
	#$CenterContainer/LoginOrNot/WhyAccount.position = (get_viewport().size - $CenterContainer/LoginOrNot/WhyAccount.size) / 2
	#$CenterContainer/LoginOrNot/WhyAccount.show()


func _on_close_pressed():
	$CenterContainer/AuthInfo.hide()


func _on_anonymous_pressed():
	Settings.set_var(&'player_auth_use', false)
	if $CenterContainer/LoginOrNot/HBoxContainer2/DontAskAgain.button_pressed: # save the preference
		Settings.set_var(&'player_auth_use_remember', true)
	hide()
	MultiplayerState.auth_enabled = false
	$Timer.stop()
	auth_menu_closed.emit()
