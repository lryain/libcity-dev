extends Node3D
class_name Slide

signal slide_returned

@export_range(0.0, 2.0)
var rollback_time = 0.2

@export var ammo_cost : int = 1

@export_node_path
var magazine_path

@onready
var magazine : Magazine = get_node(magazine_path)

#@onready var timer

var slide_ready := true

var slide_rollback_progress : float = 0:
	set(value):
		slide_rollback_progress = value
		update_slide_display(slide_rollback_progress)

@export var slide_display_mesh_instance : NodePath
@onready var slide_display : MeshInstance3D = get_node_or_null(slide_display_mesh_instance)


func update_slide_display(slide_progress = null):
	if not slide_display:
		return
	slide_display.set_instance_shader_parameter("Value", slide_progress)


func shoot():
#	print("Slide ", name, " checks if it can shoot")
	if slide_ready:
		if not magazine or magazine.feed_into_slide(ammo_cost):
			var tween = create_tween()
			tween.tween_property(self, "slide_rollback_progress", 1.0, rollback_time).from(0.0)
			tween.finished.connect(on_slide_return)
			slide_ready = false
			tween.play()
			return true
	return false


func on_slide_return():
	slide_ready = true
	slide_returned.emit()

func _ready() -> void:
	update_slide_display(1.0)
