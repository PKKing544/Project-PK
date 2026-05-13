extends StaticBody3D

var health: float = 1000000.0 # Effectively unkillable
var mesh_instance: MeshInstance3D
var label: Label3D

var damage_history: Array = [] # Stores {time: float, amount: float}
var dps_window: float = 1.0

# Reaction visuals
var base_material: StandardMaterial3D
var flash_timer: float = 0.0

func _ready():
	# 1. Mesh
	mesh_instance = MeshInstance3D.new()
	var cap_mesh = CapsuleMesh.new()
	cap_mesh.radius = 0.5
	cap_mesh.height = 2.0
	mesh_instance.mesh = cap_mesh
	
	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.8, 0.2, 0.2)
	cap_mesh.material = base_material
	add_child(mesh_instance)
	
	# 2. Collision
	var col = CollisionShape3D.new()
	var col_shape = CapsuleShape3D.new()
	col_shape.radius = 0.5
	col_shape.height = 2.0
	col.shape = col_shape
	add_child(col)
	
	# 3. Text Label
	label = Label3D.new()
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = Vector3(0, 1.5, 0)
	label.text = "DPS: 0\nTotal: 0"
	add_child(label)

func take_damage(amount: float, _force_dir: Vector3 = Vector3.ZERO, _raw_force: float = 0.0, _iframe_dur: float = 0.8, _min_stun: float = 0.05):
	health -= amount
	var current_time = Time.get_ticks_msec() / 1000.0
	damage_history.append({"time": current_time, "amount": amount})
	
	# Trigger hit reaction
	flash_timer = 0.1
	mesh_instance.position = Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))

func _process(delta: float):
	# Reaction logic
	if flash_timer > 0:
		flash_timer -= delta
		base_material.emission_enabled = true
		base_material.emission = Color(1.0, 1.0, 1.0)
		base_material.emission_energy_multiplier = 2.0
	else:
		base_material.emission_enabled = false
		mesh_instance.position = Vector3.ZERO
		
	# DPS logic
	var current_time = Time.get_ticks_msec() / 1000.0
	var valid_history = []
	var current_dps = 0.0
	
	for hit in damage_history:
		if current_time - hit.time <= dps_window:
			valid_history.append(hit)
			current_dps += hit.amount
			
	label.text = "HP: 1M\nDPS: %d" % int(current_dps)
	# clean up history periodically
	if damage_history.size() > 500:
		damage_history = valid_history
