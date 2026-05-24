# This file facilitates managing Liblast Packages.
# These files esentially contain a Godot PCK file with extra metadata and checksums as well as using compression
# This format will facilitate shipping game content updates, maps, mods and any other content

class_name LiblastPackage extends Node

# Futureproofing
const CURRENT_FORMAT_VERSION = 0

# Zstd does't seem to work, that's why Gzip is used
const CURRENT_COMPRESSION_MODE = FileAccess.COMPRESSION_GZIP

# Liblast Pakcage file name extension
const FILE_NAME_EXTENSION_COMPRESSED = "lpkz"
const FILE_NAME_EXTENSION_UNCOMPRESSED = "lpck"

# short string that signifies the file type in it's header adn footer (reversed)
const FILE_FORMAT_MARKER_COMPRESSED = "LPKZ"
const FILE_FORMAT_MARKER_UNCOMPRESSED = "LPCK"

const DATA_BLOCK_START_MARKER = "DATA"
const METADATA_BLOCK_START_MARKER = "META"

# Various types of packages. Not all types are going to work the same way
enum LiblastPackageType {
	UPDATE, # game update package: impacts game version
	OVERLAY, # game overlay package: should only replace files - eg. hd texture packs etc.
	MAP, # package that adds a single map
	MOD, #
	OTHER,
}

### Liblast Package file format binary layout
#	----+-------+-------+--------------------------------------------------------------------------
#	pos	| bytes	| type	| what
#	----+-------+-------+--------------------------------------------------------------------------
#	0	| 4		| acii	| file format marker: COMpressed or UNCompressed
#		| 1		| int	| file format version
#		| 1		| int	| compression mode (COM only)
#		| 1		| bool	| is a cryptographic signature used?
#		| 8		| int	| data block start offset
#		| 8		| int	| data block compressed size (COM only)
#		| 8		| int	| data block uncompressed size
#		| 8		| int	| metadata block compressed size (COM only)
#		| 8		| int	| metadata block uncompressed size
#		| 32	| bytes	| metadata block sha256 digest
#		| 512	| bytes	| metadata block cryptographic signature (optional)
#		| 4		| ascii	| metadata block start marker
#		| ?		| bytes	| metadata block
#		| 4		| ascii	| data block start marker
#		| ?		| bytes	| data block
#	-4	| 4		| ascii	| file format marker reversed: COMpressed or UNCompressed
#	----+-------+-------+--------------------------------------------------------------------------

class LiblastPackageHeader:
	# stuff needed to read the data this metadata corresponds to
	var is_compressed : bool # is this a compressed or uncompressed package file?
	var compression_mode : int
	var data_offset : int
	var data_compressed_size : int
	var data_uncompressed_size : int
	var metadata_compressed_size : int
	var metadata_uncompressed_size : int
	var metadata_buf_sha256 : PackedByteArray
	var is_signed : bool
	var metadata_buf_signature : PackedByteArray

# information needed to locate, fetch and verify a package
class LiblastPackageReference:
	var package_uid : String = "" # kept the same for all package versions
	var package_release_version : int # incremented with each package release
	var package_data_size : int # used to display download progress and ETA
	var package_data_sha256 : PackedByteArray # unique for each package version, used to verify data integrity

# all metadata describing a Liblast package and the file storing it
class LiblastPackageMetadata:
	var header : LiblastPackageHeader
	# package metadata
	var package_reference #: LiblastPackageReference
	var minimum_liblast_version #: Globals.LiblastVersionNumber # this also means what version this was package made for/with
	var maximum_liblast_version #: Globals.LiblastVersionNumber # the package isn't valid for game versions later than this one
	var package_dependancies : Array#[LiblastPackageReference] # all packages needed for this one to work
	var package_name : String # same fro all package versions
	var package_type : LiblastPackageType
	var package_description : String # description of the package contents to display
	var package_author : String # author name to display
	var package_author_uses_auth : bool # does the author have a Liblast account?
	var package_author_account_uid : String # reference to author's Liblast account
	var package_first_release_unix_time_utc : int # when was the first version published?
	var package_release_unix_time_utc : int # when was current version published?
	var package_release_notes : String # additional information: a changelog, shoutouts, author website link etc.
	var preview_image_webp_data : PackedByteArray # a cover image that will be displayed to identify the package
#	var package_signature_key : String # what key was this signed with?
#	var is_signed : bool = false
#	var data_signature : PackedByteArray
#	var metadata_signature : PackedByteArray


