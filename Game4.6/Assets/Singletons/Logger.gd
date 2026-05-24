extends Node

var log_dir := 'user://liblast_logs/'
var log_file : FileAccess


func _ready() -> void:
	# make sure the log directory exists
	var dir = DirAccess.open(log_dir)
	if not dir:
		DirAccess.make_dir_recursive_absolute(log_dir)
	var filename = Time.get_datetime_string_from_system(false, true).replace(':', '').replace(' ', '_') + ".log"
	print("Log file name: ", filename)
	log_file = FileAccess.open(log_dir.path_join(filename),FileAccess.WRITE)
	if not log_file:
		printerr("Can't open log file for writing: ", filename)
		return
	# write header
	var line : String = "%-19s %12s | %s" %\
	["SYSTEM TIME", "TICKS_MSEC", "EVENT"]
	log_file.store_line(line)
	if log_file.get_error() != OK:
		printerr("Can't write to log file: ", filename)
		return
	event(["Liblast log start"])


func event(message: Array) -> void:
	if not log_file: # no log file available
		printerr("Cant write to log file: ", message)
		return

	var combined_message : String = ""

	for i in message:
		combined_message += str(i)

	var line : String = "%s %12d | %s" %\
		[Time.get_datetime_string_from_system(false, true), Time.get_ticks_msec(),str(combined_message)]
	log_file.store_line(line)
	log_file.flush()
	print_rich("[i] · " + line + "[/i]")

func _exit_tree():
	event(["Liblast log finish"])
