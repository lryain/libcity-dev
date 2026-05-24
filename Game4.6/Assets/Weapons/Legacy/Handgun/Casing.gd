extends RigidDynamicBody3D

@onready var sound = $Sound
@onready var sound_player = sound.get_node("AudioStreamPlayer3D")

@onready @export var smoke_color : Color

@onready var particles_extra = Settings.get_var('render_particles_extra')

func render_casing_update(_var_name, _value) -> void: # doesn't work :(
	print("Checking render casing ", _var_name,' ' , _value)
	#queue_free()

func _ready() -> void:
	Settings.var_changed.connect(render_casing_update) #doesn't work :(
	if particles_extra:
		var pmat = $Smoke.process_material.duplicate()
		$Smoke.process_material = pmat
		$Smoke.emitting = true
		$AnimationPlayer.play("SmokeFade")
	else:
		$Smoke.hide()
	
	var mat = $Casing/Casing_LOD0.get_active_material(0).duplicate()
	$Casing/Casing_LOD0.set_surface_override_material(0, mat)

func _process(delta) -> void:
	if particles_extra:
		$Smoke.process_material.color = smoke_color

func _on_Timer_timeout() -> void:
	#$AnimationPlayer.play("Fade") # doesn't work :(
	queue_free() # ugly workaround for now

func _on_Casing_body_entered(body) -> void:
	var vel = linear_velocity.length()
	
	if vel > 0.5:
		sound_player.unit_db = -48 + min((pow(vel, 3)) * 2, 48)
		sound.play()
