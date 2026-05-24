extends Control

const AVATAR_SIZE : int = round(pow(2, 9)) # 512

@onready var store_online = $CenterContainer/HBoxContainer2/VBoxContainer/HBoxContainer/StoreOnline
@onready var claim_name = $CenterContainer/HBoxContainer2/VBoxContainer/ProfileContainer/DisplayNameContainer/ClaimName
@onready var display_name = $CenterContainer/HBoxContainer2/VBoxContainer/ProfileContainer/DisplayNameContainer/DisplayName
@onready var display_color = $CenterContainer/HBoxContainer2/VBoxContainer/ProfileContainer/ColorContainer/ColorPickerButton
@onready var save = $CenterContainer/HBoxContainer2/VBoxContainer/HBoxContainer/Save
@onready var revert = $CenterContainer/HBoxContainer2/VBoxContainer/HBoxContainer/Revert
@onready var avatar_preview = $CenterContainer/HBoxContainer2/VBoxContainer/ProfileContainer/Avatar/AvatarPreview
@onready var avatar_file_dialog = $CenterContainer/HBoxContainer2/VBoxContainer/ProfileContainer/Avatar/SelectAvatar/FileDialog

@onready var preview_camera : Camera3D = %SubViewportContainer/SubViewport/CharacterProfilePreview/Camera
@onready var preview_character : Character = %SubViewportContainer/SubViewport/CharacterProfilePreview/Marker3d/Character
@onready var preview_subviewport : SubViewport = %SubViewportContainer/SubViewport

var something_changed := false:
	set(value):
		something_changed = value
		save.disabled = not value
		revert.disabled = not value

var avatar_changed := false
var avatar_awaiting_reply := false
var display_name_changed := false
var display_color_changed := false
#var display_color_changed := false


var avatar_data : PackedByteArray
var avatar_hash : PackedByteArray


var local_profile_path = "user://settings/user_profile.liblast"


func auth_changed(enabled) -> void:
	if enabled:
		claim_name.disabled = false
		claim_name.button_pressed = true

		store_online.disabled = false
		store_online.button_pressed = true

#		# default to username
#		display_name.text = MultiplayerState.auth_username
#		display_color.color = Color.from_hsv(randf_range(0, 1), randf_range(0.25, 1), randf_range(0.25, 1))

		# ensure only auth badge is set
		if not MultiplayerState.user_character_profile.badges.has(Badges.Badge.AUTH):
			MultiplayerState.user_character_profile.badges.append(Badges.Badge.AUTH)

		if MultiplayerState.user_character_profile.badges.has(Badges.Badge.NO_AUTH):
			MultiplayerState.user_character_profile.badges.erase(Badges.Badge.NO_AUTH)

	else:
		claim_name.disabled = true
		claim_name.button_pressed = false

		store_online.disabled = true
		store_online.button_pressed = false

		# ensure only no auth badge is set
		if not MultiplayerState.user_character_profile.badges.has(Badges.Badge.NO_AUTH):
			MultiplayerState.user_character_profile.badges.append(Badges.Badge.NO_AUTH)

		if MultiplayerState.user_character_profile.badges.has(Badges.Badge.AUTH):
			MultiplayerState.user_character_profile.badges.erase(Badges.Badge.AUTH)

		# use a special placeholder avatar when auth is disabled
		avatar_preview.texture = load("res://Assets/Characters/Avatars/DefaultAvatarPirate.png")

	apply_preview_profile()


func infra_online() -> void:
	if MultiplayerState.auth_enabled:
		claim_name.disabled = false
		store_online.disabled = false


func infra_offline() -> void:
	claim_name.disabled = false
	store_online.disabled = false


func _ready() -> void:
	MultiplayerState.auth_changed.connect(auth_changed)
#	InfraServer.peer.connection_failed.connect(infra_offline)
#	InfraServer.peer.connection_succeeded.connect(infra_online)
#	InfraServer.peer.server_disconnected.connect(infra_offline)

	load_local_profile()

	preview_camera.make_current()
	#preview_subviewport.size *= 3.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta) -> void:
	pass


func randomize_profile(name:= true, color := true, voice_pitch := true) -> void:
	if name:
		display_name.text = NameGenerator.generate()
		_on_display_name_text_changed(display_name.text)
	if color:
		display_color.color = Color.from_hsv(randf(), randf(), randf())
		_on_color_picker_button_color_changed(display_color.color)
