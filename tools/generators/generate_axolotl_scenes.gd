extends SceneTree

func _init():
	_make_fireball()
	_make_axolotl()
	quit()

func _make_fireball():
	var root = Area3D.new()
	root.name = "Fireball"
	var script = load("res://scripts/enemies/projectiles/fireball.gd")
	root.set_script(script)
	
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.5
	col.shape = sphere
	root.add_child(col)
	col.owner = root
	col.name = "CollisionShape"
	
	var mesh = MeshInstance3D.new()
	var smesh = SphereMesh.new()
	smesh.radius = 0.5
	smesh.height = 1.0
	mesh.mesh = smesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.0)
	mat.emission_energy_multiplier = 3.0
	smesh.material = mat
	root.add_child(mesh)
	mesh.owner = root
	mesh.name = "Mesh"
	
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/enemies/fireball.tscn")

func _make_axolotl():
	var root = CharacterBody3D.new()
	root.name = "AxolotlEnemy"
	var script = load("res://scripts/enemies/axolotl_enemy.gd")
	root.set_script(script)
	
	# Main body
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.5, 0.5, 2.0)
	col.shape = box
	root.add_child(col)
	col.owner = root
	col.name = "BodyCollision"
	
	var bmesh = MeshInstance3D.new()
	var mb = BoxMesh.new()
	mb.size = Vector3(1.5, 0.5, 2.0)
	bmesh.mesh = mb
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.1, 0.4, 0.6) # Swampert blue
	mb.material = bmat
	root.add_child(bmesh)
	bmesh.owner = root
	bmesh.name = "BodyMesh"
	
	# Head Pivot
	var head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 0.5, -1.0)
	root.add_child(head_pivot)
	head_pivot.owner = root
	head_pivot.name = "HeadPivot"
	
	# Sweet spot
	var sweet_spot = StaticBody3D.new()
	sweet_spot.name = "SweetSpotHitbox"
	var sweet_script = load("res://scripts/enemies/sweet_spot.gd")
	sweet_spot.set_script(sweet_script)
	head_pivot.add_child(sweet_spot)
	sweet_spot.owner = root
	
	var hcol = CollisionShape3D.new()
	var hbox = BoxShape3D.new()
	hbox.size = Vector3(1.0, 0.8, 1.0)
	hcol.shape = hbox
	sweet_spot.add_child(hcol)
	hcol.owner = root
	hcol.name = "HeadCollision"
	
	var hmesh = MeshInstance3D.new()
	var mhbox = BoxMesh.new()
	mhbox.size = Vector3(1.0, 0.8, 1.0)
	hmesh.mesh = mhbox
	var hmat = StandardMaterial3D.new()
	hmat.albedo_color = Color(0.8, 0.4, 0.2) # Swampert orange gills/accents
	mhbox.material = hmat
	head_pivot.add_child(hmesh)
	hmesh.owner = root
	hmesh.name = "HeadMesh"
	
	# Mouth Fireball
	var mf = MeshInstance3D.new()
	mf.position = Vector3(0, 0, -0.6)
	var msph = SphereMesh.new()
	msph.radius = 0.4
	msph.height = 0.8
	mf.mesh = msph
	var fmat = StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.0, 0.0) # RED
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.2, 0.0)
	fmat.emission_energy_multiplier = 4.0
	msph.material = fmat
	head_pivot.add_child(mf)
	mf.owner = root
	mf.name = "MouthFireball"
	
	# Flamethrower Area
	var farea = Area3D.new()
	farea.position = Vector3(0, 0, -4.5)
	head_pivot.add_child(farea)
	farea.owner = root
	farea.name = "FlamethrowerArea"
	
	var facol = CollisionShape3D.new()
	var facbox = BoxShape3D.new()
	facbox.size = Vector3(3.0, 3.0, 8.0)
	facol.shape = facbox
	farea.add_child(facol)
	facol.owner = root
	facol.name = "CollisionShape"
	
	var fmesh = MeshInstance3D.new()
	var fmbox = BoxMesh.new()
	fmbox.size = Vector3(3.0, 3.0, 8.0)
	fmesh.mesh = fmbox
	var fmm = StandardMaterial3D.new()
	fmm.albedo_color = Color(1.0, 0.5, 0.0, 0.4)
	fmm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmm.emission_enabled = true
	fmm.emission = Color(1.0, 0.3, 0.0)
	fmbox.material = fmm
	farea.add_child(fmesh)
	fmesh.owner = root
	fmesh.name = "FlamethrowerMesh"
	
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/enemies/axolotl_enemy.tscn")
