extends Control

#@onready var aplayer = $AnimationPlayer

@onready var hit_sprite = $Hit
@onready var kill_sprite = $Kill

@onready var hit_sfx = $HitSound
@onready var kill_sfx = $KillSound

@export var hit_marker_color := Color(1, 0.5, 0)
@export var kill_marker_color := Color(1, 0, 0)


func hit():
	var sprite : TextureRect = hit_sprite.duplicate()

	add_child(sprite)
	sprite.modulate = hit_marker_color
	sprite.show()

	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(hit_marker_color, 0), 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel()
	tween.tween_property(sprite, "scale", Vector2.ONE * 1.5, 0.25)
	tween.finished.connect(sprite.queue_free)
	tween.play()

	hit_sfx.play()


func kill():
	var sprite : TextureRect = kill_sprite.duplicate()

	add_child(sprite)
	sprite.modulate = kill_marker_color
	sprite.show()

	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(kill_marker_color, 0), 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel()
	tween.tween_property(sprite, "scale", Vector2.ONE * 2, 0.5)
	tween.finished.connect(sprite.queue_free)
	tween.play()

	kill_sfx.play()


func _ready() -> void:
	hit_sprite.hide()
	kill_sprite.hide()