#		Color.get_named_color_name()
	if voice_pitch:
		%VoicePitchSlider.value = randf_range(0.5, 1.5)

func apply_preview_profile() -> void:
	preview_character.profile = MultiplayerState.user_character_profile
	preview_character.apply_profile()
	#user_profile_previous = MultiplayerState.user_character_profile
	#something_changed = false


func _on_select_avatar_pressed() -> void:
	avatar_file_dialog.show()


func _on_file_dialog_file_selected(path) -> void:
	var avatar = Image.load_from_file(path)
	var avatar_size = avatar.get_size()
#	prints("Source image dimensions:", avatar_size)
	if avatar_size.aspect() == 1: # is the image square?
		pass
#		print("The image is square")
	else:
#		print("Cropping non-square image")
		if avatar_size.x < avatar_size.y:
			avatar.crop(avatar_size.x, avatar_size.x)
		else:
			avatar.crop(avatar_size.y, avatar_size.y)

	# by this point the avatar has to be square

	if avatar.get_width() == AVATAR_SIZE: # is it of perfect size?
		pass
#		print("The image is of perfect size")
	elif avatar.get_width() > AVATAR_SIZE: # is to too big?
#		print("Shrinking the image")
		avatar.resize(AVATAR_SIZE, AVATAR_SIZE, Image.INTERPOLATE_LANCZOS)
	elif avatar.get_width() < AVATAR_SIZE:
#		print("Image is too small!")
		pass

#	print("Displaying avatar preview")

	var avatar_texture = ImageTexture.create_from_image(avatar)
	avatar_preview.texture = avatar_texture
#	print($Avatar/Panel/AvatarPreview.texture)

#	print("Saving the processed avatar")

	avatar_data = avatar.save_webp_to_buffer()
	avatar_hash = Storage.hash_data(avatar_data)

	avatar_changed = true
	something_changed = true

	#avatar.save_webp("user://avatar.webp", true)


func set_avatar_from_data() -> void:
	var avatar = Image.new()
	avatar.load_webp_from_buffer(avatar_data)

	var avatar_texture := ImageTexture.create_from_image(avatar)

	if avatar_texture == null:
#		print_debug("The avatar image data produced a null texture")
		return

#	prints("Avatar texture:", var_to_str(avatar_texture))

	avatar_preview.texture = avatar_texture


func upload_avatar() -> void:
	var request = [
	"user_update_avatar",
	{
		"peer_id" = InfraServer.peer.get_unique_id(),
		"username_hash" = MultiplayerState.auth_username.sha256_text(),
		"token" = MultiplayerState.auth_tokens[0],
	},
	{
		"data" = avatar_data,
		"hash" = avatar_hash,
	},
	]

	var err = InfraServer.peer.put_var(request)

	avatar_awaiting_reply = true

#	if err == OK:
#		prints("Avatar update request sent.")
#	else:
#		print("Error sending avatar update request:",err)


func request_avatar() -> void:
#	prints("Requesting avatar hash:", avatar_hash)

	var request = [
		"retrieve_data",
		{
			"peer_id" = InfraServer.peer.get_unique_id(),
			"username_hash" = MultiplayerState.auth_username.sha256_text(),
			"hash" = avatar_hash
		},
	]
	avatar_awaiting_reply = true
	InfraServer.peer.put_var(request)


func _on_save_pressed() -> void:
	if store_online.button_pressed: # store remotely?
		if avatar_changed:
			upload_avatar()

	if avatar_changed:
			var err = Storage.store(avatar_hash, avatar_data, MultiplayerState.auth_username.sha256_text())
#			prints("Storing avatar data locally, result:", error_string(err))


	save_local_profile()

	display_name_changed = false
	display_color_changed = false
	something_changed = false


func _on_display_name_text_changed(new_text) -> void:
	display_name_changed = true
	something_changed = true
	MultiplayerState.user_character_profile.display_name = new_text
	apply_preview_profile()


func _on_color_picker_button_color_changed(color) -> void:
	display_color_changed = true
	something_changed = true
	MultiplayerState.user_character_profile.display_color = color
	apply_preview_profile()

func save_local_profile() -> void:
	var file = FileAccess.open(local_profile_path, FileAccess.WRITE)

	if file == null:
