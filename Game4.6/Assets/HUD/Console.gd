extends Control

var logger: Node

@onready var editor = $VBoxContainer/Editor
@onready var history = $VBoxContainer/History

enum PromptStatus {UNKNOWN, INVALID, COMMAND, GET, SET}#, EXECUTED}

const CONSOLE_SIZE = 0.75 # vertical screen ratio

# Filled automatically on startup
var commands = []
# Each console command can take 1 argument that is a Variant.
# It can be an array though!
# To add a new console command usable by players, just create a method with name starting with
# `command_` and accepting one argument. Don't hesitate to add some help text while you're at it.

const colors = {
	PromptStatus.UNKNOWN : Color.GHOST_WHITE,
	PromptStatus.INVALID : Color.RED,
	PromptStatus.COMMAND : Color.MEDIUM_SPRING_GREEN,
	PromptStatus.GET : Color.PALE_GREEN,
	PromptStatus.SET : Color.DEEP_SKY_BLUE,
	#PromptStatus.EXECUTED : Color.DIM_GRAY,
}

#var previous_focus : Globals.Focus

var prompt_status: PromptStatus:
	set(value):
		prompt_status = value

		var prompt_color = colors[prompt_status]
		editor.set('theme_override_colors/font_color', prompt_color)

var prompt
var argument

var prompt_history = [""]
var prompt_history_index = 0

var previous_completion_prompt : String

var active := true:
	set(value):
		if active == value: # the value was changed to itself
			return

		active = value

		if Globals.current_character:
			Globals.current_character.is_controllable = ! active

		if active:
			editor.grab_focus()
		else:
			editor.release_focus()

### filesystem interface

#var fs_current_dir := "res://"
@onready var dir := DirAccess.open("res://")


func _ready() -> void:
	logger = get_node("/root/Logger")
	
	var methods = get_method_list().filter(func(x): return x.name.begins_with('command_'))
	commands = methods.map(func(x): return x.name.get_slice('_', 1))
#	print("Found console commands: ", commands)
	prompt_status = PromptStatus.UNKNOWN
	history.clear()

	var img : CompressedTexture2D = preload("res://Assets/Environments/Decoration/BannerLogo.png")
	history.append_text("[center] [/center]")
	history.add_image(img, 480, 0, Color.from_hsv(0,0,1,0.5), INLINE_ALIGNMENT_CENTER)
	history.newline()
	history.append_text("[font_size=12][center][b][img width=12]res://Assets/Badges/Textures/Badge_Auth.png[/img]   Welcome to Liblast!   \
	Visit [url=https://libla.st]libla.st[/url] for more information!   [img width=14]res://Assets/Badges/Textures/Badge_Auth.png[/img][/b][/center]")
	history.append_text("[font_size=9][center]Liblast version: " + Globals.get_version_string() + "[font_size=7]"+\
	"\nGodot Engine version: " + Engine.get_version_info()['string'] +\
	"\nOS: " + OS.get_name() + (("(" + OS.get_distribution_name() + ")") if OS.get_distribution_name() != OS.get_name() else "") +\
	(("\nDevice: " + OS.get_model_name()) if ['Android', 'iOS'].has(OS.get_name) else "") + \
	"\nOS version: " + OS.get_version() + \
	"\n UID: [b]%s[/b][font_size=5]%s" % [OS.get_unique_id().left(6), OS.get_unique_id().right(-6)])
	history.newline()
	## reset center alignment and restore default font size
	history.append_text("[left][font_size=%d]\n" % [get_theme_default_font_size()])
	command_help(null)
	active = false
	#anchor_bottom = 0


func _process(delta) -> void:
	if active:
		anchor_bottom = lerp(anchor_bottom, CONSOLE_SIZE, min(delta * 16, 1))
		anchor_top = anchor_bottom - CONSOLE_SIZE
	else:
		anchor_bottom = lerp(anchor_bottom, -0.01, min(delta * 16, 1))
		anchor_top = anchor_bottom - CONSOLE_SIZE


func toggle_console() -> void:
	# ensure the console is always drawn on top of everything else
#	var root = get_tree().root
#	var child_count = root.get_child_count()
#	root.move_child(self, child_count)

	if Input.is_action_just_pressed(&'console'):
		active = ! active
		get_tree().get_root().set_input_as_handled()
		if active:
#			previous_focus = Globals.focus
			Globals.focus = Globals.Focus.CONSOLE
		else:
			Globals.focus = Globals.focus_previous


