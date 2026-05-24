extends Node
# facilitates storing and fetching arbitrary binary data

# store deleted files away instead of deleting them

enum StorageBackend {TESTING, PRODUCTION}

var backend = StorageBackend.TESTING

var testing_path = "user://storage/"
var testing_dir : DirAccess

var testing_use_trash_can = true
var testing_trash_path = "user://storage_trash/"
var testing_trash_dir : DirAccess
# storage unit -  single file in the Storage pool
#class Unit:
#	var hash : PackedByteArray # hash that is both a checksum of the data, and a UUID for the storage unit
#	var data : PackedByteArray # actual data
#	var created_by : String # usrname_hash
#	var creation_time : float # unix time
#	var last_accessed_time : float # unix time
#	var last_accessed_by : String
#	var accesed_count : int # index

func string_from_hash(data_hash: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(data_hash)


func hash_data(data: PackedByteArray) -> PackedByteArray:
	var hasher = HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(data)
	return hasher.finish()


func _ready():
	if backend == StorageBackend.TESTING:

#		var dir = DirAccess.open(settings_dir)
#		if not dir:
#			DirAccess.make_dir_recursive_absolute(settings_dir)
#			dir = DirAccess.open(settings_dir)

		testing_dir = DirAccess.open(testing_path)
		if not testing_dir:
			DirAccess.make_dir_recursive_absolute(testing_path)
			testing_dir = DirAccess.open(testing_path)

		testing_trash_dir = DirAccess.open(testing_trash_path)
		if not testing_trash_dir:
			DirAccess.make_dir_recursive_absolute(testing_trash_path)
			testing_trash_dir = DirAccess.open(testing_trash_path)



func store(data_hash: PackedByteArray, data: PackedByteArray, created_by: String) -> int:
	if backend == StorageBackend.TESTING:
		var filename = string_from_hash(data_hash)
		if testing_dir.file_exists(filename):
			print("Attempting to store a unit that already exists")
			return ERR_ALREADY_EXISTS

		var unit = {
			"hash" = Marshalls.raw_to_base64(data_hash),
			"data" = Marshalls.raw_to_base64(data),
			"created_by" = created_by,
			"creation_time" = Time.get_unix_time_from_system(),
			"last_accessed_time" = 0.0,
			"last_accessed_by" = "",
			"accessed_count" = 0,
		}

		var file = FileAccess.open(testing_path.path_join(filename),FileAccess.WRITE)
		file.store_string(var_to_str(unit))

		var err = file.get_error()
		if err == OK:
			file.close()
			prints("Storage unit created, filename:", filename)
		else:
			prints("Storage unit creation FAILED, filename:", filename,"; error:", error_string(err))

		return err

	else:
		return ERR_METHOD_NOT_FOUND


func retrieve(data_hash: PackedByteArray, username_hash: String):
	if backend == StorageBackend.TESTING:
		var filename = string_from_hash(data_hash)
		if not testing_dir.file_exists(filename):
			return ERR_DOES_NOT_EXIST

		var file = FileAccess.open(testing_path.path_join(filename),FileAccess.READ_WRITE)
		var unit = str_to_var(file.get_as_text())

		if file.get_error() != OK:
			return file.get_error()

		unit["accessed_count"] += 1
		unit["last_accessed_by"] = username_hash
		unit["last_accessed_time"] = Time.get_unix_time_from_system()

		file.seek(0)
		file.store_var(unit)
		file.close()
		var err = file.get_error()
		if err != OK:
			prints("Storage unit retrieval FAILED, filename:", filename, "; error:", error_string(err))
			return file.get_error()
		else:
			prints("Storage unit retrieved, filename:", filename)
			return Marshalls.base64_to_raw(unit["data"])


func delete(data_hash: PackedByteArray):
	if backend == StorageBackend.TESTING:
		var filename = string_from_hash(data_hash)
		if not testing_dir.file_exists(filename):
			prints("Trying to delete a non-existent file! FileAccessAccessname:", filename)
			return ERR_DOES_NOT_EXIST

		if testing_use_trash_can == false:
			# delete file (no undo!)
			var err = testing_dir.remove(filename)
			if err == OK:
				prints("Storage unit deleted, filename:", filename)
			else:
				prints("Storage unit deletion FAILED, filename:", filename, "; error:", error_string(err))
		else:
			# move file to trash

			# remove old trashed file if the name is already taken
			if testing_trash_dir.file_exists(filename):
				testing_trash_dir.remove(filename)

			var err = testing_dir.rename(testing_path.path_join(filename), testing_trash_path.path_join(filename))
			if err == OK:
				prints("Storage unit trashed, filename:", filename)
			else:
				prints("Storage unit trashing FAILED, filename:", filename, "; error:", error_string(err))
