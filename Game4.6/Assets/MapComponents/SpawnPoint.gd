@tool
extends Marker3D

@export_enum("Any", "Lime Only", "Plum Only", "None") var team = 0:
	set(value):
		team = value
		if Engine.is_editor_hint():
			$SpawnPointMarker.set_instance_shader_parameter(&"selector", team)
			$SpawnPointMarker/SpawnPointMarkerFloor.set_instance_shader_parameter(&"selector", team)

### Tells the game to spawn the character on the first solid surface beneat the spawnpoint, and not in the air
@export var project_to_floor : bool = true:
	set(value):
		project_to_floor = value
		if Engine.is_editor_hint():
			$SpawnPointMarker/SpawnPointMarkerFloor.visible = ! project_to_floor

var is_free : bool = true


var characters_in_area : int = 0:
	set(value):
		if Engine.is_editor_hint():
			return

		if value < 0:
			printerr("Spawnpoint, ", name, " counted ", value, " characters present in it's area. That can't be right")
			value = 0
		characters_in_area = value
		is_free = characters_in_area == 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	$SpawnPointMarker.queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return

	if body is Character:
		characters_in_area += 1


func _on_area_3d_body_exited(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return

	if body is Character:
		characters_in_area -= 1
