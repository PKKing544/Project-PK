extends Node3D

## Attach this script to any imported GLB/GLTF scene node.
## It will automatically generate trimesh collision for every MeshInstance3D child at runtime.

func _ready():
	# Wait one frame for the scene tree to be fully loaded
	await get_tree().process_frame
	_generate_collision_recursive(self)
	print("Auto-collision: Generated collision for '", name, "'")

func _generate_collision_recursive(node: Node):
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh:
			var static_body = StaticBody3D.new()
			static_body.name = child.name + "_Col"
			
			# Create trimesh shape from mesh faces
			var faces = child.mesh.get_faces()
			if faces.size() > 0:
				var shape = ConcavePolygonShape3D.new()
				shape.set_faces(faces)
				
				var col_shape = CollisionShape3D.new()
				col_shape.shape = shape
				
				static_body.add_child(col_shape)
				child.add_child(static_body)
			
		_generate_collision_recursive(child)