func _input(event):
	if active:
		if Input.is_action_just_pressed("ui_text_completion_replace") and\
		not editor.text.is_empty() and\
		editor.text != previous_completion_prompt:
			previous_completion_prompt = editor.text
			var coms_and_vars = commands + Settings.settings.keys() + Settings.test_settings.keys()
			var matching_commands = (coms_and_vars).filter(func(text): return text.begins_with(editor.text))
			match matching_commands.size():
				0:
					history.newline()
					history.append_text("[i]No command found for [b]" + editor.text +
					"[/b]. Type [b]\'coms\'[/b] for the list of commands and [b]\'vars\'[/b] for the list of variables")
					prompt_status = PromptStatus.INVALID
				1:
					editor.text = matching_commands.front()
					validate_prompt(editor.text)
					editor.caret_column += editor.text.length()
				_:
					history.newline()
					history.append_text(var_to_str(matching_commands) +
					" were found for '" + editor.text + "', please specify[/i]")
					prompt_status = PromptStatus.UNKNOWN
		elif Input.is_action_just_pressed("ui_text_delete"):
			editor.text = ""
			prompt_status = PromptStatus.UNKNOWN
		elif Input.is_action_just_pressed("ui_up"):
			prompt_history_index = clampi(prompt_history_index + 1, 0, prompt_history.size() - 1)
#			print("Prompt history: ", prompt_history, " INDEX: ", prompt_history_index)
			editor.text = prompt_history[prompt_history_index]
			editor.caret_column = editor.text.length()
			validate_prompt(editor.text)
			get_viewport().set_input_as_handled()
		elif Input.is_action_just_pressed("ui_down"):
			prompt_history_index = clampi(prompt_history_index - 1, 0, prompt_history.size() - 1)
#			print("Prompt history: ", prompt_history, " INDEX: ", prompt_history_index)
			editor.text = prompt_history[prompt_history_index]
			editor.caret_column = editor.text.length()
			validate_prompt(editor.text)
			get_viewport().set_input_as_handled()


func _unhandled_input(_event) -> void:
	if not active:
		toggle_console()


func split_prompt(text:String) -> void:
	prompt = text.get_slice(' ', 0)
	var split = text.split(' ', false, 1)

	if split.size() == 2:
		argument = split[1]
	else:
		argument = null


func validate_prompt(text: String) -> void:
	# separate command and argument, rest is dropped
	split_prompt(text)

	# check if the prompt matches command
	if prompt in commands and has_method(StringName('command_' + prompt)):
		prompt_status = PromptStatus.COMMAND
	# check if we're trying to get a variable
	elif prompt in Settings.settings.keys() and argument == null:
		prompt_status = PromptStatus.GET
	# check if we're trying to set a variable
	elif prompt in Settings.settings.keys() and argument != null:
		prompt_status = PromptStatus.SET

	# check if we're trying to get a test variable
	elif prompt in Settings.test_settings.keys() and argument == null:
		prompt_status = PromptStatus.GET
	# check if we're trying to set a test variable
	elif prompt in Settings.test_settings.keys() and argument != null:
		prompt_status = PromptStatus.SET
	else:
		prompt_status = PromptStatus.UNKNOWN


func _on_editor_text_submitted(new_text: String) -> void:
	# Print the executed command along with/without arguments
	history.newline()
	history.append_text("[color=ffff00]]" + new_text + "[/color]\n")

	if prompt_status == PromptStatus.UNKNOWN:
		prompt_status = PromptStatus.INVALID

	if prompt_status == PromptStatus.INVALID:
		return

	if prompt_status == PromptStatus.COMMAND:
		logger.event(["console command: ", new_text])
		#history.append_text("[color=" + colors[PromptStatus.EXECUTED].to_html() + "]> " + prompt + (" " + argument) if len(argument) > 0 else '')
		call(StringName('command_' + prompt), argument)
#		prompt_history.append(prompt)

	elif prompt_status == PromptStatus.GET:
