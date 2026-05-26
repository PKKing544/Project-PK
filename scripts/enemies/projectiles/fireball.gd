extends Area3D

var speed: float = 20.0
var damage: float = 20.0
var direction: Vector3 = Vector3.FORWARD
var life_time: float = 4.0
var creator: Node3D # The enemy that fired this

@export var homing_strength: float = 1.5 # Radians per second of steering
var player: Node3D

func _ready():
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")
	
func _physics_process(delta: float):
	# 1. Homing Logic
	if is_instance_valid(player):
		var target_pos = player.global_position + Vector3(0, 1.0, 0)
		var to_target = (target_pos - global_position).normalized()
		
		# Only home if player is somewhat in front of the projectile (dot > 0)
		if direction.dot(to_target) > 0.1:
			# Gently rotate the current direction towards the player
			var current_q = Quaternion(Basis.looking_at(direction))
			var target_q = Quaternion(Basis.looking_at(to_target))
			var lerped_q = current_q.slerp(target_q, homing_strength * delta)
			direction = Basis(lerped_q).z * -1.0 # Basis.z is backward in Godot

	# 2. Wall Avoidance
	_apply_wall_avoidance(delta)
			
	global_position += direction * speed * delta
	
	life_time -= delta
	if life_time <= 0:
		queue_free()

func _apply_wall_avoidance(delta: float):
	var space = get_world_3d().direct_space_state
	var ray_len = 3.0
	var avoid_vec = Vector3.ZERO
	
	# Cast 5 rays: Straight, and slightly Left, Right, Up, Down
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
			# Push direction away from the collision point
			var dist = (res.position - global_position).length()
			var weight = 1.0 - (dist / ray_len)
			avoid_vec += res.normal * weight
			
	if avoid_vec != Vector3.ZERO:
		# Blend avoidance into direction
		direction = (direction + avoid_vec * 4.0 * delta).normalized()

func _on_body_entered(body: Node3D):
	if body == creator:
		return
	if body.is_in_group("enemy") or body.is_in_group("enemy_hurtbox") or body.is_in_group("bubble_shield"):
		return
		
	if body.has_method("take_damage"):
		var push_dir = direction
		push_dir.y += 0.2
		body.take_damage(damage, push_dir.normalized(), 520.0, 0.4, 0.1)
		
	queue_free()