static func generate_package_uid() -> String:
	var crypto = Crypto.new()
	var uid : String
	var time : PackedByteArray

	uid = Marshalls.raw_to_base64(crypto.generate_random_bytes(6))
	time.resize(6)
	time.encode_u32(0, Time.get_unix_time_from_system() * ( 1 << 28))
	uid += "-" + Marshalls.raw_to_base64(time).left(4)

	print("Generated UID ", uid)
	return uid


# decode the Image resource from WEBP block stored in the metadata object
static func get_preview_image_from_metadata(metadata: LiblastPackageMetadata):
	var image = Image.new()
	image.load_webp_from_buffer(metadata.preview_image_webp_data)
	return image


# fetch metadata from a file
static func load_metadata_from_file(filename : String, crypto_key : CryptoKey):
	var header = LiblastPackageHeader.new()

	# always first check for uncompressed files - they should take precedence
	if filename.ends_with("." + FILE_NAME_EXTENSION_UNCOMPRESSED):
		print("File extension indicates an uncompressed file")
		header.is_compressed = false
	elif filename.ends_with("." + FILE_NAME_EXTENSION_COMPRESSED):
		print("File extension indicates a compressed file")
		header.is_compressed = true
	else:
		print("No valid file extension provied in file name")
		# always first check for uncompressed files - they should take precedence
		if FileAccess.file_exists(filename + "." + FILE_NAME_EXTENSION_UNCOMPRESSED):
			filename = filename + "." + FILE_NAME_EXTENSION_UNCOMPRESSED
			print("Found uncompressed package ", filename)
			header.is_compressed = false
		elif FileAccess.file_exists(filename + "." + FILE_NAME_EXTENSION_COMPRESSED):
			filename = filename + "." + FILE_NAME_EXTENSION_COMPRESSED
			print("Found compresssed package ", filename)
			header.is_compressed = true
		else:
			print("Can't find any package files matching file name ", filename)

	print("Opening file ", filename)

#	var package_filename = filename + '.' + FILE_NAME_EXTENSION
	var file = FileAccess.open(filename, FileAccess.READ)

	# read the file type marker
	var buf : PackedByteArray = file.get_buffer(4)

	match buf.get_string_from_ascii():
		FILE_FORMAT_MARKER_COMPRESSED:
			header.is_compressed = true
			print("File is compressesd - needs uncompressing before use")
		FILE_FORMAT_MARKER_UNCOMPRESSED:
			header.is_compressed = false
			print("File is uncompressesd - can be used readily")
		_:
			printerr("Cannot open Liblast Package file - unrecognized file marker!")
			return ERR_FILE_UNRECOGNIZED

	# file format version
	var format_version = file.get_8()

	if format_version > CURRENT_FORMAT_VERSION:
		printerr("Cannot open Liblast Package file - file format version is ", format_version, " while highest supported is ", CURRENT_FORMAT_VERSION, "!")
		return ERR_FILE_MISSING_DEPENDENCIES

	if header.is_compressed:
		# compression mode - irrelevant for uncompressed files
		header.compression_mode = file.get_8()
		print("Data compression mode used is ", header.compression_mode)

	header.is_signed = file.get_8() as bool

	# data block offset
	header.data_offset = file.get_64()
	print("Data block start offset is ", header.data_offset)

	if header.is_compressed:
		header.data_compressed_size = file.get_64()
		print("Read data compressed size: ", header.data_compressed_size)
	header.data_uncompressed_size = file.get_64()
	print("Read data uncompressed size: ", header.data_uncompressed_size)

	# metadata block size
	if header.is_compressed:
		header.metadata_compressed_size = file.get_64()
		print("Read metadata compressed size: ", header.metadata_compressed_size)
	header.metadata_uncompressed_size = file.get_64()
	print("Read metadata uncompressed size: ", header.metadata_uncompressed_size)

	print("Reading metadata SHA256 digest at pos ", file.get_position())
	header.metadata_buf_sha256 = file.get_buffer(256 / 8)
	print("Finished reading metadata SHA256 digest at pos ", file.get_position())

	if header.is_signed:
		print("Reading metadata signature at pos ", file.get_position())
		header.metadata_buf_signature = file.get_buffer(4096 / 8)
		print("Finished reading metadata signature at pos ", file.get_position())

	print("Reading metadata block start marker at pos ", file.get_position())
	var metadata_marker = file.get_buffer(4)
	if metadata_marker != METADATA_BLOCK_START_MARKER.to_ascii_buffer():
		print("Cannot open Liblast Package file - metadata block start marker not found")
		return ERR_FILE_CORRUPT
	print("OK")
	var metadata_buf : PackedByteArray
	print("Reading metadata at pos ", file.get_position())
	metadata_buf = file.get_buffer(header.metadata_compressed_size if header.is_compressed else header.metadata_uncompressed_size)
	print("Finished reading metadata at pos ", file.get_position())
	print("Metadata buffer size: ", metadata_buf.size())

	# verify the digest
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(metadata_buf)
	var metadata_buf_sha256 = ctx.finish()
	print("Metadata sha256 buffer:\n", metadata_buf_sha256)
	if not header.metadata_buf_sha256 == metadata_buf_sha256:
		printerr("Cannot open Liblast Package file - metadata block SHA256 checksum mismatch!")
		return ERR_FILE_CORRUPT
	print("OK")

	if header.is_signed:
		print("Verifying signature...")
		var crypto = Crypto.new()
		if not crypto.verify(HashingContext.HASH_SHA256, header.metadata_buf_sha256, header.metadata_buf_signature, crypto_key):
			printerr("Cannot open Liblast Package file - metadata block signature verification failed!")
			return ERR_UNAUTHORIZED
		else:
			print("OK")

	var metadata : LiblastPackageMetadata

	if header.is_compressed:
		metadata = dict_to_inst(bytes_to_var(metadata_buf.decompress(header.metadata_uncompressed_size, header.compression_mode)))
	else: # the data isn't compressed, despite the variable name
		metadata = dict_to_inst(bytes_to_var(metadata_buf))

	# deserializing reference object
	metadata.package_reference = dict_to_inst(metadata.package_reference)

	# deserializing Liblast version objects
	if metadata.maximum_liblast_version is Dictionary:
		metadata.maximum_liblast_version = dict_to_inst(metadata.maximum_liblast_version)
	if metadata.minimum_liblast_version is Dictionary:
		metadata.minimum_liblast_version = dict_to_inst(metadata.minimum_liblast_version)

	if not metadata is LiblastPackageMetadata:
		printerr("Cannot open Liblast Package file - metadata block parsing failed!")
		return ERR_FILE_CORRUPT

	file.seek_end(-4)
	var footer : PackedByteArray = file.get_buffer(4)
	footer.reverse()
	if not footer in [FILE_FORMAT_MARKER_COMPRESSED.to_ascii_buffer(),\
	FILE_FORMAT_MARKER_UNCOMPRESSED.to_ascii_buffer()]:
		printerr("Cannot open Liblast Package file - file was truncated!")
		return ERR_FILE_EOF

	metadata.header = header
	return metadata


