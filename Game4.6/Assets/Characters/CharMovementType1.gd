class_name CharMovementType1 extends CharMovement

enum Medium {AIR, GROUND, WATER}
var medium: Medium = Medium.GROUND

var accel_type := {
	Medium.GROUND: 12,
	Medium.AIR: 1,
	Medium.WATER: 4,
	}

var speed_type := {
	Medium.GROUND: 10,
	Medium.AIR: 10,
	Medium.WATER: 5,
	}

var damp_type := {
	Medium.GROUND: 0,
	Medium.AIR: 0.005 * 60.0,
	Medium.WATER: 0.05 * 60.0,
	}#	set(value):
##		print("movement_velocity changed ")
#		if MultiplayerState.role != Globals.MultiplayerRole.NONE:
#			if not self.is_multiplayer_authority():
#				movement_velocity = value
##				velocity = movement_velocity

var gravity: float = 28
var jump: float = 14

var jump_jetpack_threshold : float = 0.15 # seconds
var jump_time : float = 0
var jetpack_started_from_ground = false
var jetpack_run_dry = false

var character_top_velocity : float = 0

var gravity_vec: Vector3

var walk_dir: Vector3

var walk_speed: float = 0
var walk_accel: float = 0
var walk_damp: float = 0

var movement_velocity := Vector3.ZERO
var previous_velocity := Vector3.ZERO

var push_velocity := Vector3.ZERO

var jetpack_thrust: float = 48.0 # force applied against gravity
var jetpack_tank: float = 0.75 # maximum fuel
var jetpack_fuel: float = jetpack_tank # current fuel
var jetpack_recharge: float = 0.25 # how long to recharge to full
var jetpack_min: float = 0.125 # cannot deploy jetpack if fluel is below this

#var jetpack_target_delta : float = 1.0 / 60.0
#var jetpack_delta : float = 0

# sound effects
const FOOTSTEP_DELAY = 0.25 # seconds between footsteps
const FOOTSTEP_DELAY_VARIANCE = 0.025
var footstep_countdown : float = 0
var previously_on_floor : bool

# weapon_bob

var weapons_root : Node3D


@export var weapon_bob_amplitude := Vector3(0.03, 0.01, 0.01)
@export var weapon_bob_period : float = 125
#@onready var weapon_bob_rest_position = null
@export var weapon_bob_lerp = 10

var weapon_bob_factor : float = 0 # this controls how much bob is applied

# weapon sway

var hands_spring_factor : float = 5
var hands_damping_factor : float = 30
var hands_overshoot_factor : float = 25

var hands_global_position : Vector3
var previous_hands_global_position : Vector3
var head_previous_position : Vector3
#var head_previous_rotation : Vector3
var hands_linear_velocity := Vector3.ZERO
#var hands_angular_velocity := Vector3.ZERO


## initialize parent class member variables overriding defaults
func _ready() -> void:
	special_type = CharMovement.SpecialType.JETPACK
	special_active = false
	special_amount =  1 # normalized fraction of special ability amount


func on_character_changed() -> void:
	weapons_root = character.weapons


func aim(aim: Vector2) -> void:
	# body left/right
	character.rotate_y(aim.x)
	if character.scale != Vector3.ONE:
#		print("Orthonormalized transform for character ", character.name, " at physics frame ",\
#		Engine.get_physics_frames(), " scale error was ", str(character.global_transform.basis.get_scale().distance_to(Vector3.ONE)))
		character.global_transform = character.global_transform.orthonormalized()
	# head up/down
	character.head.rotation.x = clamp(character.head.rotation.x + aim.y, -PI/2, PI/2)
	if character.head.scale != Vector3.ONE:
		character.head.global_transform = character.head.global_transform.orthonormalized()
