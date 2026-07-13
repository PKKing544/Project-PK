extends Area3D

@export_group("Flight Speeds")
@export var start_speed: float = 35.0
@export var end_speed: float = 10.0
var current_speed: float = 35.0

@export_group("Combat & Lifespan")
@export var damage: float = 20.0
@export var max_life: float = 4.0
@export var homing_strength: float = 1.5 # Radians per second of steering

@export_group("Explosion Settings")
@export var blast_radius: float = 4.0
@export var explosion_duration: float = 0.5

var direction: Vector3 = Vector3.FORWARD
var life_time: float = max_life
var creator: Node3D # The enemy that fired this
var player: Node3D

var exploding: bool = false
var explosion_timer: float = 0.5
var blast_mesh: MeshInstance3D
var has_dealt_aoe_damage: bool = false

@onready var sprite = $SpriteMinisun

func _ready():
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")
	explosion_timer = explosion_duration
	
func _physics_process(delta: float):
	if exploding:
		_process_explosion(delta)
		return

	# Speed curve: start fast, slow down
	var progress = 1.0 - (life_time / max_life)
	current_speed = lerp(start_speed, end_speed, clamp(progress * 2.0, 0.0, 1.0))

	# 1. Homing Logic
	if is_instance_valid(player):
		var target_pos = player.global_position + Vector3(0, 1.0, 0)
		var to_target = (target_pos - global_position).normalized()
		
		# Only home if player is somewhat in front of the projectile
		if direction.dot(to_target) > 0.1:
			# Gently rotate the current direction safely
			direction = direction.lerp(to_target, homing_strength * delta).normalized()

	# 2. Wall Avoidance
	# Disable feelers for the first 0.15 seconds so it doesn't violently bounce backwards if it spawns grazing a wall
	if max_life - life_time > 0.15:
		_apply_wall_avoidance(delta)
			
	global_position += direction * current_speed * delta
	
	life_time -= delta
	if life_time <= 0:
		trigger_explosion()

func _apply_wall_avoidance(delta: float):
	var space = get_world_3d().direct_space_state
	var ray_len = 2.5
	var avoid_vec = Vector3.ZERO
	
	var side_offset = 0.4
	var check_dirs = [
		direction,
		(direction + transform.basis.x * side_offset).normalized(),
		(direction - transform.basis.x * side_offset).normalized(),
		(direction + transform.basis.y * side_offset).normalized(),
		(direction - transform.basis.y * side_offset).normalized()
	]
	
	var excludes = [self.get_rid()]
	if is_instance_valid(creator):
		excludes.append(creator.get_rid())
	for bubble in get_tree().get_nodes_in_group("bubble_shield"):
		if is_instance_valid(bubble):
			excludes.append(bubble.get_rid())
			
	for d in check_dirs:
		var query = PhysicsRayQueryParameters3D.create(global_position, global_position + d * ray_len, 1) # Layer 1 (Env)
		query.exclude = excludes
		
		var res = space.intersect_ray(query)
		if not res.is_empty():
			var hit_normal = res.normal
			var dot = direction.dot(hit_normal)
			
			# If we are heading straight into the wall (dot < -0.6), DON'T try to bounce off!
			# Just let it hit and explode gracefully. We ONLY want to avoid walls if we are grazing them.
			if dot > -0.6:
				var dist = (res.position - global_position).length()
				var weight = 1.0 - (dist / ray_len)
				
				# Push purely outwards from the surface, completely ignoring backward momentum
				var push_dir = hit_normal - direction * dot
				if push_dir.length_squared() > 0.01:
					avoid_vec += push_dir.normalized() * weight
			
	if avoid_vec != Vector3.ZERO:
		# Gently blend avoidance into direction
		var new_dir = direction + avoid_vec.normalized() * 4.0 * delta
		if new_dir.length_squared() > 0.01:
			direction = new_dir.normalized()

func _on_body_entered(body: Node3D):
	if exploding:
		return
	if body == creator:
		return
	if body.is_in_group("enemy") or body.is_in_group("enemy_hurtbox") or body.is_in_group("bubble_shield"):
		return
		
	# Grace period: allow fireball to escape spawn area before wall-destruction kicks in (0.1s)
	if max_life - life_time > 0.1:
		print("FIREBALL IMPACTED: ", body.name)
		trigger_explosion()

func trigger_explosion():
	if exploding: return
	exploding = true
	# Turn off physics safely
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Create yellow explosion mesh immediately
	blast_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = blast_radius
	sphere.height = blast_radius * 2.0
	blast_mesh.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_receive_shadows = true
	blast_mesh.material_override = mat
	
	blast_mesh.scale = Vector3.ZERO
	add_child(blast_mesh)

func _process_explosion(delta: float):
	explosion_timer -= delta
	var progress = 1.0 - (max(explosion_timer, 0.0) / max(explosion_duration, 0.001))
	
	# We must process the AoE damage here in _physics_process, NOT inside _on_body_entered!
	# Querying the physics space state while inside a body_entered signal causes a fatal Godot crash!
	if not has_dealt_aoe_damage:
		has_dealt_aoe_damage = true
		var space = get_world_3d().direct_space_state
		var shape = SphereShape3D.new()
		shape.radius = blast_radius
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = global_transform
		query.collision_mask = 1 | 2 | 4 | 8
		
		var hits = space.intersect_shape(query)
		for hit in hits:
			var body = hit.collider
			if not is_instance_valid(body) or body == creator or body.is_in_group("enemy") or body.is_in_group("enemy_hurtbox"):
				continue
			if body.has_method("take_damage"):
				var push_dir = (body.global_position - global_position).normalized()
				push_dir.y += 0.3
				body.take_damage(damage, push_dir, 600.0, 0.4, 0.1)
	
	if is_instance_valid(blast_mesh):
		var s = clamp(progress * 4.0, 0.0, 1.0)
		blast_mesh.scale = Vector3(s, s, s)
		var mat = blast_mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = lerp(0.6, 0.0, progress)
			
	if is_instance_valid(sprite):
		sprite.scale += Vector3(1, 1, 1) * delta * 8.0 # Make explosion slightly smaller
		sprite.modulate.a = lerp(1.0, 0.0, progress)
		
	if explosion_timer <= 0.0:
		queue_free()
