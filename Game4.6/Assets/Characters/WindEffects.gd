extends AudioStreamPlayer

#@export var minimum_speed: float
#@export var minimum_speed_hysteresis: float
#@export var maximum_speed: float
@export var enabled : bool

@export var speed_to_volume: Curve
@export var speed_to_cutoff: Curve
@export var speed_to_shake: Curve

# for mapping the curves
@export var max_speed: float = 100.0

# for pausing playback to save resources and avoid quiet hum all the time
@export var min_speed: float = 2.0
@export var min_speed_hysteresis: float = 0.5

@onready var audio_bus = AudioServer.get_bus_index("WindSFX")
@onready var audio_filter : AudioEffectFilter = AudioServer.get_bus_effect(audio_bus,0)

@export var camera_shake_path : NodePath
@onready var camera_shake := get_node(camera_shake_path)

#var camera_shake_amount : float = 1

var character : Character # host character reference
var camera : Camera3D # host first-person camera


func _ready() -> void:
	if not enabled:
		set_physics_process(false)

	speed_to_volume.bake()
	speed_to_cutoff.bake()
	speed_to_shake.bake()


func _physics_process(delta) -> void:
	# make sure the sound is ONLY played if this is the current character
	if Globals.current_character == character: # if the player is looking through our eyes
		if playing == false:
			playing = true
	else:
		if playing == true:
			playing = false

	var speed = character.velocity.length()

	if speed > min_speed + min_speed_hysteresis / 2:
		stream_paused = false
	elif speed < min_speed - min_speed_hysteresis / 2:
		stream_paused = true

	volume_db = speed_to_volume.sample_baked(speed / max_speed)
	audio_filter.cutoff_hz = speed_to_cutoff.sample_baked(speed / max_speed) * 10 # convert to 0-1 kHz range
	camera_shake.shake_amount = speed_to_shake.sample_baked(speed / max_speed)
