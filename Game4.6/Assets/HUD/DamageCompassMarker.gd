extends Control

@onready var tween := create_tween()

var damage : Damage
var character : Character


func _ready() -> void:
	set_process(false)
	hide() # only show the marker once it is properly aligned
#	print("Spawned damage marker for damage: ", damage, " and character: ", character)

	if damage.get(&"source_position") == null:
		queue_free()
		set_process(false)
		return
	
	if damage is DamageHit:
		if character == null:
			character = Globals.current_character

	#	if damage is DamageHit: # for some reason DamageHit doesn't work even though it's a parent class
		tween.tween_property(self, "modulate", Color(1,1,1,1), remap(damage.damage_amount, 10, 100, 0.3, 0.8)).from(Color(3,3,3,3)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.parallel()
		tween.tween_property($Polygon2D, "position", position, 0.15).from(position + Vector2(256,0)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.chain()
		tween.tween_property(self, "modulate", Color(1,1,1,0), remap(damage.damage_amount, 10, 100, 0.75, 2))
		tween.finished.connect(queue_free)
		tween.play()
#		print("Damage marker for source ", damage.source_position)
	#	else:
	#		# if the damage is not directional, it makes no sense to show a compass marker
	#		hide()
	#		queue_free()
	else:
#		print("Damage marker despawning - no valid damage object provided!")
		set_process(false)
		queue_free()
		return

	# wait for the process() to align the marker and only then show it
	await(get_tree().process_frame)
	show()
	set_process(true)


func _exit_tree() -> void:
	# make sure the tween isn't goig to try and access anything that is already gone
	tween.kill()


func _process(delta: float) -> void:
	# location of the character
	if not character:
		queue_free()
		return

	var loc_a = Vector2(character.position.x, character.position.z)
#	print("Loc a: ", loc_a)

	# location of the damage source
	var loc_b = Vector2(damage.source_position.x, damage.source_position.z)
#	print("Loc b: ", loc_b)

#	var distance = log(loc_a.distance_to(loc_b) * 10 + 1) * 30
	# affecting marker dimesions and posision
#	$Control/ColorRect.position.x = distance + 50
#	$Control/ColorRect.size.y = 25

	# affecting marker's angle
	var angle = loc_a.rotated(character.rotation.y).angle_to_point(loc_b.rotated(character.rotation.y))
	self.rotation = angle