static func write_metadata_to_file(file: FileAccess, metadata: LiblastPackageMetadata):
	pass



#static func decompress_file(filename : String, metadata: LiblastPackageMetadata):
#	assert(metadata.header.is_compressed, "Attempting to decompress an uncompressed package file!")
#
#	# read the compressed data
#	var package_filename = filename + '.' + FILE_NAME_EXTENSION_COMPRESSED
#	var file = FileAccess.open(package_filename, FileAccess.READ)
#	file.seek(metadata.header.data_offset)
#	var pack_data_compressed = file.get_buffer(metadata.header.data_compresssed_size)
#	file.close()
#
#	# verify the checksum (this will also ensure that the provided metadata matches the data from file)
#	var data_ctx = HashingContext.new()
#	data_ctx.start(HashingContext.HASH_SHA256)
#	data_ctx.update(pack_data_compressed)
#	var data_compressed_sha256 = data_ctx.finish()
#	if metadata.package_reference.package_data_sha256 != data_compressed_sha256:
#		printerr("Cannot decompress Liblast Package file - data block SHA256 checksum mismatch!")
#		print("Calculated checksum: ", data_compressed_sha256)
#		print("Expected checksum: ", metadata.package_reference.package_data_sha256)
#		return ERR_FILE_CORRUPT
#
#	# decompress data
#	var pack_data : PackedByteArray
#	pack_data = pack_data_compressed.decompress(metadata.header.data_uncompresssed_size, metadata.header.compression_mode)
#
#	# now create a new decompressed file
#
#	var uncompressed_package_filename = filename + FILE_NAME_EXTENSION_UNCOMPRESSED
#	file = FileAccess.open(uncompressed_package_filename, FileAccess.WRITE)
#
#	file.store_buffer(pack_data)


# extract the PCK part of the Liblast Package and load it into the game
static func load_data_from_file(filename : String, metadata: LiblastPackageMetadata):
	pass
	# first let's check if the file's data is compressd or not
	# pick file name based on metadata
