### Based on file: https://gist.github.com/AndreaCatania/afd01671e35e9d004d1d7a498fc0e2a3 (licensed under MIT)
### Modified for Liblast, relicensed under AGPL.
##
## This Post Import script automatically assigns the
## material to the Mesh if it's found inside the
## `res://materials` directory.
##
## # How to use
## To you use it, you need to set this script as Post Import script
## on the file.fbx or file.glb.
##
## Your `materials` directory can look like:
##   res://materials/iron_mat.material
##   res://materials/glass_mat.tres
##   res://materials/my_asset_kit_1/abc_mat.material
##   res://materials/my_asset_kit_1/asd_mat.tres

@tool
extends EditorScenePostImport

const materials_dir = "res://Assets/Materials"

func _post_import(scene):
#	print("Post import start")
	## Process the scene
	apply_global_material(scene)
	return scene

func apply_global_material(node):
	if node == null:
		return

	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			# Extract the material name
			var material_name = node.mesh.get("surface_" + str(i + 1) + "/name")
			var mat = search_material(material_name)
			if mat != null:
				node.mesh.surface_set_material(i, mat)
#				print("Global material set for: ", material_name, " ", mat)

	for child in node.get_children():
		apply_global_material(child)


var materials: Dictionary = {}

func search_material(material_name, _base_dir = materials_dir) -> Material:
	if materials.has(material_name):
		return materials[material_name]

	return _search_material(material_name)


func _search_material(material_name, base_dir = materials_dir) -> Material:
	var dir = DirAccess.open(base_dir)
	if dir:
		# Search the file inside this directory
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() == false:
				if file_name == material_name + ".tres" or file_name == material_name + ".material":
					var mat: Material = load(base_dir + "/" + file_name)
					if mat != null:
						# This material is valid, cache it since it's likely it's reused.
						materials[material_name] = mat
#						print("Material found: ", material_name, " in path: ", base_dir + "/" + file_name)
						return mat
#					else:
#						print("IMPORT ERROR: The material ", material_name, " is found, but it's not valid material.")
			file_name = dir.get_next()
		dir.list_dir_end()

		# Search inside sub dirs now
		dir.list_dir_begin()
		file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and file_name != "." and file_name != "..":
				var mat = _search_material(material_name, base_dir + "/" + file_name)
				if mat != null:
					return mat
			file_name = dir.get_next()
		dir.list_dir_end()
#	else:
#		print_debug("Can't open material library directory!")
	# Nothing found
	return null
