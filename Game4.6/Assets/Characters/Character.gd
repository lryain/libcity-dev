class_name Character
extends CharacterBody3D

# used to update HUD if the character is being currently controlled or spectated
signal character_hud_update(update: CharHudUpdate)

signal character_died

enum CharacterBannerStatus { NONE = -1, CHAT, MENU, IDLE, LAG, ZOOM, SAME_TEAM }
enum CharacterFaceExpression { NEUTRAL, ATTACK, HURT, DEAD, KILL, LOOSE, WIN, WINK }

enum CharacterCurrentCamera {FIRST_PERSON, THIRD_PERSON, DEATH}

# managing collisions
@onready var collision_layer_alive = collision_layer
@onready var collision_layer_dead = 0 # nothing 1024 # dead bodies only
@onready var collision_layer_gibbed = 0 # gibbed bodies only (nothing)
@onready var collision_mask_alive = collision_mask
@onready var collision_mask_dead = 0 # nothing collision_mask_alive #1 && 2 && 8 && 1024

# use ugly workaround?
var stubborn_body_team_shader_parameter : bool = true

# dictionary of sources of rumble camera shake
var rumble_sources = {}

var face_expression_tween : Tween
# monitor if this character's face is currently visible on screen
var face_on_screen = false

# monitor how long the face has been viewed
var face_screen_time : float = 0

# wink only once per game
var winked = false

var is_gibbed : bool = false

var check_cameras = true

var check_network_connection_tween : Tween

var network_ping_threshold = 500 # 500 miliseconds
var network_ping_threshold_hysteresis = 200

# resource containg information about how the player character should look
@export var profile : CharacterProfile:
	set(value):
		if not self.is_inside_tree():
#			print("Can't apply profile while outside of tree")
			return
		if profile == value:
			return
		else:
			profile = value

		if profile is CharacterProfile:
			apply_profile()
		elif profile == null:
			printerr("Can't apply null profile!")

# object containing current state of the character that needs to be updated between peers
# this should be initialized by the GameState spawner, if not - character will get a stub
@onready var state : CharacterState

@export var controller_scene: PackedScene
var controller : CharController # provides control input

@export var loadout : Resource

var weapons := CharWeapons.new()

var movement := CharMovementType1.new() # processes movement inputs

@export var movement_velocity : Vector3#: # used to sync velocity between peers

const ZOOM_SPEED := 3.0
const ZOOM_FACTOR := 4.0
const DEFAULT_FOV := 90.0
const ZOOM_VELOCITY_RATE := 32.0
var zoom_amount := 0.0
var zoom_velocity := 0.0
var zoom_amount_previous := zoom_amount

var outline_thickness_factor : float = 1.0
var outline_thickness_tween : Tween

const IDLE_TIME_THRESHOLD := 10
var banner_status_before_idle : CharacterBannerStatus
var banner_status_before_lag : CharacterBannerStatus
var banner_ray_previously : bool = false # used for banner camera raycast check
var idle_time : float # seconds since last controller input

# used for reset after respawn
@onready var base_body_position : Vector3 = $Body.position

@export var jetpack_active: bool:
	set(value):
		# ignore duplicated requests
		if value == jetpack_active:
			return

		jetpack_active = value
#		prints("Changing jetpack to", value)

		if not is_instance_valid(jetpack):
			return

		var sound = jetpack.get_node("Sound")
		if value:
			sound.play(randf_range(0, sound.stream.get_length()))
		else:
			sound.stop()

		var light = jetpack.get_node("Light")
		light.visible = jetpack_active

		var trail = jetpack.get_node("Jet")
		trail.visible = jetpack_active

		var smoke = jetpack.get_node("Smoke")
		smoke.emitting = jetpack_active

#		var particle_forcefield = $Body/GpuParticlesAttractorSphere3d
#		if particle_forcefield:
#			particle_forcefield.visible = ! value

		var particle_collider = $Body/GpuParticlesCollisionSphere3d
		if particle_collider:
			particle_collider.visible = ! value


# store these values as reference for distance- and fov-based correction
@onready var banner_base_visibility_range_end : float
@onready var banner_base_visibility_range_end_margin : float

@export var voice: Resource # handles voice for various character events
#var sounds: CharSounds # handles SFX for various character events

@export_node_path var head_path: NodePath
@onready var head: Node3D = self.get_node(head_path)

@export_node_path var mouth_path: NodePath
@onready var mouth: Node3D = self.get_node(mouth_path)

@export_node_path var camera_path: NodePath
@onready var camera: Camera3D = self.get_node(camera_path)

@export_node_path var camera_3rd_person_path: NodePath
@onready var camera_3rd_person: Camera3D = self.get_node(camera_3rd_person_path)

@export_node_path var camera_death_path: NodePath
@onready var camera_death: Camera3D = self.get_node(camera_death_path)

@export_node_path var camera_death_pivot_path: NodePath
@onready var camera_death_pivot: Node3D = self.get_node(camera_death_pivot_path)

@export_node_path var camera_shake_jetpack_path: NodePath
@onready var camera_shake_jetpack: Node = self.get_node(camera_shake_jetpack_path)

@export_node_path var camera_shake_damage_path: NodePath
@onready var camera_shake_damage: Node = self.get_node(camera_shake_damage_path)

@export_node_path var camera_shake_rumble_path: NodePath
@onready var camera_shake_rumble: Node = self.get_node(camera_shake_rumble_path)

@export_node_path var wind_fx_path: NodePath
@onready var wind_fx : AudioStreamPlayer = self.get_node(wind_fx_path)

@export_node_path var hands_path: NodePath
@onready var hands: Node3D = self.get_node(hands_path)

@export_node_path var feet_path: NodePath
@onready var feet: Node3D = self.get_node(feet_path)

@export_node_path var models_path: NodePath
@onready var models: Node3D = self.get_node(models_path)

@export_node_path var jetpack_path: NodePath
@onready var jetpack: Node3D = self.get_node(jetpack_path)

@export_node_path var jetpack_physical_bone_path: NodePath
@onready var jetpack_physical_bone: PhysicalBone3D = self.get_node(jetpack_physical_bone_path)

@export_node_path var skeleton_path: NodePath
@onready var skeleton: Skeleton3D = self.get_node(skeleton_path)

@export_node_path var models3rdPerson_path: NodePath
@onready var models3rdPerson: Node3D = self.get_node(models3rdPerson_path)

@export var body_mesh_3rdPerson : MeshInstance3D

@export_node_path var body_mesh_path: NodePath
@onready var body_mesh: MeshInstance3D = self.get_node(body_mesh_path)