#	var package_filename = filename + '.' + FILE_NAME_EXTENSION_COMPRESSED if metadata.header.is_compressed\
#	else FILE_NAME_EXTENSION_COMPRESSED
#	if FileAccess.file_exists(filename + '.' + FILE_NAME_EXTENSION_COMPRESSED):
#		package_filename = filename + '.' + FILE_NAME_EXTENSION_COMPRESSED
#		print("File's extension indicates compressed package")
#	elif FileAccess.file_exists(filename + '.' + FILE_NAME_EXTENSION_UNCOMPRESSED):
#		print("File's extension indicates uncompressed package")

#	var package_filename_temp = package_filename + ".temp"
#	var file = FileAccess.open(package_filename, FileAccess.READ)
#	var err : int
#	err = file.get_error()
#	if err != OK:
#		printerr("Failed to open package file ", filename, ". Error: ", error_string(err))
#		return err
#
#	file.seek(metadata.header.data_offset)
#	err = file.get_error()
#	if err != OK:
#		printerr("Failed to open package file ", filename, ". Error: ", error_string(err))
#		return err
#
#	var pack_data_compressed = file.get_buffer(metadata.header.data_compresssed_size)
#	file.close()
#
#	var data_ctx = HashingContext.new()
#	data_ctx.start(HashingContext.HASH_SHA256)
#	data_ctx.update(pack_data_compressed)
#	var data_compressed_sha256 = data_ctx.finish()
#	if metadata.package_reference.package_data_sha256 != data_compressed_sha256:
#		printerr("Cannot open Liblast Package file - data block SHA256 checksum mismatch!")
#		print("Calculated checksum: ", data_compressed_sha256)
#		print("Expected checksum: ", metadata.package_reference.package_data_sha256)
#		return ERR_FILE_CORRUPT
#
#	var pack_data : PackedByteArray
#	if metadata.header.is_compressed:
#		pack_data = pack_data_compressed.decompress(metadata.header.data_uncompressed_size, metadata.header.compression_mode)
#	else: # no compression was used
#		pack_data = pack_data_compressed
#
#	var data_package_filename = filename + '.pck'
#	file = FileAccess.open(data_package_filename,FileAccess.WRITE)
#	file.store_buffer(pack_data)
#
#	ProjectSettings.load_resource_pack(data_package_filename)


static func save_to_file(filename: String, metadata: LiblastPackageMetadata, pack_data: PackedByteArray, crypto_key : CryptoKey):
	var package_filename = filename + '.' + (FILE_NAME_EXTENSION_COMPRESSED if metadata.header.is_compressed else FILE_NAME_EXTENSION_UNCOMPRESSED)

	var file = FileAccess.open(package_filename, FileAccess.WRITE)

	### header
	# marker - 4 bytes
	file.store_buffer((FILE_FORMAT_MARKER_COMPRESSED if metadata.header.is_compressed else FILE_FORMAT_MARKER_UNCOMPRESSED).to_ascii_buffer())
	# format version - 1 byte
	file.store_8(CURRENT_FORMAT_VERSION)
	# compression mode - 1 byte
	if metadata.header.is_compressed:
		file.store_8(CURRENT_COMPRESSION_MODE)

	# should we expect a cryptographic signature as part of the header?
	file.store_8(metadata.header.is_signed)

	var pack_data_buf : PackedByteArray
	if metadata.header.is_compressed:
		pack_data_buf = pack_data.compress(CURRENT_COMPRESSION_MODE)
	else:
		pack_data_buf = pack_data

	var data_ctx = HashingContext.new()
	data_ctx.start(HashingContext.HASH_SHA256)
	data_ctx.update(pack_data_buf)
	var data_buf_sha256 = data_ctx.finish()

	metadata.package_reference.package_data_size = pack_data_buf.size()
	metadata.package_reference.package_data_sha256 = data_buf_sha256

	# SERIALIZATION
	# reference object
	metadata.package_reference = inst_to_dict(metadata.package_reference)

	# dependancies
	var deps_serialized = []
	for i in metadata.package_dependancies:
		deps_serialized.append(inst_to_dict(i))
	metadata.package_dependancies = deps_serialized

	# Liblast versions
	if is_instance_valid(metadata.maximum_liblast_version):
		metadata.maximum_liblast_version = inst_to_dict(metadata.maximum_liblast_version)
	if is_instance_valid(metadata.minimum_liblast_version):
		metadata.minimum_liblast_version = inst_to_dict(metadata.minimum_liblast_version)

	var metadata_buf : PackedByteArray

	# take the header out of the metadata block so we can create the signature
