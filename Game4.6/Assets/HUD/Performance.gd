extends RichTextLabel

#@onready var main = get_tree().root.get_node("Node3D")

# Timestamps of frames rendered in the last second
var times := []

# Frames per second
var fps := 0



func _process(delta) -> void:
	if MultiplayerState.role == Globals.MultiplayerRole.NONE:
		text = "Offline"
	elif MultiplayerState.role in [Globals.MultiplayerRole.SERVER, Globals.MultiplayerRole.DEDICATED_SERVER]:
		text = "Hosting · "
		var peers = get_tree().get_multiplayer().get_peers().size()
		if peers == 0:
			text += "no peers"
		elif peers == 1 :
			text += "1 peer"
		else:
			text += str(peers) + " peers"
	elif MultiplayerState.role == Globals.MultiplayerRole.CLIENT:
		text = "Connected · "
		var own_peer = MultiplayerState.peer.get_peer(get_multiplayer_authority())

		var ping = own_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		var packet_loss = own_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)
		text += str(ping) + " ms · " + str(packet_loss)

		# propagate this info
#
#		var local_pid = get_multiplayer_authority()
#		if MultiplayerState.local_character and main.player_list.players.has(local_pid):
#			main.player_list.players[local_pid].ping = ping
#			main.player_list.players[local_pid].packet_loss = packet_loss
#			main.push_local_player_info()


	text += "\nFPS: %s" % str(get_realtime_fps())
	if Engine.max_fps != 0:
		text += " (%s max)" % str(Engine.max_fps)

#	text += "\n{0}\n[color=#8888ff][b][url={1}]{1}[/url][/b][/color]".format([
#		str(Settings.version),
#		"code.libla.st"
#		])

#func _on_performance_meta_clicked(meta: String):
#	# meta: Link to the project which is placed within the url tag
#	# Opens the link in the default browser on click
#	OS.shell_open(meta)

func get_realtime_fps() -> int:
	var now := Time.get_ticks_msec()

	# Remove frames older than 1 second in the `times` array
	while times.size() > 0 and times[0] <= now - 1000:
		times.pop_front()

	times.append(now)
	return times.size()

