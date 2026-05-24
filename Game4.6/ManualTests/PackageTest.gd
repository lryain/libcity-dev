extends Control

var key : CryptoKey

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_pressed():
	var metadata := LiblastPackage.LiblastPackageMetadata.new()
	var reference := LiblastPackage.LiblastPackageReference.new()
	reference.package_uid = LiblastPackage.generate_package_uid()
	reference.package_release_version = 1

	metadata.package_reference = reference

	metadata.package_author = "unfa"
	metadata.package_name = "test"
	metadata.package_first_release_unix_time_utc = Time.get_unix_time_from_system()
	metadata.minimum_liblast_version = Globals.build_version

	var header = LiblastPackage.LiblastPackageHeader.new()
	header.is_compressed = $Save/Compress.button_pressed
	header.is_signed = $Save/Sign.button_pressed

	metadata.header = header

	var image = Image.load_from_file("res://Assets/Effects/BloodParticles_normal.png")
	image.resize(256, 256,Image.INTERPOLATE_LANCZOS)
	metadata.preview_image_webp_data = image.save_webp_to_buffer(true, 0.95)

	var package_filename_temp = "package_data.temp"
	var packer = PCKPacker.new()
	packer.pck_start(package_filename_temp)
	packer.add_file("res://version", "version")
	packer.add_file("res://Assets/Maps/DM1-2.tscn", "Assets/Maps/DM1-2.tscn")
	packer.add_file("res://Assets/Materials/Generic/Rock_01_Tileable.tres", "Assets/Materials/Generic/Rock_01_Tileable.tres")
	packer.add_file("res://Assets/Singletons/Globals.gd", "Assets/Singletons/Globals.gd")
	packer.add_file("res://Assets/LiblastPackage.gd", "Assets/LiblastPackage.gd")
	packer.add_file("res://LiblastPackage.gd", "LiblastPackage.gd")
	packer.add_file("res://Main.gd", "Main.gd")
	var err
	err = packer.flush(true)
	print("Finished creating PCK temp file with status ", error_string(err))


	var pack_data = FileAccess.get_file_as_bytes(package_filename_temp)

	var diraccess = DirAccess.open("res://")
	diraccess.remove(package_filename_temp)
#	var data : PackedByteArray
#	data.resize(4)
#	data.append_array("$$$$".to_ascii_buffer())

	key = CryptoKey.new()
	err = key.load("local_user_key")
	print("Loaded crypto key with result ", error_string(err))
	assert(err == OK, "Error loading crypto key for signing")
	LiblastPackage.save_to_file("test_package", metadata, pack_data, key)


func _on_load_pressed():
	key = CryptoKey.new()
	var err = key.load("local_user_key")
	print("Loaded crypto key with result ", error_string(err))
	assert(err == OK, "Error loading crypto key for signing")
	var metadata = LiblastPackage.load_metadata_from_file("test_package." + ("lpkz" if $Save/Compress.button_pressed else "lpck"), key)
	print("Read Liblast Package Metadata: ")
	$MetadataLabel.text = var_to_str(metadata)

	if not metadata is LiblastPackage.LiblastPackageMetadata:
		print("Error ", error_string(metadata))
		return

	var texture = ImageTexture.create_from_image(LiblastPackage.get_preview_image_from_metadata(metadata))
	$Load/TextureRect.texture = texture

	LiblastPackage.load_data_from_file("test_package." + ("lpkz" if $Save/Compress.button_pressed else "lpck"), metadata)


func _on_create_rsa_key_pressed():
	var crypto = Crypto.new()
	key = crypto.generate_rsa(4096)
	var err = key.save("liblast.key")
	print("Saved crypto key with result ", error_string(err))
	assert(err == OK, "Error saving crypto key for signing")
	err = key.save("liblast.pub", true)
	print("Saved crypto .pub key with result ", error_string(err))
	assert(err == OK, "Error saving crypto .pub key for signing")


func _on_load_rsa_key_pressed():
	key = CryptoKey.new()
	var err = key.load("local_user_key")
	print("Loaded crypto key with result ", error_string(err))
	assert(err == OK, "Error loading crypto key for signing")