#	var metadata_header = metadata.header
#	var metadata_minus_header = metadata
#	metadata_minus_header.header = null

	if metadata.header.is_signed:
		# ensuring that the signature is empty before we create, hash and sign the metadata block
		metadata.header.metadata_buf_signature = []

	# creating the metadata binary buffer
	if metadata.header.is_compressed:
		metadata_buf = var_to_bytes(inst_to_dict(metadata)).compress(CURRENT_COMPRESSION_MODE)
		print("Prepared compressed metadata buffer")
	else:
		metadata_buf = var_to_bytes(inst_to_dict(metadata))
		print("Prepared uncompressed metadata buffer")

	print("Metadata buffer size:\n", metadata_buf.size())

	var data_offset : int = file.get_position()
	if metadata.header.is_compressed:
		data_offset += (64 / 8) * 2 # compressed sizes of metadata and data blocks

	data_offset += (64 / 8) * 3
	data_offset += (256 / 8) # metadata sha356
	if metadata.header.is_signed:
		data_offset += (4096 / 8) # metadata signature of 512 bytes
	data_offset += 4 # metadata marker
	data_offset += metadata_buf.size() # metadata size

	print("Writing data offset: ", data_offset)
	file.store_64(data_offset)

	if metadata.header.is_compressed:
		print("Writing (compressed) data size: ", metadata.package_reference.package_data_size)
		file.store_64(metadata.package_reference.package_data_size)
	print("Writing uncompressed data size: ", pack_data.size())
	file.store_64(pack_data.size())

	if metadata.header.is_compressed:
		print("Writing (compressed) metadata size: ", metadata_buf.size())
		file.store_64(metadata_buf.size())
	print("Writing uncompressed metadata size: ", var_to_bytes(inst_to_dict(metadata)).size())
	file.store_64(var_to_bytes(inst_to_dict(metadata)).size())

	print("Finished writing header at file pos ", file.get_position())

	# metadata SHA256
	var metadata_ctx = HashingContext.new()
	metadata_ctx.start(HashingContext.HASH_SHA256)
	metadata_ctx.update(metadata_buf)
	# because metadata_buf was already created adding this won't affect hashing and signing
	metadata.header.metadata_buf_sha256 = metadata_ctx.finish()
	print("Metadata sha256 buffer:\n", metadata.header.metadata_buf_sha256)
	print("Writing metadata SHA-256 digest at file pos ", file.get_position())
	file.store_buffer(metadata.header.metadata_buf_sha256)
	print("Finished writing metadata SHA-256 digest at file pos ", file.get_position())

	# creating the metadata cryptographic signature
	if metadata.header.is_signed:
		print("Signing the metadata block with crypto key ", crypto_key)
		assert(is_instance_valid(crypto_key), "No valid crypto key provided for signing Liblast Package")
		var crypto = Crypto.new()
		metadata.header.metadata_buf_signature = crypto.sign(HashingContext.HASH_SHA256, metadata.header.metadata_buf_sha256, crypto_key)
#		print("Signture: ", metadata.header.metadata_buf_signature)
		print("Writing metadata signature of size ", metadata.header.metadata_buf_signature.size())
		file.store_buffer(metadata.header.metadata_buf_signature)
		print("Finished writing signature at file pos ", file.get_position())

	print("Writing metadata block start marker at pos ", file.get_position())
	file.store_buffer(METADATA_BLOCK_START_MARKER.to_ascii_buffer())
	print("Writing metadata at pos ", file.get_position())
	file.store_buffer(metadata_buf)
	print("Finished writing metadata at file pos ", file.get_position())

	assert(file.get_position() == data_offset, "Predicted data offset is different from the actual one")

	print("Writing data block start marker at pos ", file.get_position())
	file.store_buffer(DATA_BLOCK_START_MARKER.to_ascii_buffer())
	print("Writing data block at pos ", file.get_position())
	file.store_buffer(pack_data_buf)
	print("Finished writing data at file pos ", file.get_position())

	# store reverse file marker to signify the file end - this allows quickly checking if the file wasn't truncated
	var footer : PackedByteArray = (FILE_FORMAT_MARKER_COMPRESSED if metadata.header.is_compressed else FILE_FORMAT_MARKER_UNCOMPRESSED).to_ascii_buffer()
	footer.reverse()
	file.store_buffer(footer)

	print("Finished writing file footer at pos ", file.get_position())
	file.close()

#	ProjectSettings.load_resource_pack()


#@export var pkg_name : String
#@export var pkg_release_version : int
#@export var pkg_scene_md5 : String
#@export var pkg_scene_filename : String
#@export var pkg_package_size : int # map package size in KB
#var pkg_dependancies : Array[LiblastPackage.LiblastPackageMetadata]
#@export var pkg_description : String
#@export var pkg_author : String
#@export var pkg_credits : String
#@export var pkg_thumbnail : Image

