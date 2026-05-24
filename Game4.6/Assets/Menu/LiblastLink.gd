extends LinkButton

@export var url = "https://libla.st"

@onready var shadow = $Shadow


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_liblast_link_pressed() -> void:
	OS.shell_open(url)


func _on_mouse_entered() -> void:
	shadow.hide()


func _on_mouse_exited() -> void:
	shadow.show()