#		print_debug("Cannot open file for writing")
		return

	var buf = {
		"display_name" = MultiplayerState.user_character_profile.display_name,
		"display_color" = MultiplayerState.user_character_profile.display_color,
		"avatar_hash" = MultiplayerState.user_character_profile.avatar_hash,
		"badges" = [Badges.Badge.PRE_ALPHA],
		"voice_pitch" = %VoicePitchSlider.value,
		"fov" = Settings.get_var("render_fov"),
		}
	file.store_string(var_to_str(buf))

	var err = file.get_error()
	if err != OK:
		prints("Can't save local user profile. Error:", error_string(err))


func load_local_profile() -> void:
	var file = FileAccess.open(local_profile_path, FileAccess.READ)

	if not file:
#		prints("No local user profile stored. Randomizing.")
		randomize_profile()
		save_local_profile()
	else:
		var buf = str_to_var(file.get_as_text())
		var err = file.get_error()
		if err == OK and buf != null:
			display_name.text = buf["display_name"]
			MultiplayerState.user_character_profile.display_name = buf["display_name"]

			display_color.color = buf["display_color"]
			MultiplayerState.user_character_profile.display_color = buf["display_color"]

			avatar_hash = buf["avatar_hash"]
			MultiplayerState.user_character_profile.avatar_hash = buf["avatar_hash"]

			%VoicePitchSlider.value = buf["voice_pitch"]
			MultiplayerState.user_character_profile.voice_pitch = %VoicePitchSlider.value

			if buf.keys().has("fov"):
				MultiplayerState.user_character_profile.fov = buf["fov"]
		else:
#			prints("Local user profile loading failed. Randomizing.")
			randomize_profile()
			save_local_profile()

	apply_preview_profile()


	something_changed = false
	display_name_changed = false
	display_color_changed = false

func _on_user_profile_visibility_changed() -> void:
	if visible:
		$Timer.start()

		if avatar_data.is_empty() and not avatar_hash.is_empty(): # gotta load the avatar!
			request_avatar()

	else:
		$Timer.stop()


func _on_timer_timeout() -> void:
	return # FIXME InfraServer needs a rewrite
	InfraServer.peer.poll()

	if InfraServer.peer.get_available_packet_count() > 0:
		var reply = InfraServer.peer.get_var()

		if reply[0] == "user_update_avatar" and avatar_awaiting_reply:
			if reply[1] == OK:
#				print("Avatar change successful!")
				avatar_awaiting_reply = false
				avatar_changed = false
			elif reply[1] == ERR_INVALID_DATA:
#				print("Avatar data got corrupted, resending...")
				upload_avatar()
			elif reply[1] == ERR_ALREADY_EXISTS:
#				print("Uploaded avatar already exists on the server!")
				avatar_awaiting_reply = false
				avatar_changed = false
			else:
#				prints("Error changing avatar:", error_string(reply[1]))
				avatar_awaiting_reply = false
		elif reply[0] == "retrieve_data" and avatar_data.is_empty() and avatar_awaiting_reply:
			if reply[1].has("data"):
				var data = reply[1]["data"]
				#var recieved_hash = reply[1]["hash"]
				var computed_hash = Storage.hash_data(data)
				if avatar_hash != computed_hash:
#					print("Avatar data integrity check FAILED. Re-sending request")
					request_avatar()
				else:
					avatar_data = data
#					print("Avatar downloaded succesfully")
					avatar_awaiting_reply = false
					# cache retrived data locally for later
					Storage.store(avatar_hash, data, MultiplayerState.auth_username.sha256_text())
					set_avatar_from_data()
#			elif reply[1].has("error"):
#				prints("Error downlaoding avatar:", error_string(reply[1]["error"]))


func _on_sub_viewport_size_changed() -> void:
	pass
#	print("Character Profile Preview viewport size: ", preview_subviewport.size)
#	preview_subviewport.size *= 2
#	pass


func _on_randomize_pressed() -> void:
	randomize_profile(true, false, false)


func _on_randomize_2_pressed() -> void:
	randomize_profile(false, true, false)


func _on_revert_pressed() -> void:
	load_local_profile()


func _on_voice_pitch_slider_value_changed(value: float) -> void:
	%VoicePitchLabel.text = str(value)
	MultiplayerState.user_character_profile.voice_pitch = value


	preview_character.profile = MultiplayerState.user_character_profile
	apply_preview_profile()
	preview_character.say_random_taunt(preview_character.voice.spawn)

func _on_resized() -> void:
	pass
#	var scaling_factor : float = get_tree().root.size.x as float / get_tree().root.content_scale_size.x as float
#	print("Viewport scaling factor", scaling_factor)
#	if preview_subviewport:
#		preview_subviewport.size = Vector2i(1000, 1000)