@export_node_path var hands_mesh_path: NodePath
@onready var hands_mesh: MeshInstance3D = self.get_node(hands_mesh_path)

@export_node_path var face_mesh_path: NodePath
@onready var face_mesh: MeshInstance3D = self.get_node(face_mesh_path)

@export_node_path var face_light_path: NodePath
@onready var face_light: OmniLight3D = self.get_node(face_light_path)

@export_node_path var face_light_1st_person_path: NodePath
@onready var face_light_1st_person: OmniLight3D = self.get_node(face_light_1st_person_path)

@export_node_path var wind_streaks_path: NodePath
@onready var wind_streaks: Node3D = self.get_node(wind_streaks_path)

@export_node_path var banner_path: NodePath
@onready var banner: Node3D = self.get_node(banner_path)

@onready var banner_status : Sprite3D = banner.get_node("Status")
@onready var banner_status_tween := create_tween()
@onready var banner_status_scale := 1.0
@onready var banner_status_visibility_range := 1.0

@onready var aim_bone : int = skeleton.find_bone("DEF-spine.002")
@onready var aim_bone_rotation : Quaternion = skeleton.get_bone_pose_rotation(aim_bone)

# binary controls
var controls = {
	Globals.CharCtrlType.MOVE_F: CharCtrl.new(),
	Globals.CharCtrlType.MOVE_B: CharCtrl.new(),
	Globals.CharCtrlType.MOVE_L: CharCtrl.new(),
	Globals.CharCtrlType.MOVE_R: CharCtrl.new(),
	Globals.CharCtrlType.MOVE_S: CharCtrl.new(),
	Globals.CharCtrlType.MOVE_J: CharCtrl.new(),
	Globals.CharCtrlType.TRIG_P: CharCtrl.new(),
	Globals.CharCtrlType.TRIG_S: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_1: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_2: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_3: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_L: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_R: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_P: CharCtrl.new(),
	Globals.CharCtrlType.WEPN_N: CharCtrl.new(),
	Globals.CharCtrlType.V_ZOOM: CharCtrl.new(),
}


@export var max_health: int = 100

# used by console, chat and menu to make sure inputs ar not processed
var is_controllable: bool = false # previously "input_active"
var is_mobile: bool = false
var is_armed: bool = true # can the character use their weapons?

@onready var game_state : GameState = Globals.game_state# reference to the current game state

var killer : Character # reference to the charater that killed us mostly recently (if any)

@onready var cameras = {
	CharacterCurrentCamera.FIRST_PERSON : get_node(camera_path),
	CharacterCurrentCamera.THIRD_PERSON : get_node(camera_3rd_person_path),
	CharacterCurrentCamera.DEATH : get_node(camera_death_path),
}

@onready var current_camera : CharacterCurrentCamera = CharacterCurrentCamera.FIRST_PERSON:
	set(value):
		current_camera = value
		update_camera()


func check_network_connection():
	if MultiplayerState.role == Globals.MultiplayerRole.CLIENT:
		var own_peer = MultiplayerState.peer.get_peer(get_multiplayer_authority())
		if own_peer:
			var ping = own_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		#	var packet_loss = own_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)
			if ping > network_ping_threshold + network_ping_threshold_hysteresis / 2.0\
			and get_banner_status() != CharacterBannerStatus.LAG:
				print("Lag banner: SHOW for ", name)
				banner_status_before_lag = get_banner_status()

				set_banner_status(CharacterBannerStatus.LAG)
			elif ping < network_ping_threshold - network_ping_threshold_hysteresis / 2.0\
			and get_banner_status() == CharacterBannerStatus.LAG:
				print("Lag banner: HIDE for ", name)
				if banner_status_before_lag:
					set_banner_status(banner_status_before_lag)
				else:
					set_banner_status(CharacterBannerStatus.NONE)

#			print("Autority for ", name, " peer ping: ", str(ping) + " ms")# · " + str(packet_loss))
		#	print("Network connection check for character ", name)



func _on_settings_var_changed(variable: String, value):
	if variable == 'render_fov':
		if MultiplayerState.local_character == self:
			profile.fov = value
			print("Settings var changed")
			update_camera_fov()


# apply the team defined in state to all visual elements of the character
func apply_team_state() -> void:
	if is_instance_valid(body_mesh):
		body_mesh.set_instance_shader_parameter("team_body", state.team)
	else:
		push_error("Character applying team state but no body mesh was found")
	if is_instance_valid(hands_mesh):
		hands_mesh.set_instance_shader_parameter("team_body", state.team)
	else:
		push_error("Character applying team state but no hands mesh was found")

	banner.get_node("NameTag").modulate = Globals.team_colors[state.team]
	face_mesh.set_instance_shader_parameter("team", state.team)
	face_light.light_color = Globals.team_colors[state.team]
	face_light_1st_person.light_color = Globals.team_colors[state.team]

	# TODO: this is bad, and it was not necessary right up until recently, but
	# this last parameter has become stubborn and doesn't always work
	# so I have to apply it a few times to make sure teh team color applies...
	body_mesh.set_instance_shader_parameter("team", state.team)

	if stubborn_body_team_shader_parameter:
		await get_tree().process_frame
		if is_instance_valid(body_mesh):
			body_mesh.set_instance_shader_parameter("team", state.team)
			hands_mesh.set_instance_shader_parameter("team", state.team)
		else:
			return
		await get_tree().process_frame
		if is_instance_valid(body_mesh):
			body_mesh.set_instance_shader_parameter("team", state.team)
			hands_mesh.set_instance_shader_parameter("team", state.team)


func set_character_owner(pid: int):
	name = str(pid)
#	if profile:
#		profile.display_name = profile.display_name + " (" + str(pid) + ")"

	# for BOT characters, the server is their authority
	if pid < 0:
		pid = 1

	set_multiplayer_authority(pid)
	$CharacterAuthority/StateSynchronizer.set_multiplayer_authority(pid)


# pass though HUD updates from subcomponents
func _character_hud_update(update: CharHudUpdate) -> void:
	update.character = self
	update.state = state
	$Models3rdPerson/CharacterHeavy/CharacterHeavySkeleton/Skeleton3D/BoneAttachmentHead/Banner/Health/SubViewport/HealthBar.value = state.health
	$Models3rdPerson/CharacterHeavy/CharacterHeavySkeleton/Skeleton3D/BoneAttachmentHead/Banner/Health/SubViewport/HealthBar/Label.text = str(state.health)
	if update.special_type == CharMovement.SpecialType.JETPACK:
		jetpack_active = update.special_active
	character_hud_update.emit(update)