#		print("Orthonormalized transform for character's ", character.name, " head at physics frame ",\
#		Engine.get_physics_frames(), " scale error was ", str(character.head.global_transform.basis.get_scale().distance_to(Vector3.ONE)))
	#character.global_transform = character.global_transform.orthonormalized()

	if character == Globals.current_character and character.current_camera == character.CharacterCurrentCamera.FIRST_PERSON:
		weapon_bob(get_process_delta_time())
		if Settings.get_var(&"view_weapon_sway"):
			weapon_sway(get_process_delta_time())


# hands moving when walking
func weapon_bob(delta: float) -> void:
	if not is_instance_valid(weapons_root):
		printerr("Trying to process weapon bob but the weapons_root reference is invalid")
		return

	var weapon_bob_offset = Vector3.ZERO

	var character_walk_speed = character.movement.walk_speed

	var walk_vector = Vector2(character.velocity.x, character.velocity.z)

	# interpolate the weapon_bob_factor to smoothly turn the effect on and off.
	# It will interpoalte towards zero if the character is not grounded
	weapon_bob_factor = move_toward(weapon_bob_factor,\
	remap(walk_vector.length(), 0, character_walk_speed, 0, 1) if character.is_on_floor() else 0.0,\
	weapon_bob_lerp * delta)

	var time : float = Time.get_ticks_msec() * Engine.time_scale

	weapon_bob_offset.x = sin(time / weapon_bob_period)\
	* weapon_bob_amplitude.x

	weapon_bob_offset.y = cos((time / (weapon_bob_period / 2.0)) + 1)\
	* weapon_bob_amplitude.y

	weapon_bob_offset.z = cos((time / weapon_bob_period * 2.0))\
	* weapon_bob_amplitude.z

	weapons_root.position = weapon_bob_offset * weapon_bob_factor


# inertia
func weapon_sway(delta : float):

	var head_linear_velocity : Vector3
#	var head_angular_velocity : Vector3

	head_linear_velocity = head_linear_velocity.lerp((character.head.global_position - head_previous_position) / delta, delta * 0.001)
#	head_angular_velocity = (character.head.global_rotation - head_previous_rotation) / delta

#	hands_linear_velocity.lerp()

	# spring force
	hands_linear_velocity = hands_linear_velocity.lerp(\
		((character.hands.global_position - hands_global_position) / delta) * hands_overshoot_factor,\
		hands_spring_factor * delta)
	# damping
	hands_linear_velocity = hands_linear_velocity.lerp(Vector3.ZERO, hands_damping_factor * delta)
#	hands_angular_velocity.slerp(head_angular_velocity, hands_inertia_factor * delta)

#	print("Head lin velocity:	", head_linear_velocity)
#	print("	Head ang velocity:	", head_angular_velocity)

	hands_global_position += hands_linear_velocity * delta

	hands_global_position = hands_global_position.slerp(character.hands.global_position, delta * 30)

	character.hands.global_position.limit_length(Settings.get_var(&"view_weapon_sway_limit"))

	weapons_root.global_position = hands_global_position
	previous_hands_global_position = weapons_root.global_position
#	character.hands.global_rotation += (hands_angular_velocity - head_angular_velocity) * delta

	head_previous_position = character.head.global_position
#	head_previous_rotation = character.head.global_rotation


func reset() -> void:
	movement_velocity = Vector3.ZERO
	character.velocity = Vector3.ZERO
	character.movement_velocity = Vector3.ZERO
	character_top_velocity = 0.0
	gravity_vec = Vector3.ZERO
	walk_dir = Vector3.ZERO
	jetpack_fuel = jetpack_tank
	special_amount = 1.0

	var update = CharHudUpdate.new()
	update.special_amount = special_amount
	update.special_type = special_type
	update.special_active = true
	character_hud_update.emit(update)


func process(delta:float) -> void:
	if character.is_queued_for_deletion():
		return

	if not character.state.alive:
		if character.jetpack_active:
			var thrust : Vector3 = character.jetpack_physical_bone.global_transform.basis.y * delta * jetpack_thrust * 40
#			print("Jetpack bone thrust: ", thrust)
#			character.jetpack_physical_bone.linear_velocity = Vector3.UP * 7
			character.jetpack_physical_bone.apply_central_impulse(thrust)
