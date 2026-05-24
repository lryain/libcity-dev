extends HBoxContainer

@onready var label = $Status
@onready var icon = $Icon
#var icon_no_auth = preload("res://Assets/Badges/Textures/Badge_NoAuth.png")
#var icon_auth = preload("res://Assets/Badges/Textures/Badge_Auth.png")

func auth_changed(enabled):
	if InfraServer.peer.get_connection_status() ==  MultiplayerPeer.CONNECTION_CONNECTED:
		if enabled:
			label.text = "[i][color=#44aa44]logged in as[/color][/i] [b]{0}[/b]" \
				.format([MultiplayerState.auth_username])
#			icon.texture = icon_auth
#		else:
#			label.text = "[i]no account[/i]"
#			icon.texture = icon_no_auth


func infra_connection_failed() -> void:
	label.text = "[i][color=#aa4444]offline"


func infra_connection_succeeded() -> void:
	label.text = "[i][color=#44aa44]online"


func infra_server_disconnected() -> void:
	label.text = "[i][color=#aa4444]connection lost"


#func infra_connection_issue() -> void:
#	label.text = "[i][color=#aaaa44]connection interrupted"

# Called when the node enters the scene tree for the first time.
func _ready():
	MultiplayerState.auth_changed.connect(auth_changed)
#	InfraServer.peer.connection_failed.connect(infra_connection_failed)
#	InfraServer.peer.connection_succeeded.connect(infra_connection_succeeded)
#	InfraServer.peer.server_disconnected.connect(infra_server_disconnected)
#	InfraServer.infra_connection_issue.connect(infra_connection_issue)

	label.text = "[i][color=444444]connecting..."