func update_camera():
#	print("Updating ", CharacterCurrentCamera.keys()[current_camera] ," camera on " , "CURRENT " if Globals.current_character == self else "", "character ", self, " name ", name, " at frame ", Engine.get_frames_drawn())
	assert(current_camera != null, "Attempting to update a camera that's not there!")

#	return # disabling temporarily

	if Globals.current_character == self:
		match current_camera:
			CharacterCurrentCamera.FIRST_PERSON:
				#models3rdPerson.hide()
				body_mesh_3rdPerson.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				models.show()
				wind_streaks.show()
				banner.hide()
				jetpack.transparency = 1
				face_light.hide()
				face_light_1st_person.show()
			CharacterCurrentCamera.THIRD_PERSON:
				#models3rdPerson.show()
				body_mesh_3rdPerson.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				models.hide()
				wind_streaks.hide()
				banner.show()
				jetpack.transparency = 0
				face_light.show()
				face_light_1st_person.hide()
			CharacterCurrentCamera.DEATH:
				#models3rdPerson.show()
				body_mesh_3rdPerson.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				models.hide()
				wind_streaks.hide()
				banner.show()
				jetpack.transparency = 0
				face_light.show()
				face_light_1st_person.hide()
		cameras[current_camera].make_current() # apply the camera
	else:
		#models3rdPerson.show()
		body_mesh_3rdPerson.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		models.hide()
		wind_streaks.hide()
		banner.show()
		jetpack.transparency = 0
		face_light.show()
		face_light_1st_person.hide()


func update_camera_fov():
	if cameras:
		for i in cameras:
			if zoom_amount == 0: # ugly workaround
				cameras[i].fov = profile.fov


func _on_current_character_changed(new: Character, _old: Character):
	# send a HUD update because it's just switched to showing us
	if new == self:
		var update = CharHudUpdate.new()
		update.character = self
		update.state = state
		update.special_type = movement.special_type
		update.special_amount = movement.special_amount
		update.special_active = movement.special_active
		update.got_spawned = true # we're kinda cheating lol
		character_hud_update.emit(update)
		$Head/WindEffects.enabled = true
	else:
		$Head/WindEffects.enabled = false
	update_camera()


func check_idle():
	# IDLE state has lowest priority - apply it only if nothing else is shown
	if not banner_status.visible:
		if idle_time >= IDLE_TIME_THRESHOLD:
			set_banner_status(CharacterBannerStatus.IDLE)

	# if we're under the threshold and we're currently displaying idle - take it down
	if banner_status.visible and banner_status.frame == CharacterBannerStatus.IDLE:
		if idle_time < IDLE_TIME_THRESHOLD:
			set_banner_status(CharacterBannerStatus.NONE)


func update_particle_effects(root: Node) -> void:
	for i in root.get_children(): # activate all top-level particle systems secondary ones should be parented to the primary ones
		if i is GPUParticles3D or i is CPUParticles3D:
			i.amount = max(1, round(i.amount * Settings.get_var("render_particles_amount")))
			i.update_particle_effects()


func _ready():
	# by default hide 1st person models to be viewable from outside.
	# This will be overriden by a current_character_change event if needed
	models.hide()

	Globals.current_character_changed.connect(_on_current_character_changed)
	Globals.focus_changed.connect(_on_focus_changed)
	Settings.var_changed.connect(_on_settings_var_changed)

	# if the character belongs to the local player, make it current
	# disable all cameras to prevent them hijacking scene's current camera
#	print("Unsetting all cameras for character ", self)
	camera.clear_current(false)
	camera_3rd_person.clear_current(false)
	camera_death.clear_current(false)
	camera_death.character = self

#	current_camera = CharacterCurrentCamera.THIRD_PERSON

	# if no global GameState exists...
	if game_state == null:
		# let's try to find one
		if get_tree().get_nodes_in_group(&"GameStates").size() > 0:
			game_state = get_tree().get_nodes_in_group(&"GameStates")[0]
		else:
			# we need to make our own
			game_state = GameState.new()

	# store values for later
	banner_base_visibility_range_end = banner.get_child(0).get("visibility_range_end")
	banner_base_visibility_range_end_margin = banner.get_child(0).get("visibility_range_end_margin")

	weapons.character = self
	weapons.weapons_root = hands
	self.add_child(weapons)
	weapons.set_multiplayer_authority(self.get_multiplayer_authority()) # make local peer the authority - otherwise weapon RPCs won't propagate
	weapons.name = "CharacterWeapons"
	weapons.character_hud_update.connect(_character_hud_update)

	wind_fx.character = self

	self.add_child(movement)

	movement.character_hud_update.connect(_character_hud_update)

	if controller_scene:
		var instance = controller_scene.instantiate()
		controller = instance
		# pass necessary reference to the character controller scene
#		print("Controller: ", controller)
		controller.character = self
		controller.CharControllerEvent.connect(_controller_event)
		controller._ready()
		controller.set_process(true)
		controller.set_physics_process(true)
		head.add_child(controller)
		controller.global_transform = head.global_transform

	# controls are missing control_type
	for ctrl in controls.keys():
		var type = ctrl
		controls[type].control_type = type

	# pass necessary reference to the character movement object
	movement.character = self

	if MultiplayerState.local_character == self:
		profile = MultiplayerState.user_character_profile

	if profile:
		if profile.badges.is_empty():
			profile.badges = [Badges.Badge.PRE_ALPHA]

	apply_profile()

	update_particle_effects(self)

	# hide the banner status
	set_banner_status(CharacterBannerStatus.NONE)
	if multiplayer.has_multiplayer_peer():
		set_banner_status.rpc(CharacterBannerStatus.NONE)

	# if the spawner did not provide a state, randomize our team
	if state == null:
		state = CharacterState.new()
		state.team = randi_range(1,2) as Globals.Teams

	apply_team_state()

	state.health = max_health

	# set the face expression to default
	set_face_expression(CharacterFaceExpression.NEUTRAL, 0)

	# enable movement
#	get_tree().create_timer(0.1).timeout.connect(func (): is_mobile = true; is_controllable = true)

	setup_ragdoll_bones()
	set_ragdoll_colliders_disabled(true)

	is_mobile = true
	is_controllable = true

	spawn_fx()

	say_random_taunt(voice.spawn)

#	print("Character ", name, " checking if it's local authority")
	if multiplayer.has_multiplayer_peer():
#		print("\tMultiplayer peer found.")
		if str(multiplayer.get_unique_id()) == name:
#			print("\tCharacter IS local authority, setting as current and local")
			MultiplayerState.local_character = self
	#			print("Setting character ", name, " as CURRENT")
			Globals.current_character = self
