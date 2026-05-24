extends Panel

var drag_position = null

const SCALE_STEP = 0.1
var window_scale : float = 1.0:
	set(value):
		print("windows scale value: ", value)
		var norm = clamp(value, 0.1, 1.0)

		window_scale = norm

		scale = Vector2(window_scale,window_scale)
		$HBoxContainer2/ScaleLabel.text = str(window_scale * 100) + "%"

@onready var log : RichTextLabel = $HBoxContainer/Log
@onready var toggles = $HBoxContainer/VBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.SCALE_STEP


func section_color(section):
	var col = Color.from_hsv((section as float) / 5.5, 0.3, 1)
	log.append_text("[color=" + col.to_html() +"]")
#	return section + 1


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
#	var section := 0

	log.clear()

#	log.append_text("scale: " + str(scale))
#	log.newline()
#	log.append_text("window_scale: " + str(window_scale))
#	log.newline()

	if toggles.get_node("CurChars").button_pressed:
		section_color(1)
		log.append_text("cur. char.: " + str(Globals.current_character))
#		log.append_text("\t")
		log.newline()
		log.append_text("loc. char.: " + str(MultiplayerState.local_character))
		log.newline()
		log.append_text("loc. char. prof: " + str(MultiplayerState.user_character_profile))
		log.newline()


	if toggles.get_node("State").button_pressed:
		section_color(2)
		log.append_text("focus: " + str(Globals.Focus.keys()[Globals.focus]))
#		log.append_text("\t")
		log.newline()
		log.append_text("mult. state: " + str(Globals.MultiplayerRole.keys()[MultiplayerState.role]))
		log.newline()

		log.append_text("glob. game. state: " + str(Globals.game_state))
		log.newline()

	if toggles.get_node("Times").button_pressed:
		section_color(0)
		log.append_text("FPS: " + str(Engine.get_frames_per_second()))
		log.newline()
		log.append_text("proc. time: " + str(round(1000 * Performance.get_monitor(Performance.TIME_PROCESS))) + "ms")
		log.newline()
		log.append_text("phys. time: " + str(round(1000 * Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))) + "ms")
		log.newline()
#		log.newline()
#		log.append_text("fr. time: " + str(Engine.)

	if toggles.get_node("Performance").button_pressed:
		section_color(3)
#		log.append_text(Time.get_time_string_from_system())
#		log.append_text(var_to_str(Time.get_ticks_msec()))
#		log.append_text(var_to_str(Performance.get_monitor(Performance.TIME_FPS)))
#		log.append_text(var_to_str(Engine.max_fps))
		log.append_text("object cnt: " + str(Performance.get_monitor(Performance.OBJECT_COUNT)))
		log.newline()
		log.append_text("node cnt: " + str(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		log.newline()
		log.append_text("orphan node cnt: " + str(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
		log.newline()
		log.append_text("res. cnt: " + str(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
		log.newline()
		log.append_text("mem static: " + str(round(Performance.get_monitor(Performance.MEMORY_STATIC / (1024 * 1024)))) + "MB")
		log.newline()
		log.append_text("mem stat. max: " + str(round(Performance.get_monitor(Performance.MEMORY_STATIC_MAX / (1024 * 1024)))) + "MB")
		log.newline()
		log.append_text("phys3d active objs: " + str(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)))
		log.newline()
		log.append_text("phys3d col. pairs: " + str(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)))
		log.newline()
		log.append_text("phys3d islands: " + str(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)))
		log.newline()

	if toggles.get_node("Profiles").button_pressed:
		section_color(4)
		log.append_text("char profiles: ")
		log.newline()
		if Globals.game_state:
			if Globals.game_state.profiles_by_pid:
				for i in Globals.game_state.profiles_by_pid.keys():
					var pid = i
					var profile = Globals.game_state.profiles_by_pid[i]
					log.append_text("pid: " + str(pid) + " profile: " + str(profile))
					log.newline()

	if toggles.get_node("Discovery").button_pressed:
		section_color(5)
		log.append_text("peer discovery: ")
		log.newline()
		if LocalDiscovery.discovered_peers.size() > 0:
			for i in LocalDiscovery.discovered_peers:
				var role = LocalDiscovery.discovered_peers[i].role
				var time_to_live = LocalDiscovery.discovered_peers[i].expiration_time - Time.get_ticks_msec()
				log.append_text("IP: " + str(i) + " role: " + str(Globals.MultiplayerRole.keys()[role]) + " TTL: " + str(time_to_live))
				log.newline()

	if toggles.get_node("Movement").button_pressed:
		section_color(6)
		log.append_text("character movement: ")
		log.newline()
		if Globals.current_character:
			var velocity = Globals.current_character.velocity.length()
			var top_velocity = Globals.current_character.movement.character_top_velocity
			log.append_text("vel: " + str(velocity) + "\ntop vel: " + str(top_velocity))
			log.newline()
		else:
			print("no current character")


func _on_gui_input(event: InputEvent) -> void:
	# for dragging the window around
	if event is InputEventMouseButton:
		if event.pressed:
			# start dragging
			drag_position = event.global_position - global_position
		else:
			# end dragging
			drag_position = null

	if event is InputEventMouseMotion and drag_position:
		global_position = event.global_position - drag_position


func _on_print_toggle_toggled(button_pressed: bool) -> void:
	set_process(button_pressed)


func _on_smaller_pressed() -> void:
	window_scale -= SCALE_STEP


func _on_larger_pressed() -> void:
	window_scale += SCALE_STEP
