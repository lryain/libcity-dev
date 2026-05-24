class_name PlayerList
# List of players

var players = {}


func erase(pid) -> void:
	players.erase(pid)


func set_item(pid: int, info: PlayerInfo) -> void:
	players[pid] = info


func get_item(pid: int) -> PlayerInfo:
	if players.has(pid):
		return players[pid]
	else:
		return PlayerInfo.new()