#			profile = MultiplayerState.user_character_profile
#		else:
#			print("\tCharacter IS NOT local authority")
#	else:
#		print("\tNo multiplayer peer found.")

	# set this var to false so we stop updating our cameras every frame
	# after a couple seconds from spawning
	var tween = create_tween()
	tween.tween_interval(3) # wait a bit
	tween.tween_property(self, "check_cameras", false, 0)
	tween.play()

	# by default don't play wind noise
	$Head/WindEffects.enabled = false

	# only run on remote characters ("puppets") and if we're playing online
	if str(multiplayer.get_unique_id()) != name and multiplayer.has_multiplayer_peer():
		# check ping periodically so we can show a "lag" status banner if needed
		check_network_connection_tween = create_tween().set_loops(0)
		check_network_connection_tween.tween_interval(1)
		check_network_connection_tween.tween_callback(check_network_connection)
		check_network_connection_tween.play()


#	await get_tree().create_timer(1).timeout

	var update = CharHudUpdate.new()
	update.character = self
	update.state = state
	update.got_spawned = true
	character_hud_update.emit(update)

# clean up
func _exit_tree():
	if check_network_connection_tween:
		check_network_connection_tween.kill()

	# activate despawning effects and repartent them to the scene tree's root
	var despawn_fx = $DespawnFX
	despawn_fx.get_node("AnimationPlayer").play("Despawn")
	despawn_fx.reparent(get_tree().root)
	despawn_fx.global_transform = global_transform


func process_view_zoom(delta: float) -> void:
	var base_fov := DEFAULT_FOV # initialize with default
	if profile:
		if profile.fov: # try to read from profile
			base_fov = profile.fov

	var target_fov = base_fov / ZOOM_FACTOR

	# are we zooming in?
	if controls[Globals.CharCtrlType.V_ZOOM].enabled:
		zoom_velocity = minf(zoom_velocity + delta * ZOOM_VELOCITY_RATE, 1.0)
	else:
		zoom_velocity = maxf(zoom_velocity - delta * ZOOM_VELOCITY_RATE, -1.0)

	# changing direction but not during motion shou;ld reset velocity to avoid delay

	zoom_amount += delta * ZOOM_SPEED * zoom_velocity

	if zoom_amount <= 0.1 and zoom_velocity < 0:
		zoom_amount = 0
	if zoom_amount >= 0.95 and zoom_velocity > 0:
		zoom_amount = 1

	if controls[Globals.CharCtrlType.V_ZOOM].changed and zoom_amount in [0.0, 1.0]:
		zoom_velocity = 0.0

	var factor = smoothstep(0, 1, zoom_amount)
	# interpolate

	camera.fov = lerpf(base_fov, target_fov, factor)
#	print("Lerping camera fov: ", camera.fov, " camera: ", camera, " active camera: ", get_viewport().get_camera_3d())

	# is the fov changing?
	if zoom_amount != zoom_amount_previous:
		if zoom_amount == 0:
			is_armed = true
			set_banner_status(CharacterBannerStatus.NONE)
			if multiplayer.has_multiplayer_peer():
				set_banner_status.rpc(CharacterBannerStatus.NONE)
		elif zoom_amount > 0:
			is_armed = false
			set_banner_status(CharacterBannerStatus.ZOOM)
			if multiplayer.has_multiplayer_peer():
				set_banner_status.rpc(CharacterBannerStatus.ZOOM)

		var update = CharHudUpdate.new()
		update.character = self
		update.state = state
		update.zoom_amount = zoom_amount
		update.zoom = true
		character_hud_update.emit(update)

	zoom_amount_previous = zoom_amount


func process_wind_streaks(_delta: float):
#	print("Character's ", name, " current camera is ", current_camera)
	if current_camera != CharacterCurrentCamera.FIRST_PERSON:
		return

	if Globals.current_character != self:
		return

#	if velocity.length() > 0.1:
	if velocity.dot(Vector3.UP) > 0.99 or\
	velocity.dot(Vector3.UP) < -0.99:
		wind_streaks.look_at(global_position + velocity, Vector3.FORWARD)
	else:
		wind_streaks.look_at(global_position + velocity, Vector3.LEFT)

	wind_streaks.rotate_object_local(Vector3(1,0,0), deg_to_rad(90))
	var streaks = pow(clamp(remap(velocity.length(), 13, 20, 0, 1), 0, 1), 1.3)

	wind_streaks.mesh.surface_get_material(0)["shader_parameter/Speed"] = streaks
#	print("Characters's ", name, " streaks: ", velocity.length())

#	%WindStreaks.set_instance_shader_parameter("Speed", remap(velocity.length(), 10, 25, 0, 1))
#		%WindStreaks.transparency = remap(velocity.length(), 10, 25, 1, 0)

# cast a ray from banner to camera to prevent banners being visible through walls
func banner_raycast_camera_check():
	var current_character = Globals.current_character

	# spectators can view everyone
	if not current_character:
		return
	# is this character is current?
	if current_character == self:
		return

	# is the character viewing the world on our team? if so - they are allowed to see the banner though walls!
	if current_character.state.team == self.state.team:
		for i in banner.get_children(): # DISABLE occlusion culling
			if i.get(&"ignore_occlusion_culling"):
				i.set(&"ignore_occlusion_culling", true)
		return
	else:
		for i in banner.get_children(): # enable occlusion culling
			if i.get(&"ignore_occlusion_culling"):
				i.set(&"ignore_occlusion_culling", false)

	if get_viewport().get_camera_3d():
		var space_state = get_world_3d().direct_space_state
		var physics_ray_query_parameters_3d = PhysicsRayQueryParameters3D.new()
		physics_ray_query_parameters_3d.from = banner.global_position
		physics_ray_query_parameters_3d.to = get_viewport().get_camera_3d().global_position
		physics_ray_query_parameters_3d.collision_mask = 1 # only colliewith solid geometry
		physics_ray_query_parameters_3d.exclude = [self.get_rid(), Globals.current_character.get_rid()]


		# is there a character that we're looking at the game throgh the eyes of right now?
		if current_character and current_character != self:
	#		print("Current character exists")
			# does this character use first person camera at the moment?
			if current_character.current_camera == Character.CharacterCurrentCamera.FIRST_PERSON:
	#			print("Current character using first person camera")
				physics_ray_query_parameters_3d.exclude = [current_character]
	#		else:
	#			print("Current character NOT using first person camera")

		var ray = space_state.intersect_ray(physics_ray_query_parameters_3d)

