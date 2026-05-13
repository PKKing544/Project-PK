## Attach this to any Node3D that has the structure:
##   TerrainMesh  (MeshInstance3D with a baked ArrayMesh)
##   TerrainBody/TerrainCollision  (StaticBody3D / CollisionShape3D)
##
## On _ready it builds the trimesh collision automatically.
extends Node3D

func _ready() -> void:
	var mesh_inst := $TerrainMesh as MeshInstance3D
	var col_node  := $TerrainBody/TerrainCollision as CollisionShape3D

	if not mesh_inst or not mesh_inst.mesh:
		push_error("BakedTerrain (%s): TerrainMesh or mesh resource is missing!" % name)
		return

	col_node.shape = mesh_inst.mesh.create_trimesh_shape()
	print("BakedTerrain (%s): collision ready." % name)