#			character.jetpack_physical_bone.global_transform.basis[0]\
#			* jetpack_thrust * (1/60) * 1000 ) # local Y axis (pointing up)
#			character.jetpack_physical_bone.apply_central_impulse(Vector3.UP * 10) # local Y axis (pointing up)

		character.velocity = Vector3.ZERO

	# use velocity provided from the multiplayer sync
	if MultiplayerState.role != Globals.MultiplayerRole.NONE:
		if not character.is_multiplayer_authority():
#			print("NOT the authority. Using remote velocity: ", character.movement_velocity)
			#movement_velocity = character.movement_velocity
			character.velocity = character.movement_velocity
			character.move_and_slide()
			return # skip the rest of the movement code
		else:
			character.movement_velocity = character.velocity
#			print("Authority. Setting remote velocity to: ", character.movement_velocity)

	if not character.state.alive:
		return

	# Gravity
	if character.is_on_floor():
		gravity_vec = Vector3.ZERO
	else:
		gravity_vec += Vector3.DOWN * gravity * delta # applying gravity acceleration

	# Air control
	if character.is_on_floor():
		medium = Medium.GROUND
	else:
		medium = Medium.AIR


	if character.state.alive: # when alive - active movement
		# Jumping
		if character.controls[Globals.CharCtrlType.MOVE_J].changed:
			if character.is_on_floor() and character.controls[Globals.CharCtrlType.MOVE_J].enabled:
				gravity_vec += Vector3.UP * jump
				# sfx
				character.mouth.stream = character.voice.jump
				character.mouth.play()

				jump_time = jump_jetpack_threshold
				jetpack_started_from_ground = true
			### Jetpack
			elif not character.is_on_floor() and character.controls[Globals.CharCtrlType.MOVE_J].enabled:
				jetpack_started_from_ground = false

			jetpack_run_dry = false # clear the flag


		if character.controls[Globals.CharCtrlType.MOVE_J].enabled:
			jump_time -= delta
#			print("jump time: ", jump_time)

		# turning jetpack on and off
		if jetpack_fuel >= jetpack_min and\
		character.controls[Globals.CharCtrlType.MOVE_J].enabled and\
		not jetpack_run_dry and ((jetpack_started_from_ground and jump_time < 0) or not jetpack_started_from_ground): # can't auto-start if we've run out of fuel
#			if (jetpack_started_from_ground and jump_time <= 0) or\
#			not jetpack_started_from_ground:
			character.jetpack_active = true

		elif not character.controls[Globals.CharCtrlType.MOVE_J].enabled:
			character.jetpack_active = false

		# discharging
		# we want to evaluate jetpack ith effective framerate of 60 independent of the actual tick rate
#		jetpack_delta += delta
		if character.jetpack_active and jetpack_fuel > 0: # and jetpack_delta >= jetpack_target_delta:
