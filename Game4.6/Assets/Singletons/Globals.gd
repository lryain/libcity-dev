extends Node
# Holds global constants, enums and refernces

# Liblast versioning

class LiblastVersionNumber:
	var major : int
	var minor : int
	var patch : int
	var hotfix : int # 0 means it's not a hotfix
	var type : ReleaseType

	func _init(major, minor, patch, hotfix, type):
		self.major = major
		self.minor = minor
		self.patch = patch
		self.hotfix = hotfix
		self.type = type

### Liblast Release Version - SET THIS BEFORE RELEASE!
var build_version = LiblastVersionNumber.new(0,1,10,0,ReleaseType.PRE_ALPHA)
var build_is_a_numbered_release : bool = false
###

enum ReleaseType {PRE_ALPHA, ALPHA, BETA, RELEASE_CANDIDATE, STABLE, TESTING}

enum Focus {MENU, GAME, CHAT, AWAY, CONSOLE}
enum MultiplayerRole {NONE, CLIENT, SERVER, DEDICATED_SERVER, INTERMEDIATE}

enum GameMode {CONTROL_POINTS, DUEL, CAMPAIGN, DEATHMATCH, TEAM_DEATHMATCH, KING_OF_THE_HILL, FRIDGE_STACKING}
enum MatchPhase {LOBBY, WARMUP, GAME}

enum CharCtrlType { # Character Control Type
	UNDEFINED, # not set yet
	MOVE_F, # move_forward
	MOVE_B, # move_backward
	MOVE_L, # move_left
	MOVE_R, # move_right
	MOVE_S, # move_special
	MOVE_J, # move_jump
	TRIG_P, # trigger_primary
	TRIG_S, # trigger_secondary
	WEPN_1, # weapon_1
	WEPN_2, # weapon_2
	WEPN_3, # weapon_3
	WEPN_L, # weapon_last
	WEPN_R, # weapon_reload
	WEPN_P, # weapon_previous
	WEPN_N, # weapon_next
	V_ZOOM, # view_zoom
}

#enum MaterialType { NONE,
#					CONCRETE,
#					METAL,
#					WOOD,
#					GLASS,
#					WATER,
#					}

#const NET_SERVER : String = "libla.st"
const NET_SERVER : String = "localhost"
const NET_PORT : int = 12597
const NET_PEER_LIMIT = 32

#const INFRA_SERVER : String = "localhost"
const INFRA_SERVER : String = "unfa.xyz"
const INFRA_PORT : int = 12599

const LOCAL_DISCOVERY_PORT : int = 12600

signal current_character_changed(new_character:CharacterBody3D, old_character: CharacterBody3D)
signal game_state_changed(new_game_state, old_game_state)
var game_state : GameState:
	set(value):
		if value == game_state:
			return
		# notify about the change
		# apply the change
		var old_game_state = game_state
		game_state = value
		game_state_changed.emit(game_state, old_game_state)


signal focus_changed(new: Focus, previous: Focus)

var focus: Focus = Focus.MENU:
	set(value):
#		prints("Focus changed to", value, "a.k.a", Focus.keys()[value])
		if value == self.focus:
			return

		focus_previous = focus
		focus = value
		focus_changed.emit(focus, focus_previous)

		# make mouse cursor captured while in game - leave it out for menu, console or game lobby
		if value in [Focus.MENU, Focus.CONSOLE] or \
		(value == Focus.GAME and game_state.current_match_phase != MatchPhase.GAME):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		var character_banner_status : Character.CharacterBannerStatus

		# only allow controlling the character in GAME focus
		# TODO - move this logic to the character?
		if multiplayer.has_multiplayer_peer():
			if MultiplayerState.local_character:
				if value == Focus.GAME:
					MultiplayerState.local_character.is_controllable = true
					character_banner_status = Character.CharacterBannerStatus.NONE
				else:
					MultiplayerState.local_character.is_controllable = false
					match focus:
						Globals.Focus.MENU:
							character_banner_status = Character.CharacterBannerStatus.MENU
						Globals.Focus.CHAT:
							character_banner_status = Character.CharacterBannerStatus.CHAT
						Globals.Focus.AWAY:
							character_banner_status = Character.CharacterBannerStatus.IDLE

				MultiplayerState.local_character.set_banner_status(character_banner_status)
				MultiplayerState.local_character.set_banner_status.rpc(character_banner_status)


var focus_previous: Focus = focus


# root for parenting in-game objects to so the ycan be disposed of easily
func get_spawn_root() -> Node:
	if game_state:
		return game_state.spawn_root
	else:
		return get_tree().root


# this is the character currently followed by the first person camera and HUD
# it's NOT the same as MultiplayerState's local_character, but usually current_character will point to local_character
var current_character: CharacterBody3D = null:
	set(value):
		if value == current_character:
#			print_debug("Attempting to set exisitng current_character; skipping")
			return

		var previous_character = current_character
		#									new ↓           ↓ old
		current_character = value
		current_character_changed.emit(current_character, previous_character)
#		print_debug("Changing current character from ", previous_character, " to ", value, " on peer ", MultiplayerState.peer.get_unique_id())

enum Teams {NONE, LIME, PLUM}

var team_colors = {
	Teams.NONE : Color.from_hsv(0,0,0.9),
	Teams.LIME : Color.html("cbfc10"), # lime
	Teams.PLUM : Color.html("a100ff"), # purple
}


func _ready() -> void:
	pass
	## This was meant to automatically update the game version so that builds would have
	## extra metadata in the executable, but it's annoying as it prompts user
	## to reload "project.godot" every time
	#if OS.has_feature("debug"):
		#ProjectSettings.set_setting("application/config/version", get_version_string(false, false))
		#ProjectSettings.save()
	#else:
		#pass


func get_version_string(bbcode = true, save = true) -> String: # compose a string based on liblast build number and Git repository metadata

	if Globals.build_is_a_numbered_release:
		var version_string = ("Liblast v. [b]%d.%d.%d%s %s[/b]" if bbcode else\
			"Liblast v. %d.%d.%d%s %s") % [
			Globals.build_version.major,
			Globals.build_version.minor,
			Globals.build_version.patch,
			("-" + str(Globals.build_version.hotfix) + " hotfix") if Globals.build_version.hotfix > 0 else "",
			str(Globals.ReleaseType.keys()[Globals.build_version.type]).to_lower().replace('_','-'),
		]
		print("Generate release version string:\n", version_string)
		return version_string

	else:
		# check if we are in a git repository and get the HEAD information
		var file = FileAccess.open("res://../.git/logs/HEAD", FileAccess.READ)
		if file:
	#		print("Git data folder found. Parsing...")
			var lines = []
			while not file.eof_reached():
				lines.append(file.get_csv_line(" "))

			var row = lines[lines.size() -2]

			var branch := "?"
			var file2 = FileAccess.open("res://../.git/HEAD", FileAccess.READ)

			if file2:
				branch = file2.get_csv_line("/")[2]

			var result = ("git branch [b]%s[/b] commit [b]%s[/b] %s UTC" if bbcode else\
			"git branch %s commit %s %s UTC") % [\
			branch,\
			row[1].left(10),\
			Time.get_datetime_string_from_unix_time(row[4].to_int(), true)\
			]

			if save:
				var file3 = FileAccess.open("res://version", FileAccess.WRITE)
				file3.store_line(result)
				file3.flush()

			return result
		else:
			var file4 = FileAccess.open("res://version", FileAccess.READ)
			if file4:
				return file4.get_as_text()
			else:
				return ""
