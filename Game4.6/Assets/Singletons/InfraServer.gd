extends Node

var peer := ENetMultiplayerPeer.new()

#signal infra_connection_issue

@onready var timer = Timer.new()

signal connection_lost
signal connnection_failed
signal connection_ok

func infra_connected():
#	print("Infraserver connection established!")
	peer.set_target_peer(MultiplayerPeer.TARGET_PEER_SERVER) # we're only ever going to talk to the server
	peer.get_peer(MultiplayerPeer.TARGET_PEER_SERVER).set_timeout(1000, 2500, 5000)


func infra_connection_failed():
#	print("Infraserver connection failed. Retrying...")
	peer.close_connection()
	infra_connect()


func infra_disconnected():
#	print("Infraserver connection terminated. Reconnecting...")
	peer.close_connection()
	infra_connect()


func infra_disconnect():
#	print("Disconnecting from InfraServer")
	peer.close_connection()


func infra_connect():
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
#		print("Connecting to InfraServer...")
		var result = peer.create_client(Globals.INFRA_SERVER, Globals.INFRA_PORT)
#		print("Creating client result: ", result)
#	else:
#		print("Already connected to InfraServer!")


func timer_timeout() -> void:
	var server_peer = peer.get_peer(MultiplayerPeer.TARGET_PEER_SERVER)

	if server_peer:
		server_peer.ping()
#		if server_peer.get_state() != ENetPacketPeer.STATE_CONNECTED \
#		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
#			infra_connection_issue.emit()

	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		infra_connect()

# Called when the node enters the scene tree for the first time.
func _ready():
	return # temporary

#	@warning_ignore(return_value_discarded)
	peer.connect(&"connection_succeeded", infra_connected)
#	@warning_ignore(return_value_discarded)
	peer.connect(&"connection_failed", infra_connection_failed)
#	@warning_ignore(return_value_discarded)
	peer.connect(&"server_disconnected", infra_disconnected)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.set_target_peer(MultiplayerPeer.TARGET_PEER_SERVER)

	infra_connect()

	add_child(timer)
	timer.timeout.connect(timer_timeout)
	timer.one_shot = false
	timer.start(1)