#			jetpack_delta -= jetpack_target_delta
			if character.state.alive:
				gravity_vec += Vector3.UP * (jetpack_thrust * min(delta, jetpack_fuel))
	#			print("Jetpack acceleration: ", jetpack_thrust * min(delta, jetpack_fuel) / delta)
	#			print("Gravity vector: ", gravity_vec)
			jetpack_fuel = max(jetpack_fuel - delta, 0)

			character.camera_shake_jetpack.shake_amount = 1

			special_amount = jetpack_fuel / jetpack_tank

			var update = CharHudUpdate.new()
			update.special_amount = special_amount
			update.special_type = special_type
			update.special_active = true
			character_hud_update.emit(update)

		# running empty
		elif jetpack_fuel == 0:
	#		print("Jetpack empty")
			character.jetpack_active = false
			character.camera_shake_jetpack.shake_amount = 0
			jetpack_run_dry = true

		# recharging
		if not character.jetpack_active and jetpack_fuel < jetpack_tank:
			jetpack_fuel = min(jetpack_fuel + jetpack_recharge * delta, jetpack_tank)

			var update = CharHudUpdate.new()
			update.special_amount = jetpack_fuel / jetpack_tank
			update.special_type = special_type
			update.special_active = true
			character_hud_update.emit(update)

			character.camera_shake_jetpack.shake_amount = 0

		# Walking direction
		walk_dir = Vector3.ZERO
		if character.controls[Globals.CharCtrlType.MOVE_F].enabled:
			walk_dir -= character.transform.basis.z
		if character.controls[Globals.CharCtrlType.MOVE_B].enabled:
			walk_dir += character.transform.basis.z
		if character.controls[Globals.CharCtrlType.MOVE_L].enabled:
			walk_dir -= character.transform.basis.x
		if character.controls[Globals.CharCtrlType.MOVE_R].enabled:
			walk_dir += character.transform.basis.x

	else: # when dead
		character.jetpack_active = false
		walk_dir = Vector3.ZERO

	if walk_dir.length() > 0: # normalized() will return a null
		walk_dir = walk_dir.normalized()
	# Walk velocity
	walk_speed = speed_type[medium]
	walk_accel = accel_type[medium]
	walk_damp = damp_type[medium]

	# movement acceleration/deceleration
	movement_velocity = movement_velocity.lerp(walk_dir * walk_speed, walk_accel * delta)

	# apply push force
	if not character.is_on_floor(): # compensate for ground friction
		push_velocity /= 60
	movement_velocity += push_velocity
	push_velocity = Vector3.ZERO


	previous_velocity = character.velocity
	previously_on_floor = character.is_on_floor()

	# sum movement velocity and gravity; apply damping/drag
	character.velocity = (movement_velocity + gravity_vec).lerp(Vector3.ZERO, walk_damp * delta)

	if character.velocity.length() > character_top_velocity:
		character_top_velocity = character.velocity.length()
#		print("Top velocity: ", character_top_velocity)
	# Perform movement
	character.move_and_slide()

	# Preserve momentum after collision while in air
	if not character.is_on_floor():
		movement_velocity.x = character.velocity.x
		movement_velocity.z = character.velocity.z
		gravity_vec.y = character.velocity.y

	var sfx_step : AudioStreamPlayer3D = character.feet.get_node("Step")
	var sfx_land : AudioStreamPlayer3D = character.feet.get_node("Land")

	# sound effects
	var walk_velocity = Vector2(movement_velocity.x, movement_velocity.z)
#	print("walk velocity: ", walk_velocity, " footstep_countdown: ", footstep_countdown)
	if walk_velocity.length() > 3 and character.is_on_floor():
		footstep_countdown -= delta
		if footstep_countdown <= 0:
			sfx_step.play()
			footstep_countdown = FOOTSTEP_DELAY + randf_range(-FOOTSTEP_DELAY_VARIANCE, FOOTSTEP_DELAY_VARIANCE)

	if character.is_on_floor() and not previously_on_floor:
		var velocity_loss = character.velocity.y - previous_velocity.y
#		print("Velocity loss: ", velocity_loss)
		var volume_db = remap(velocity_loss, 6, 30, -24, 0)
		sfx_land.volume_db = volume_db
		sfx_land.play()

		# fall damage
		if character == MultiplayerState.local_character:
			var fall_damage = DamageFall.new()
			var fall_damage_factor = remap(velocity_loss, 25, 35, 0, 1)
			fall_damage.damage_amount = clamp(\
			lerpf(0, 35, fall_damage_factor),\
			0, 150)
#			fall_damage.damage_amount = max(remap(velocity_loss, 25, 30, 0, 60), 0)
			if fall_damage.damage_amount > 0:
				character.hurt(fall_damage)
				character.hurt.rpc(inst_to_dict(fall_damage))

	# only process weapon bob for currently viewed first-person character
	if character == Globals.current_character and character.current_camera == character.CharacterCurrentCamera.FIRST_PERSON:
		weapon_bob(delta)
		if Settings.get_var(&"view_weapon_sway"):
			weapon_sway(delta)
