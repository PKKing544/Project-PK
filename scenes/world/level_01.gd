## Attached to the Level01 root node.
## Builds trimesh collision for the baked terrain on first load.
extends Node3D

func _ready() -> void:
	var mesh_inst := $Terrain/TerrainMesh as MeshInstance3D
	var body      := $Terrain/TerrainBody  as StaticBody3D
	var col_node  := $Terrain/TerrainBody/TerrainCollision as CollisionShape3D

	if not mesh_inst or not mesh_inst.mesh:
		push_error("Level01: TerrainMesh or its mesh is missing — did you run bake_level_01_terrain.gd?")
		return

	col_node.shape = mesh_inst.mesh.create_trimesh_shape()
	print("Level01: terrain collision ready.")
