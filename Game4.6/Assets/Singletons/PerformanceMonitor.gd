extends Node

@export var interval := 1.0
@export var enabled := false

var header = [
		"time",
		"ticks msec",
		"FPS",
		"target FPS",
		"process time msec",
		"physics process time msec",
		"object count",
		"object node count",
		"object orphan node count",
		"object resource count",
		"memory static",
		"memory static max",
		"physics 3D active objects",
		"physics 3D collision pairs",
		"physics 3D island count",
#		"%cpu",
#		"%mem",
		]
var timer = Timer.new()
@onready var log_file_name = "res://performance_monitor_" + Time.get_date_string_from_system() + '_' + Time.get_time_string_from_system() + ".log"
var log_file

func _ready():
	var args = OS.get_cmdline_args()

	for arg in args:
		if arg == "--performance-monitor":
			enabled = true
			print("Performance Monitor logging enabled")
		if enabled:
			interval = str_to_var(arg) as float
			print("Performance Monitor interval set to ", interval, " seconds")
			break

	if enabled == false:
		queue_free()
		return

	print_debug("Creating log file :", log_file_name)

	log_file = FileAccess.open(log_file_name,FileAccess.WRITE)

	log_file.store_csv_line(header)

	self.add_child(timer)
	timer.one_shot = false
	timer.connect(&'timeout', log_datapoint)
	timer.start(interval)
	log_datapoint()

func log_datapoint():
	var values = []
	values.append(Time.get_time_string_from_system())
	values.append(var_to_str(Time.get_ticks_msec()))
	values.append(var_to_str(Performance.get_monitor(Performance.TIME_FPS)))
	values.append(var_to_str(Engine.max_fps))
	values.append(var_to_str(Performance.get_monitor(Performance.TIME_PROCESS)))
	values.append(var_to_str(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)))
	values.append(var_to_str(Performance.get_monitor(Performance.OBJECT_COUNT)))
	values.append(var_to_str(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	values.append(var_to_str(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
	values.append(var_to_str(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
	values.append(var_to_str(Performance.get_monitor(Performance.MEMORY_STATIC)))
	values.append(var_to_str(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)))
	values.append(var_to_str(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)))
	values.append(var_to_str(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)))
	values.append(var_to_str(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)))

#	var output
#	OS.execute("top -n2 -d 0.5 -p " + var_to_str(OS.get_process_id()) + "| awk '{print $9}'", [], output) # %CPU
#	values.append(var_to_str(output[0]))
#
#	OS.execute("top -n2 -d 0.5 -p " + var_to_str(OS.get_process_id()) + "| awk '{print $10}'", [], output) # %MEM
#	values.append(var_to_str(output[0]))

	log_file.store_csv_line(values)

func _exit_tree():
	if log_file:
		log_file.store_line("EOF")
		log_file.flush()
