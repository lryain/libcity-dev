class_name Pooler
extends Node3D

@onready var pooler: Node3D = $Pooler

#Stores projectiles that are in use and projectiles that are done can be re-used
var enabled : Array = [] 
var disabled : Array = []



func initialize(ammo_count : int, projectile : PackedScene):
	#Reset the pooler if it already has children
	for child in pooler.get_children():
		child.queue_free()
		enabled = []
		disabled = []
	
	
	for i in range(ammo_count):
		var proj_inst : Projectile = projectile.instantiate()
		disable_projectile(proj_inst)
		pooler.add_child(proj_inst)
		disabled.append(proj_inst)
		proj_inst.connect(proj_inst.projectile_dead.get_name(), on_projectile_stop)

func spawn_projectile(character : Character, projectile_velocity : float):
	if character == null : return
	var projectile : Projectile = disabled.pop_front()
	enabled.push_front(projectile)
	
	projectile.global_transform = global_transform
	projectile.character = character
	projectile.source_position = character.global_position
		# FIXME the shooting direction should be -Z, not -X basis component:
	projectile.linear_velocity = - global_transform.basis.x * projectile_velocity
	
	enable_projectile(projectile)
	
	print("Pooled Bullets Left = " + str(disabled.size()))


func on_projectile_stop(projectile : Projectile):
	disable_projectile(projectile)
	enabled.erase(projectile)
	disabled.push_front(projectile)
	print("Bullet Stopped, left: " + str(enabled.size()))


func disable_projectile(projectile : Projectile):
	projectile.visible = false
	projectile.set_process(false)
	projectile.set_physics_process(false)
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	projectile.disable_mode = CollisionObject3D.DISABLE_MODE_REMOVE


func enable_projectile(projectile : Projectile):
	projectile.visible = true
	projectile.set_process(true)
	projectile.set_physics_process(true)
	projectile.process_mode = Node.PROCESS_MODE_INHERIT
	projectile.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