#		print(prompt)
#		print(Settings.get_var(prompt))
		history.newline()
		history.append_text("[color=" + colors[prompt_status].to_html() + "]> " + prompt + " is " + var_to_str(Settings.get_var(prompt)) + "[/color]")

	elif prompt_status == PromptStatus.SET:
		logger.event(["console var set: ", new_text])
		var err = Settings.set_var(prompt, str_to_var(argument))
		if err == OK:
			history.newline()
			history.append_text("[color=" + colors[prompt_status].to_html() + "]> " + prompt + " is now " + var_to_str(Settings.get_var(prompt)) + "[/color]")
		else:
			prompt_status = PromptStatus.INVALID
			return

	prompt_history.insert(1, editor.text) # always leave the 1st item as ""
	prompt_history_index = 0

	editor.text = ""
	prompt_status = PromptStatus.UNKNOWN


func _on_history_meta_clicked(meta) -> void:
	OS.shell_open(meta)


func _on_history_focus_entered() -> void:
	if active:
		editor.grab_focus()


func _on_history_mouse_exited() -> void:
	if active:
		editor.grab_focus()


func _on_editor_text_changed(new_text: String) -> void:
	if active:
		toggle_console()
		if not active:
			editor.text = editor.text.rstrip('`')
			editor.caret_column = editor.text.length()
	validate_prompt(new_text)
	get_tree().get_root().set_input_as_handled()


func _on_editor_focus_exited():
	# this prevents loosing focus when the console is active
	if active:
		editor.grab_focus()


const help_help =\
"WW8gZGF3ZywgSSBzZWUgeW91J2QgbGlrZSBzb21lIGhlbHAgd2l0aCB5b3VyIGhlbHAgc28gSSBw
cmludGVkIHRoaXMgaGVscCBmb3IgdGhlIGhlbHAgc28geW91IGNhbiBnZXQgaGVscCBhYm91dCBn
ZXR0aW5nIGhlbHAgd2hpbGUgZ2V0dGluZyBoZWxwIHVzaW5nIHRoaXMgaGVscGZ1bCBoZWxwIGNv
bW1hbmQuIFlvdSBqdXN0IHR5cGUgaXQgdG8gZ2V0IGhlbHAuIEhvcGUgdGhpcyBoZWxwcy4gV2Fp
dCwgeW91J3JlIGFscmVhZHkgdXNpbmcgaXQsIHNvIHdoeSBhcmUgeW91IGFza2luZyBmb3IgaGVs
cD8hIFlvdSdyZSBqdXN0IHdhc3Rpbmcgb3VyIHRpbWUgaGVyZSE="


func print_help(text: String):
	# print help with a special color to distinguish it from the rest
	var prefix = "[color=b0d0ff][i]"
	var suffix ="[/i][/color]"
	history.newline()
	history.newline()
	history.append_text(prefix + text + suffix)


func print_calc_info(errorMsg: String):
	history.append_text(errorMsg)
	print_help('''
		USE: [b]calc [num] [operator] [num][/b]
		Examples: 
			[b]calc 25 add 6[/b]
			[b]calc 25 + 6[/b]

			[b]calc 34 sub 12[/b]
			[b]calc 34 - 12[/b]

			[b]calc 203.32 mul 4.7[/b]
			[b]calc 203.32 * 4.7[/b]

			[b]calc 86 div 43[/b]
			[b]calc 86 / 43[/b]
			[b]calc 86 : 43[/b]

			[b]calc 66 mod 28[/b]
			[b]calc 66 % 28[/b]

			[b]calc 50 pow 22[/b]
			[b]calc 50 ** 22[/b]
		''')


########## COMMANDS ##########

func command_calc(argument) -> void:
	history.newline()

	if argument == null:
		print_calc_info("[color=b800e1]Calculator :P[/color]")
		return
	else:
		var args = argument.split(" ")

		if args.size() < 3 or argument == null:
			print_calc_info("[color=ff0000]ERROR: [/color]Insufficient number of arguments")
			return
		else:
			var p1 = float(args[0].strip_edges())
			var op = args[1].strip_edges()
			var p2 = float(args[2].strip_edges())
			var resultTxt = "[color=b800e1]Result: [/color]"

			# Perform the calculation based on the operator
			match op:
				"add", "+": history.append_text(resultTxt + str(p1 + p2))
				"sub", "-": history.append_text(resultTxt + str(p1 - p2))
				"mul", "*": history.append_text(resultTxt + str(p1 * p2))
				"div", "/", ":": history.append_text(resultTxt + str(p1 / p2))
				"mod", "%": history.append_text(resultTxt + str(fmod(p1, p2)))
				"pow", "**": history.append_text(resultTxt + str(p1 ** p2))
				_: print_calc_info("[color=ff0000]ERROR: [/color]The 2nd argument isn't an operator!")


