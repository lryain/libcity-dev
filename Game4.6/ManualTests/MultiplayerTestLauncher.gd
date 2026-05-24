extends Control

var server_process : int
var client_processes : Array[int]


func _on_button_pressed():
	if not $CenterContainer/VBoxContainer/Server.button_pressed and server_process > 0:
		OS.kill(server_process)
		server_process = 0
	elif $CenterContainer/VBoxContainer/Server.button_pressed and server_process <= 0:
		var args = PackedStringArray(["--mute", "--dedicated-host", "MapB"])
		server_process = OS.create_instance(args)

func _on_button_2_pressed():
	var args = PackedStringArray(["--mute", "--join","localhost"])
	var pid = OS.create_instance(args)
	if pid > 0:
		client_processes.append(pid)


func _on_kill_clients_pressed():
	for i in client_processes:
		OS.kill(i)
	client_processes.clear()


func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
