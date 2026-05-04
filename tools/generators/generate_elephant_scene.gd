extends SceneTree

func _init():
	var root = CharacterBody3D.new()
	root.name = "ElephantEnemy"
	root.set_script(load("res://scripts/enemies/elephant_enemy.gd"))
	
	# Elephant Body
	var body_mesh = MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.6
	capsule.height = 1.5
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.4, 0.8)
	capsule.material = mat
	body_mesh.mesh = capsule
	root.add_child(body_mesh)
	body_mesh.owner = root
	
	# Cloud
	var cloud_mesh = MeshInstance3D.new()
	cloud_mesh.name = "CloudMesh"
	var sphere = SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 0.5
	var cmat = StandardMaterial3D.new()
	cmat.albedo_color = Color(0.9, 0.9, 1.0)
	sphere.material = cmat
	cloud_mesh.mesh = sphere
	cloud_mesh.position = Vector3(0, -0.6, 0)
	root.add_child(cloud_mesh)
	cloud_mesh.owner = root
	
	# Collision
	var col = CollisionShape3D.new()
	col.name = "CollisionShape"
	var cap_shape = CapsuleShape3D.new()
	cap_shape.radius = 0.6
	cap_shape.height = 1.5
	col.shape = cap_shape
	root.add_child(col)
	col.owner = root
	
	# Vision Cone Mesh
	var cone = MeshInstance3D.new()
	cone.name = "VisionCone"
	var cm = CylinderMesh.new()
	cm.top_radius = 0.0 # Pointy end
	cm.bottom_radius = 25.0 * tan(deg_to_rad(30.0)) # 60 degree cone
	cm.height = 25.0
	
	var cone_mat = StandardMaterial3D.new()
	cone_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.15) # Transparent faint red
	cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.material = cone_mat
	
	cone.mesh = cm
	
	# We want the tip of the cone at the elephant, projecting forward (-Z)
	# By default CylinderMesh is centered on Y axis.
	# We need to rotate it so it points down -Z, and offset it by half its height
	cone.rotation_degrees = Vector3(90, 0, 0)
	cone.position = Vector3(0, 0, -12.5) # Half of 25.0 height
	root.add_child(cone)
	cone.owner = root
	
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/enemies/elephant_enemy.tscn")
	
	print("Scene generated successfully.")
	quit()