func command_cd(argument) -> void:
	history.newline()
	var err = dir.change_dir(argument)
	if err != OK:
		history.append_text("[color=ff0000]ERROR: " + error_string(err) + "[/color]\n")
#	else:
#		history.append_text("")


func command_chars(_argument) -> void:
	var char_names = []
	for i in get_tree().get_nodes_in_group(&'Characters'):
		char_names.append(i.profile.display_name)

	history.newline()
	history.newline()
	history.append_text(var_to_str(char_names))
#	history.append_text("Not implemented yet. Will print out the list of all characters present in the current game (if any)")


func command_clear(_argument) -> void:
	history.clear()


func command_coms(_argument) -> void:
	history.newline()
	history.newline()
	history.append_text("Available [b]commands[/b]:")
	history.newline()
	history.append_text(var_to_str(commands))


func command_debug(argument) -> void:
	match argument:
		"add":
			var panel = load("res://Assets/UI/DebugPanel.tscn").instantiate()
			get_tree().root.call_deferred(&"add_child", panel)
			history.newline()
			history.append_text("Debug Panel instantiated")
		"clear":
			# destroy all debug panels that were spawned
			for i in get_tree().get_nodes_in_group("DebugPanels"):
				i.queue_free()
			history.newline()
			history.append_text("All Debug Panels freed")
		"hide":
			# destroy all debug panels that were spawned
			for i in get_tree().get_nodes_in_group("DebugPanels"):
				i.hide()
			history.newline()
			history.append_text("Debug Panels hidden")
		"show":
			# destroy all debug panels that were spawned
			for i in get_tree().get_nodes_in_group("DebugPanels"):
				i.show()
			history.newline()
			history.append_text("Debug Panels shown")
		_:
			command_help("debug")


func command_god(_argument) -> void:
	history.newline()
	history.append_text("Nice try. Godmode isn't implemented yet.")


func command_help(argument) -> void:


	if argument == null:
		print_help(
'''[b]--- Liblast Console Help ---[/b]

[b]- Key bindings:[/b]

	[b]TILDA[/b] toggles the console
	[b]DELETE[/b] clears the current prompt
	[b]TAB[/b] auto-completes the current prompt or list possible completions
	[b]UP/DOWN[/b] cycles through prompt history

	All standard keyboard shortcuts work as well.

[b]- Basic commands[/b]

	To view this help text, type [b]\'help\'[/b]
	To list available commands, type [b]\'coms\'[/b]
	To list available variables, type [b]\'vars\'[/b]

	To get help for a given command, type [b]\'help\'[/b] followed by the command

	To read a variable, type it\'s name
	To set a variable, type it\'s name followed by the new value
''')
	elif not commands.has(argument):
		var arg = '[b]' + argument + '[/b]'
		print_help('sorry - ' + arg + ' is not a valid command')
	else:
		var arg = '[b]' + argument + '[/b]'
		match argument:
			'calc' : print_help(arg + ' calculates two values')
			'cd' : print_help(arg + ' changes working directory')
			'clear' : print_help(arg + ' removes all text from the console')
			'coms' : print_help(arg + ' prints the list of available commands')
			'debug' : print_help(arg + ''' provides various debugging features. The command expects an argument. Valid argments are:
[b]add[/b] - spawns a debug panel
[b]clear[/b] - removes all spawned debug panels
[b]hide[/b] - make all debug panels invisible
[b]show[/b] - makes all hidden debug panels visible
''')
			'help' : print_help(Marshalls.base64_to_utf8(help_help))
			'history' : print_help(arg + ' prints current console prompt history')
			'host' : print_help(arg + ' starts a game on a selected map')
			'join' : print_help(arg + ' joins a game hosted at selected address')
			'kill' : print_help(arg + ' terminates player\'s character. Use [b]kill more[/b] for extra fun')
			'killall' : print_help(arg + ' terminates all characters. Use [b]kill more[/b] for extra fun')
			'ls' : print_help(arg + ' lists working directory contents')
			'pwd' : print_help(arg + ' prints working directory')
			'quit' : print_help(arg + ' closes the game')
			'restart' : print_help(arg + ' closes the game and starts it again in a new process')
			'timescale' : print_help(arg + ' alters the speed of the game')
			'vars' : print_help(arg + ' prints the list of available variables')
			'version' : print_help(arg + ' prints Liblast version information')
			_ : print_help('sorry - there\'s no help text for ' + arg + ' command')


