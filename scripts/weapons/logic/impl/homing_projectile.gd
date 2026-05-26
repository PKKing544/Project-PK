extends BaseProjectile
class_name HomingProjectile

var snap_distance: float = 3.0
var has_snapped: bool = false
var target_enemy: Node3D = null

func _physics_process(delta: float):
	if not compiled_mode: return
	
	if not has_snapped:
		_check_for_snap()
		
	if has_snapped and is_instance_valid(target_enemy):
		# Target is valid, calculate direction to target
		var dir_to_target = (target_enemy.global_position - global_position).normalized()
		move_dir = dir_to_target
		fall_velocity = 0.0 # disable gravity after snap
		
	super._physics_process(delta)

func _check_for_snap():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = snap_distance
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	
	if shooter is CollisionObject3D:
		query.exclude = [shooter.get_rid()]
		
	var results = space_state.intersect_shape(query)
	var closest_dist = snap_distance + 1.0
	var closest_enemy = null
	
	for res in results:
		var collider = res.collider
		if collider and collider.has_method("take_damage") and collider != shooter:
			var dist = global_position.distance_to(collider.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_enemy = collider
				
	if closest_enemy:
		target_enemy = closest_enemy
		has_snapped = true
