@tool
extends EditorScenePostImport

# Every dungeon piece embeds the same 1024 atlas. Keep one copy.


func _post_import(scene: Node) -> Object:
	var tex: Texture2D = load("res://assets/models/dungeon/wall_dungeon_texture.png") as Texture2D
	if tex != null:
		_retarget(scene, tex)
	return scene


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