#		print("ray: ", ray)

		if ray.size() > 0 and not banner_ray_previously:
			banner.hide()
			banner_ray_previously = true
		elif not ray.size() > 0 and banner_ray_previously:
			banner.show()
			banner_ray_previously = false


func _process(delta):
	if self.is_queued_for_deletion():
		return

	if camera:
		process_view_zoom(delta)

	# this is an ugly workaround for camera trouble when joining a game
	if check_cameras or get_viewport().get_camera_3d() == null:
		update_camera()
#	print("Camera fov: ", camera.fov, " camera: ", camera, " active camera: ", get_viewport().get_camera_3d())

	camera_distance_and_fov_based_corrections()

	# if there's any rumble camera shake sources present
	if not rumble_sources.is_empty():
		# let's process them
		process_rumble(delta)

	if face_on_screen and not winked:
		face_screen_time += delta * Engine.time_scale

		if face_screen_time > 5 and Engine.get_physics_frames() % 10 == 0 and randf() <= 0.01: # check every 10 physics frames
			face_on_screen = false
			set_face_expression(CharacterFaceExpression.WINK, 0.75)
			winked = true
	if not state.is_queued_for_deletion():
		if not state.alive:
			if killer:
				if not killer.is_queued_for_deletion():
#					camera_death_pivot.global_position = head.global_position
					camera_death.target = killer

	if multiplayer.has_multiplayer_peer():
		if str(multiplayer.get_unique_id()) == name:
			profile = MultiplayerState.user_character_profile
			apply_profile()

	process_wind_streaks(delta)

	# bend charcter's back up/down
	skeleton.set_bone_pose_rotation(aim_bone, aim_bone_rotation + Quaternion(Vector3.LEFT, head.rotation.x))

	banner_raycast_camera_check()


@rpc("call_remote", "any_peer", "reliable")
func attack_hit_confirmation(kill: bool = false, _victim = null):
	var update = CharHudUpdate.new()

	# victim cna be passed as node refrence (if called on local peer)
	# or as a PID of the character owner (if called from a remote peer)
	var victim : Character
	if _victim is Character:
		victim = _victim
	elif _victim is int:
		victim = game_state.characters_by_pid[_victim]
	else:
		printerr("Character recieved hit confirmation with invalid victim data: ", _victim)
		return

	if victim == self: # don't process self-inflicted damage
		return

	if kill and victim != self: # suicide doesn't count
		state.kills += 1
		update.did_kill = victim

		say_random_taunt(voice.kill, 0.25)

		set_face_expression(CharacterFaceExpression.KILL, 3)

		Globals.game_state.increment_team_score(state.team, self)

	else:
		update.did_damage = true
		set_face_expression(CharacterFaceExpression.ATTACK)

	character_hud_update.emit(update)


func camera_distance_and_fov_based_corrections() -> void:
	if not state.alive:
		return
	if not profile:
		return
	if not profile.fov is int:
		profile.fov = Settings.get_var("render_fov")

	# change outline thickness based on the distance from the current camera to maintain the same visual thickness regardless of distance.
	var current_camera = get_viewport().get_camera_3d()

	if current_camera:
		var distance = get_viewport().get_camera_3d().global_position.distance_to(self.global_position)
		var fov = current_camera.fov
		var thickness : float = lerpf(4.0, 96.0, distance / 50.0) * lerpf(0.1, 1, fov / profile.fov) * outline_thickness_factor
		#thickness = clamp(thickness, 0, 64)
		set_team_outline_thickness(thickness)

		# this has to be done per-element because of pivots
		for i in banner.get_children():
			# correct the scale of every banner element
			i.scale = Vector3.ONE * (fov / profile.fov) * (banner_status_scale if i == banner_status else 1.0)

			# change distance fade so you can actually see more when zoomed in
			i.set("visibility_range_end", banner_base_visibility_range_end * (profile.fov / fov) * (banner_status_visibility_range if i == banner_status else 1.0))
			i.set("visibility_range_end_margin", banner_base_visibility_range_end_margin * (profile.fov / fov ))


func set_team_outline_thickness(x: float) -> void:
	return # temporarily disabled to avoid parameter bleed due to a Godot bug
	body_mesh.set_instance_shader_parameter("outline_thickness", x)
	hands_mesh.set_instance_shader_parameter("outline_thickness", x)


func setup_ragdoll_bones() -> void:
	for i in skeleton.get_children():
		if i is PhysicalBone3D:
			i.set_script(preload("res://Assets/Characters/CharacterPhysicalBone.gd"))


func set_ragdoll_colliders_disabled(disabled: bool) -> void:
#	return
	for i in skeleton.get_children():
		if i.get_child(0) is CollisionShape3D:
			i.get_child(0).set_deferred(&"disabled", disabled)
			if not disabled:
				i.apply_central_impulse(Vector3.UP * randf_range(15,5)\
				+ Vector3.LEFT * randf_range(-5,5)\
				+ Vector3.FORWARD * randf_range(-5,5))
#			i.can_sleep = false
#			print("Setting bone ", i.get_child(0)," disabled state as ", i.get_child(0).disabled)


@rpc func die(damage : Damage) -> void:
	if state.alive == false:
		return

	mouth.stop()
	mouth.stream = voice.die
	mouth.play()


	var update = CharHudUpdate.new()
	update.character = self
	update.got_killed = true

	hands.hide()

