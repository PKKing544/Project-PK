extends StaticBody3D
class_name BubbleShield

var has_bubble: bool = true # So the player/projectiles recognize it as a bubble
var target: Node3D:
	set(val):
		target = val
		_update_bubble_size()
var visuals: MeshInstance3D
var collision: CollisionShape3D

func _ready():
	add_to_group("bubble_shield")
	var radius = 1.6
	if target and is_instance_valid(target) and "bubble_radius" in target:
		radius = target.bubble_radius
		
	visuals = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	visuals.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0, 0.4) # Transparent blue
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.3, 0.8)
	mat.emission_energy_multiplier = 0.5
	visuals.material_override = mat
	add_child(visuals)
	
	collision = CollisionShape3D.new()
	var col_shape = SphereShape3D.new()
	col_shape.radius = radius
	collision.shape = col_shape
	add_child(collision)
	
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, false)

func _update_bubble_size():
	if not target or not is_instance_valid(target): return
	
	var radius = 1.6
	if "bubble_radius" in target:
		radius = target.bubble_radius
		
	if visuals and visuals.mesh is SphereMesh:
		visuals.mesh.radius = radius
		visuals.mesh.height = radius * 2.0
		
	if collision and collision.shape is SphereShape3D:
		collision.shape.radius = radius

func take_damage(_amount: float, _f_dir: Vector3 = Vector3.ZERO, _f_raw: float = 0.0, _iframe_dur: float = 0.8, _min_stun: float = 0.05):
	pass # Absorbs damage from projectiles directly!

func heal(_amount: float):
	pass # Bubbles do not get healed

func preview_damage(_amount: float):
	pass

func _process(_delta: float):
	if target and is_instance_valid(target):
		global_position = target.global_position
		
		# Scale visual to fit target
		var s = 1.0
		if "scale" in target:
			s = (target.scale.x + target.scale.y + target.scale.z) / 3.0
		visuals.scale = Vector3.ONE * s
		collision.scale = Vector3.ONE * s
	else:
		queue_free()
