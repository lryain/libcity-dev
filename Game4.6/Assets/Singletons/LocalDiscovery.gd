extends Node

const HEADER = "Liblast Local Discovery"
const EXPIRATION_TIME : float = 5000 # miliseconds; time a host is considered online if no packets were recieved

var interval : float = 3 # time between send_recieve updates seconds

var peer = PacketPeerUDP.new()

var tween : Tween

var discovered_peers : Dictionary = {}

signal update # emitted after the discovered_peers dictionary gets updated


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	peer.set_broadcast_enabled(true)
	# send to all devices in the local network
	peer.set_dest_address("192.168.0.255", Globals.LOCAL_DISCOVERY_PORT)
	peer.bind(Globals.LOCAL_DISCOVERY_PORT)

	tween = create_tween()
	tween.set_loops(0)
	tween.tween_interval(interval)
	tween.chain()
	tween.tween_method(send_and_recive, null, null, 0)

	# start the cycle only if it's desired
	if Settings.get_var("host_local_discovery"):
		tween.play()


func enable():
	if tween:
		if not tween.is_running():
			tween.play()


func disable():
	if tween.is_running():
		tween.pause()


func send_and_recive(_arg = null):
#	print("Availble packets: ", peer.get_available_packet_count())
	while peer.get_available_packet_count() > 0:
		var rcv = peer.get_var()
		if rcv is Array:
			if rcv[0] == HEADER:
#				print("Recieved a discovery UDP packet")
				if rcv[1].pid != OS.get_process_id(): # ensure we're not processing our own packet
					if rcv[1].available: # add to list
						rcv[1]["expiration_time"] = Time.get_ticks_msec() + EXPIRATION_TIME
						discovered_peers[peer.get_packet_ip()] = rcv[1]
					else: # remove from list
						if discovered_peers.find_key(peer.get_packet_ip()):
							discovered_peers.erase(peer.get_packet_ip())

	var snd = [
	HEADER,
	{
		"name" : MultiplayerState.user_character_profile.display_name,
		"role" : MultiplayerState.role,
		"pid" : OS.get_process_id(),
#			"mid" : OS.get_unique_id(),
		"available" : true,
	}
	]
#	print("Broadcasting discovery UDP packet")
	peer.put_var(snd)
	update.emit()


func _exit_tree() -> void:
	# send the goodbye packet only if the feature is enabled
	if not Settings.get_var("host_local_discovery"):
		return

	var buf = [
		HEADER,
		{
			"name" : MultiplayerState.user_character_profile.display_name,
			"role" : MultiplayerState.role,
			"pid" : OS.get_process_id(),
#			"mid" : OS.get_unique_id(),
			"available" : false,
		}
		]

	peer.put_var(buf)
	await( get_tree().create_timer(0.25).timeout )
	# give the packet time to leave
	peer.close()
