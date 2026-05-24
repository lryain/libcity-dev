extends Area3D

const SPIN = 1

@onready var light_energy = $OmniLight3D.light_energy

var time = 0.0

var active := true:
	set(value):
		active = value
		self.visible = value
		self.monitorable = value
		self.monitoring = value

@export var health : int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	time += delta
	rotate_y(SPIN * delta)	
	$OmniLight3D.light_energy = (sin(time * 4) / 2 + 0.5) * light_energy

@rpc(reliable, call_local) func activate():
	active = false
	$RespawnTimer.start()
	$Pickup.play()

func _on_pickup_body_entered(body):
	if active and body.has_method(&'heal') \
#		and body.is_multiplayer_authority() \ # call on all locally
		and health > 0:
		if body.heal(health):
#			rpc(&'activate') # RPC fails
			activate()

func _on_respawn_timer_timeout():
	active = true
	$Respawn.play()
	$RespawnParticles.emitting = true
