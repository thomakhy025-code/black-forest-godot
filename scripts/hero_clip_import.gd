@tool
extends EditorScenePostImport

# The rigs ship with 76 clips. The match plays these and no others.
const KEEP := {
	"Idle": true,
	"Unarmed_Idle": true,
	"Walking_A": true,
	"Walking_B": true,
	"Walking_C": true,
	"Running_A": true,
	"Running_B": true,
	"Spellcasting": true,
	"Blocking": true,
	"Interact": true,
	"2H_Melee_Idle": true,
	"Death_A": true,
	"Dodge_Forward": true,
	"Jump_Full_Short": true,
	"Use_Item": true,
	"Spellcast_Shoot": true,
	"1H_Melee_Attack_Chop": true,
	"Unarmed_Melee_Attack_Punch_A": true,
	"Hit_A": true,
}


func _post_import(scene: Node) -> Object:
	_drop_clips(scene)
	var src := get_source_file()
	if src.ends_with("Rogue_Hooded.glb"):
		var tex: Texture2D = load("res://assets/models/characters/Rogue_rogue_texture.png") as Texture2D
		if tex != null:
			_retarget(scene, tex)
	return scene


func _drop_clips(node: Node) -> void:
	if node is AnimationPlayer:
		var anim := node as AnimationPlayer
		var libs: PackedStringArray = anim.get_animation_library_list()
		for lib_name in libs:
			var library: AnimationLibrary = anim.get_animation_library(lib_name)
			if library == null:
				continue
			var names: PackedStringArray = library.get_animation_list()
			var drop := PackedStringArray()
			for clip_name in names:
				if not KEEP.has(clip_name):
					drop.append(clip_name)
			for clip_name2 in drop:
				library.remove_animation(clip_name2)
	for child in node.get_children():
		_drop_clips(child)


func _retarget(node: Node, tex: Texture2D) -> void:
	var meshes: Array = []
	if node is MeshInstance3D:
		meshes.append(node)
	meshes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for mesh in meshes:
		var mi := mesh as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var count := mi.mesh.get_surface_count()
		for index in count:
			var mat: Material = mi.mesh.surface_get_material(index)
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).albedo_texture = tex