func command_history(_argument) -> void:
	history.newline()
	history.newline()
	history.append_text('Console prompt [b]history[/b]: ')
	history.newline()
	# omit the empty entries
	history.append_text(var_to_str(prompt_history.filter(func(text): return ! text.is_empty())))


func command_host(argument) -> void:
	history.newline()
	history.append_text("Not implemented yet. Will host a local game on specified map")
	#history.append_text("Starting a local game on map", argument, "...")
	#var game_config = GameConfig.new()
	#game_config.map = argument
	#MultiplayerState.game_config = game_config
	#
	#var err = MultiplayerState.start_server()
	#
	#if err != OK:
		#history.append_text("Failure: ", error_string(err))


func command_join(argument) -> void:
	history.newline()
	history.append_text("Not implemented yet. Will atempt to join a game server under specified address")


func command_kill(argument) -> void:
	history.newline()
	if Globals.current_character:

		var damage
		if argument == "more":
			history.append_text("Terminating player... with [b]extreme prejudice.[/b]")
			damage = Damage.new()
			damage.damage_amount = 10000
#			damage.source_position = Globals.current_character.global_position
#			damage.attacker = Globals.current_character
#			damage.attacker_pid = MultiplayerState.peer.get_unique_id()
			Globals.current_character.hurt(damage)
		else:
			history.append_text("Terminating player... you ok there?")
			damage = Damage.new()

		Globals.current_character.hurt.rpc(inst_to_dict(damage))
		Globals.current_character.die.rpc(inst_to_dict(damage))
		Globals.current_character.hurt(damage)
		Globals.current_character.die(damage)


func command_killall(argument) -> void:
	history.newline()
	var damage
	if argument == "more":
		history.append_text("Terminating everyone... with [b]extreme prejudice.[/b]")
		damage = Damage.new()
		damage.damage_amount = 10000
#		damage.attacker = Globals.current_character
	else:
		history.append_text("Terminating everyone... I hope you're happy.")
		damage = Damage.new()

	for i in get_tree().get_nodes_in_group(&'Characters'):
#		damage.source_position = i.global_position
#		damage.attacker = i
#		damage.attacker_pid = str(i.name)
		i.hurt.rpc(inst_to_dict(damage))
		i.die.rpc(inst_to_dict(damage))
		i.hurt(damage)
		i.die(damage)


func command_ls(_argument) -> void:
	history.newline()
#	history.append_text("[b]Current directory contents:[/b]\n")
	history.append_text("[color=aaaaff]")
	for i in dir.get_directories():
		history.append_text(i + "/\n")
#	history.newline()
	history.append_text("[color=aaffaa]")
	for i in dir.get_files():
		history.append_text(i + "\n")

	history.append_text("[color=ffffff]")


func command_map(argument) -> void:
	history.newline()
	history.append_text("Not implemented yet. Will load the specified map and start a local game")


func command_maps(_argument) -> void:
	history.newline()
	history.append_text("Not implemented yet. Will print out the list of available maps")


func command_noclip(_argument) -> void:
	history.newline()
	history.append_text("Sorry. Noclip isn't implemented yet.")


func command_pwd(_argument) -> void:
	history.newline()
#	history.append_text("[b]Current directory path:[/b]\n")
	history.append_text(dir.get_current_dir())
#	history.append_text("[/color]\n")


func command_quit(_argument) -> void:
	history.newline()
	history.append_text("Exiting Liblast...")
	get_tree().quit()


func command_restart(_argument) -> void:
	history.newline()
	history.append_text("Restarting Liblast...")
	OS.create_instance(OS.get_cmdline_args())
	get_tree().quit()


func command_spectate(argument) -> void:
	history.newline()
	history.append_text("Not implemented yet. Will change the currently viewed character in game, allowing to spectate other players")


func command_timescale(argument) -> void:
	history.newline()
	if argument == null:
		history.append_text("Time scale is curently " + str(Engine.time_scale))
	elif str(argument).is_valid_float():
		history.append_text("Setting time scale to " + str(argument))
		Engine.time_scale = argument.to_float()
	else:
		history.append_text("Can't set time scale to " + str(argument))


func command_vars(_argument) -> void:
	history.newline()
	history.newline()
	history.append_text("Available [b]variables[/b]:")
	history.newline()
	history.append_text(var_to_str(Settings.settings.keys()))


func command_version(argument) -> void:
	history.append_text(Globals.get_version_string(true, false))