#	var damage = DamageFall
	#damage.damage_amount = state.health # we were hurt just enough to die

	if damage is DamageAttack:
		if damage.attacker is EncodedObjectAsID:
			damage.attacker = instance_from_id(damage.attacker.object_id)

	update.got_damage = damage
	#state.health = 0 # and now we have no health
	update.state = state

	character_hud_update.emit(update)

	character_died.emit()

	if false:
		var tween = create_tween()
		tween.tween_property(self, "rotation", rotation + Vector3(PI/ 2,0,0), 1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		tween.parallel()
		tween.tween_property($Body, "position", $Body.position - Vector3(0,0.3,0), 1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		tween.play()

	# zoom resets on death, so let's hide the banner too
	if banner_status.frame == CharacterBannerStatus.ZOOM:
		set_banner_status(CharacterBannerStatus.NONE)

	# disable collision with other players so bodies can't block the living
	collision_layer = collision_layer_dead
	collision_mask = collision_mask_dead
	is_mobile = false

	# spare a dedicated server the hassle of simulating ragdolls
	if MultiplayerState.role != Globals.MultiplayerRole.DEDICATED_SERVER:
		skeleton.physical_bones_start_simulation()
		set_ragdoll_colliders_disabled(false)

	current_camera = CharacterCurrentCamera.DEATH

	if state.health > 0:
		state.health = 0
	set_face_expression(CharacterFaceExpression.DEAD, 0)
	state.alive = false
	state.deaths += 1

	state.spawn_time = (Time.get_ticks_msec() / 1000.0) + MultiplayerState.game_config.respawn_wait_time
	var respawn_tween = create_tween()
	respawn_tween.tween_interval(MultiplayerState.game_config.respawn_wait_time)
	respawn_tween.chain()

#	respawn_tween.tween_property(body_mesh, "transparency", 1, 1)
#	respawn_tween.parallel()
#	respawn_tween.tween_property(face_mesh, "transparency", 1, 1)
#	respawn_tween.parallel()
#	respawn_tween.tween_property($Jetpack, "transparency", 1, 1)

	respawn_tween.finished.connect(respawn)
	respawn_tween.play()

	### NO HUD UPDATE HERE - hurt() handles it


func _on_focus_changed(new, previous):
	# if currently controlled character is yanked out of the focus...
	if new != Globals.Focus.GAME and\
	previous == Globals.Focus.GAME and\
	Globals.current_character == self and\
	MultiplayerState.local_character == self:
		reset_all_controls()


# make the character stop doing whatever they were doing
func reset_all_controls() -> void:
	var event = CharCtrlEvent.new()

	for i in controls:
#		controls[i].enabled = false
		var cc = CharCtrlChange.new(i)
		cc.enabled = false
		cc.changed = true
		event.control_changes.append(cc)

#	print("Sending a controller event to stop all actions")
	_controller_event(event)


@rpc("call_remote", "any_peer", "unreliable")
func set_rumble_source(source_id, rumble) -> void:
	rumble_sources[source_id] = {
		"amount" : rumble.amount, # maximum amount
		"decay" : rumble.decay, # envelope attack slope (higher is shorter duration)
		"attack" : rumble.attack, # envelope decay slope (higher is shorter duration)
		"factor" : 0.0, # envelope multiplier
		"stage" : 0, # envelope stage (0 -> attack, 1 -> decay)
		}


func process_rumble(delta: float) -> void:
	# this will let us write down what source are no longer needed
	var erase_queue = []

	# reset the camera shake amount so we can add all of them up
	camera_shake_rumble.shake_amount = 0
#	print("Rumble sources: ", rumble_sources)
	for i in rumble_sources.keys():
		match rumble_sources[i].stage: # 0 - attack, 1 - decay
			0 : rumble_sources[i].factor = move_toward(rumble_sources[i].factor, 1, delta * rumble_sources[i].attack)
			1 : rumble_sources[i].factor = move_toward(rumble_sources[i].factor, 0, delta * rumble_sources[i].decay)

		# trasition from the attack stage to decay
		if is_equal_approx(rumble_sources[i].factor, 1)\
		and rumble_sources[i].stage == 0:
			rumble_sources[i].stage = 1

		# apply the rumble_source
		camera_shake_rumble.shake_amount += rumble_sources[i].amount * rumble_sources[i].factor

#		print("Stage: ", rumble_sources[i].stage, "; Factor: ", rumble_sources[i].factor)
		# apply decay to the rumble source

		# check if the source is over
		if rumble_sources[i].factor <= 0 and rumble_sources[i].stage == 1:
			erase_queue.append(i) # schedule the rumble source for deletion

	# this has to be done in a separate loop, because doing it while iterating over the dictionary
	# results in an undefined behavior
	for i in erase_queue:
		rumble_sources.erase(i)

	# ensure the rumble won't ever exceed sane limits
	camera_shake_rumble.shake_amount = clamp(camera_shake_rumble.shake_amount, 0, 1)


func respawn() -> void:
	hide()

	# spare a dedicated server the hassle of handling ragdolls
	if MultiplayerState.role != Globals.MultiplayerRole.DEDICATED_SERVER:
		set_ragdoll_colliders_disabled(true)
		skeleton.physical_bones_stop_simulation()

	is_gibbed = false
#	if Globals.current_character == self:
	is_mobile = false

	movement.reset()

	current_camera = CharacterCurrentCamera.FIRST_PERSON

#	print("Character respawned at ", respawn_location)
#	rotation.x = 0 # make it stand up

	#$Body.position = base_body_position
	state.health = max_health
	state.alive = true

	hands.show()

	global_transform = game_state.get_spawn_transform(state.team)
	camera.rotation.z = 0 # reset camera shake roll
	state.spawn_time = 0 # signify there's no scheduled respawn

	# resetting character controls
	reset_all_controls()

	# resetting camera rotation
	head.rotation = Vector3.ZERO

	# ensure the character is already in a new position before making it visible and tangible
	await get_tree().create_timer(0.05).timeout
	await get_tree().process_frame

	# reload all weapons
	weapons.primary.reset()
	weapons.secondary.reset()
	weapons.tertiary.reset()

	#skeleton.reset_bone_poses()

	show()

	# enabling movement (gravity etc)

	body_mesh.transparency = 0
	face_mesh.transparency = 0
	jetpack.get_node("Jet").transparency = 0
	#jetpack.transparency = 0

	# enable collision with other players (restore collision layer)
	collision_layer = collision_layer_alive
	collision_mask = collision_mask_alive

	spawn_fx()

	set_face_expression(CharacterFaceExpression.NEUTRAL, 0)

	var update = CharHudUpdate.new()
	update.character = self
	update.state = state
	update.got_spawned = true
	character_hud_update.emit(update)

	camera_shake_jetpack.shake_amount = 0
	camera_shake_damage.shake_amount = 0
	$Head/Camera/CameraShakeWind.shake_amount = 0

	# change to play a respawn line
	say_random_taunt(voice.spawn, 0.25)

	is_mobile = true


func say_random_taunt(taunts : Array[AudioStream], probability : float = 1.0):
	# skip purely visual stuff on a dedicated server
	if MultiplayerState.role == Globals.MultiplayerRole.DEDICATED_SERVER:
		return

	# inverted chance of not doing anything
	if randf() > probability:
		return

	mouth.stream = taunts[randi() % taunts.size()]

	get_tree().create_timer(randf_range(0.4, 0.8)).timeout.connect(mouth.play)


func spawn_fx():
	# skip purely visual stuff on a dedicated server
	if MultiplayerState.role == Globals.MultiplayerRole.DEDICATED_SERVER:
		return

	$SpawnFX/SpawnVFX.emitting = false
	$SpawnFX/SpawnVFX2.emitting = false

	$SpawnFX/SpawnSFX.play()
	$SpawnFX/SpawnVFX.emitting = true
	$SpawnFX/SpawnVFX2.emitting = true
	$SpawnFX/SpawnLight.play(&"Spawn")


func set_face_expression(expression: CharacterFaceExpression, expiration_time: float = 1.5) -> void:
	# skip purely visual stuff on a dedicated server
	if MultiplayerState.role == Globals.MultiplayerRole.DEDICATED_SERVER:
		return

	# can't change your expression if you're dead
	if state.alive == false:
		return

	if expression <= CharacterFaceExpression.keys().size():
		# make sure there isn't any scheduled face resetting before we proceed
		if face_expression_tween:
			if face_expression_tween.is_running():
				face_expression_tween.kill()

		# set the face in the shader
		face_mesh.set(&"shader_uniforms/FaceExpression", expression)

		# expiration_time of 0 means the expression won't reset to default on it's own
		if expiration_time > 0:
			# shedule resetting the face expression back to default
			face_expression_tween = create_tween()
			face_expression_tween.tween_interval(expiration_time)
			face_expression_tween.chain()
			face_expression_tween.tween_property(face_mesh, "shader_uniforms/FaceExpression",\
				CharacterFaceExpression.NEUTRAL, 0)
			face_expression_tween.play()


# ths function modifies some parameters used to configure banner_status sprite scanel and view distance
# this is done to make it clear to people shooting others that the victims may not be able to defend themselves right now
func emphasize_banner_status() -> void:
	# skip purely visual stuff on a dedicated server
	if MultiplayerState.role == Globals.MultiplayerRole.DEDICATED_SERVER:
		return

	if banner_status_tween.is_running():
		banner_status_tween.kill()

	banner_status_tween = create_tween()
	banner_status_scale = 1.5
	banner_status_visibility_range = 32.0
	banner_status_tween.tween_property(self, "banner_status_scale", 1.0, 1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	banner_status_tween.parallel()
	banner_status_tween.tween_interval(0.5)
	banner_status_tween.chain()
	banner_status_tween.tween_property(self, "banner_status_visibility_range", 1.0, 2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	banner_status_tween.play()


@rpc("call_remote", "any_peer", "reliable")
func set_banner_status(status: CharacterBannerStatus) -> void:
	if banner_status.frame == status and banner_status.visible:
		return
	elif status == CharacterBannerStatus.NONE and not banner_status.visible:
		return
	elif status == CharacterBannerStatus.NONE and banner_status.visible:
		banner_status.visible = false
	else:
		banner_status.visible = true
		banner_status.frame = status


@rpc("call_remote", "any_peer", "reliable")
func get_banner_status() -> CharacterBannerStatus:
	if banner_status.visible:
		return banner_status.frame as CharacterBannerStatus
	else:
		return CharacterBannerStatus.NONE


# function to apply visual changes using this character's profile resource
func apply_profile() -> void:
	if not is_instance_valid(profile):
		push_warning("Attempting to apply a character profile. but it's ", profile)
		return

	profile.fov = Settings.get_var("render_fov")

	update_camera_fov()

	mouth.pitch_scale = profile.voice_pitch

	if profile.display_color:
		#var mat2 := body_mesh.mesh.surface_get_material(0).duplicate()
		body_mesh.set_instance_shader_parameter("body_color", profile.display_color)
		hands_mesh.set_instance_shader_parameter("body_color", profile.display_color)

	if profile.display_name:
		banner.get_node("NameTag").text = profile.display_name

	banner.get_node("Badge").texture = Badges.get_top_priority_badge_texture(profile.badges)
	banner.get_node("Badge").show()


func _controller_event(event: CharCtrlEvent) -> void:
	if self.is_queued_for_deletion():
		return

	# reset the idle timer
	idle_time = 0

	# in a multiplayer game only the multiplayer authority can control a character
	if MultiplayerState.role != Globals.MultiplayerRole.NONE: # PID less than zero means we're a BOT
		if is_multiplayer_authority() == false:
			return

	# dead characteres don't move (voluntarily);
	if state.alive and is_controllable:
		if event.use_absolute:
			if event.abs_location:
				global_transform.origin = event.abs_location

			if event.abs_aim:
				head.set_rotation(Vector3(event.abs_aim.y, 0, 0)) # head up/down
				set_rotation(Vector3(0, event.abs_aim.x, 0)) # body left/right

		if event.aim:
				# when zoom_amount == 0, no change is applied; otherwise sensitivity is reduced
				movement.aim(event.aim / ((zoom_amount * ZOOM_FACTOR) + 1))

		if not event.control_changes.is_empty():
			for ctrl in event.control_changes:
				if is_instance_valid(ctrl):
					var type = ctrl.control_type
					controls[type].enabled = ctrl.enabled
					controls[type].changed = true

		if is_armed:
			weapons._controller_event(event)


func _physics_process(delta:float) -> void:
	if self.is_queued_for_deletion():
		return

	if is_armed:
		weapons.process(delta)

	movement.process(delta)

	# Make "wind" when moving
	if velocity.length() > 0.01:
		# scale particle attractor with speed
		$Body/GpuParticlesAttractorSphere3d.strength = velocity.length() * 1
		# align it with movement direction
		if velocity.dot(Vector3.UP) > 0.99 and velocity.dot(Vector3.UP) < -0.99:
			$Body/GpuParticlesAttractorSphere3d.look_at(position + velocity, Vector3.UP)
	else:
		$Body/GpuParticlesAttractorSphere3d.strength = 0


	if state.alive:
		idle_time += delta
		if multiplayer.has_multiplayer_peer():
			if name == str(multiplayer.get_unique_id()):
				idle_time += delta
				check_idle()
		else:
			check_idle()


@rpc("call_remote", "any_peer", "reliable")
func hurt(_damage) -> void:
	if is_gibbed:
		return
#	print("Recieved damage ", _damage)

	var attacker : Character

	var damage : Damage
	if _damage is Damage:
		damage = _damage
		if damage is DamageAttack:
			#if damage.attacker is Node:
			attacker = damage.attacker
			#else:
			#	attacker = GameState.characters_by_pid[damage.attacker_pid]
#			print_debug("Local attacker is ", attacker)
	elif _damage is Dictionary:
		damage = dict_to_inst(_damage)
		if damage is DamageAttack:
			if game_state.characters_by_pid.has(damage.attacker_pid):
				attacker = game_state.characters_by_pid[damage.attacker_pid]
#			print_debug("Remote attacker is ", attacker)
	else:
		push_error("Character recieved invalid damage object")

	if is_instance_valid(attacker):
		if attacker.is_queued_for_deletion():
			attacker = null
	else:
		attacker = null

#	print("Identified Attacker is ", attacker)
	if damage is DamageAttack:
#		print("Attacker is ", damage.attacker)e
#		print("Attacker PID is ", damage.attacker_pid)
		damage.attacker = attacker


	if state.alive: # die() was not called yet
		if damage is DamageAttack and damage.attacker:
			# friendly fire?
			if damage.attacker == self and damage is DamageExplosion: # blast self-damage
				pass
			elif damage.attacker.state.team == state.team:
				# run only on attacker's peer
				if str(multiplayer.get_unique_id()) == damage.attacker.name:
					# let the attacker know we're on their team by animating the outline thickness
					# and showing a banner


					# if we're hitting ourselves with our own splash damage
					var previous_banner_status

					if banner_status.visible:
						previous_banner_status = banner_status.frame
					else:
						previous_banner_status = CharacterBannerStatus.NONE

					set_banner_status(CharacterBannerStatus.SAME_TEAM)
					emphasize_banner_status()

					# add extra stuff to the tween that emphasize_banner_status() uses
					banner_status_tween.chain()
	#				banner_status_tween.tween_interval(1)
	#				banner_status_tween.chain()
					banner_status_tween.tween_property(banner.get_node("Status"), "transparency", 1, 3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
					banner_status_tween.chain()
					banner_status_tween.tween_property(banner.get_node("Status"), "visible", false, 0)
					banner_status_tween.tween_property(banner.get_node("Status"), "transparency", 0, 0)

					if outline_thickness_tween:
						outline_thickness_tween.kill()

					outline_thickness_tween = create_tween()
					outline_thickness_tween.tween_property(self, "outline_thickness_factor", 4, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
					outline_thickness_tween.chain()
					outline_thickness_tween.tween_property(self, "outline_thickness_factor", 1, 1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CIRC)
					# after the animation ends restore the previous banner status (or none)
					outline_thickness_tween.finished.connect(set_banner_status.bind(previous_banner_status))
					outline_thickness_tween.play()

				if MultiplayerState.game_config.friendy_fire_amount != 0:
					damage.damage_amount *= MultiplayerState.game_config.friendy_fire_amount
				else:
					return

	state.health -= damage.damage_amount

	camera_shake_damage.shake_amount += damage.damage_amount / 100.0

	# damage push force
	if damage is DamageHit:
		movement.push_velocity += (self.global_position - damage.hit_position).normalized() * damage.push_force
#		velocity += (self.global_position - damage.hit_position).normalized() * damage.push_force * 10
#		movement.movement_velocity = velocity

	if state.alive: # die()_ wasn't called yet
		if state.health <= 0: # but we recieved enough damage to die
			if damage is DamageAttack:
				if damage.attacker:
					killer = damage.attacker # remember who killed us (if anyone)
					killer.tree_exiting.connect(func(): killer = null)
					damage.attacker.attack_hit_confirmation(true, self) # send kill confirmation
				else:
					killer = null
		else:
			if not mouth.playing:
				mouth.stop()
				mouth.stream = voice.hurt
				mouth.play()

			if damage is DamageAttack:
				if damage.attacker:
					damage.attacker.attack_hit_confirmation(false, self) # send hit confirmation
#					damage.attacker = attacker

			var update = CharHudUpdate.new()
			update.character = self
			update.state = state
			update.got_damage = damage
#			print("Damage recieved: ", inst_to_dict(damage))
#			if damage is DamageAttack:
#				update.got_damage.attacker = attacker # update the attacker to ensure HUD will get a valid node reference

			character_hud_update.emit(update)

		if state.health <= 0:
			await get_tree().process_frame
			die(damage)

		# set the face to express pain, keep it longer for higher damage values
		set_face_expression(CharacterFaceExpression.HURT, remap(damage.damage_amount, 5, 100, 0.5, 5) )

		if multiplayer.has_multiplayer_peer():
			if damage is DamageAttack:
				if is_instance_valid(damage.attacker):
					if str(multiplayer.get_unique_id()) == damage.attacker.name:
					# if the character's player isn't actively playing, animate the banner to indicate that
					# the ZOOM banner is an exception - it's not a reason to not shoot someone, quite the contrary
					# so we're not gonna make this too easy
						if banner_status.frame not in [CharacterBannerStatus.NONE, CharacterBannerStatus.ZOOM]:
							emphasize_banner_status()


	# gibbing when the health is below a certain level
	if not state.alive and state.health <= -max_health / 3 :
		gib()

		# do the following only if the peer this is runnin on is the same that dealt the damage


func gib():
	hide()
	is_gibbed = true
	is_mobile = false
	self.collision_mask = collision_layer_gibbed

	# skip purely visual stuff on a dedicated server
	if MultiplayerState.role == Globals.MultiplayerRole.DEDICATED_SERVER:
		return

	var gib_fx = preload("res://Assets/Effects/Gibbing.tscn").instantiate()

	for j in gib_fx.get_children():
#		print("GibFX child is ", j)
		if not is_inside_tree():
			continue

		if j is GPUParticles3D:
			j.emitting = true
		elif j is AudioStreamPlayer3D:
			j.play(0)

	Globals.get_spawn_root().add_child(gib_fx)
	gib_fx.global_position = $Gibs.global_position
	gib_fx.show()

	if Settings.get_var(&"render_gibs"):
		var gib_scene = preload("res://Assets/Characters/CharacterGib.tscn")
		var gibs : Array
		var gib_amount = 10
		var gib : RigidBody3D
		for i in range(0, gib_amount):
			gib = gib_scene.instantiate()

			if i == 0:
				gib.use_camera = true

			gib.character = self
			gib.global_position = $Gibs.global_position + (Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.5)
			gib.rotation = Vector3(randf(), randf(), randf()) * PI * 4.0
			gib.apply_central_impulse(velocity + Vector3(randf(), randf(), randf()).normalized() * 25 * randf_range(0.3, 1))
			gib.apply_torque_impulse(Vector3(randf(), randf(), randf()).normalized() * randf_range(25, 1500))
			gib.scale = Vector3.ONE * randf_range(0.2, 1.5)


			Globals.get_spawn_root().add_child(gib)
			gib.trigger()


func heal(health: int) -> void:
	var update = CharHudUpdate.new()

	update.character = self
	update.state = state
	update.got_healing = health
	character_hud_update.emit(update)


func _on_visible_on_screen_notifier_3d_screen_entered() -> void:
	if not winked:
		face_on_screen = true


func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	if not winked:
		face_on_screen = false
		face_screen_time = 0
