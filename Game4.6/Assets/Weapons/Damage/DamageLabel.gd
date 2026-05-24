class_name DamageLabel extends Label3D

var damage_amount : int = 0:
	set(value):
		damage_amount = value
		text = "-" + str(damage_amount)

var damage_gradient : Gradient = load("res://Assets/Weapons/Damage/DamageGradient.tres")
var max_damage : int = 100

@onready var target_pixel_size = pixel_size

var tween : Tween

func _ready() -> void:
	if damage_amount == 0: # there is not point showing no damage
		queue_free()
	else:
		activate()


func activate() -> void:
	damage_amount = damage_amount # trigger the setter

	pixel_size = target_pixel_size * remap(damage_amount, 0, max_damage, 2, 8)

	outline_modulate = Color.WHITE
	modulate = damage_gradient.sample(float(damage_amount) / float(max_damage))


	tween = create_tween()

	tween.tween_property(self, "pixel_size", target_pixel_size, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel()
	tween.tween_property(self, "position", position + Vector3.UP * 2, 1.5)
	tween.parallel()
	tween.tween_property(self, "modulate", modulate.darkened(0.5) , 1.5)
	tween.parallel()
	tween.tween_property(self, "outline_modulate", Color.BLACK, 0.1)
	tween.parallel()
	tween.tween_property(self, "transparency", 1, 1).set_delay(0.5)
	tween.finished.connect(queue_free)
	tween.play()
