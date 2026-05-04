extends Node
class_name ShotResolver

@export var hitscan_collision_mask: int = 1
@export var player_camera: Camera3D
@export var muzzle_point: Node3D

func resolve_shot(compiled_mode: FireModeData, charge_ratio: float = 1.0, shot_count: int = 1):
	# Fire 'pellet_count' times
	for i in range(compiled_mode.pellet_count):
		# Calculate random spread here
		var aim_dir = get_aim_direction(compiled_mode.spread_deg)
		
		# For hitscan: calculate via RayCast
		if compiled_mode.fire_type == FireModeData.FireType.HITSCAN:
			_resolve_hitscan(compiled_mode, aim_dir, charge_ratio)
		else:
			_resolve_projectile(compiled_mode, aim_dir, charge_ratio)
			
	# Apply Kickback logic to Player (Normal kickback)
	if compiled_mode.kickback_force > 0:
		var shooter = get_parent().get_parent()
		if shooter and shooter.has_method("apply_kickback"):
			var base_dir = get_aim_direction(0.0)
			var mult = max(1.0, 2.0 * charge_ratio) # Scales up to 2x based on charge
			shooter.apply_kickback(-base_dir * (compiled_mode.kickback_force * mult))

	# Apply Reactive Kickback (Wall/Floor push)
	if compiled_mode.reactive_kickback_force > 0 and shot_count >= compiled_mode.reactive_kickback_threshold:
		_resolve_reactive_kickback(compiled_mode)

func _resolve_reactive_kickback(mode: FireModeData):
	var start = muzzle_point.global_position
	var aim_dir = get_aim_direction(0.0)
	var end = start + aim_dir * mode.reactive_kickback_range
	
	var space_state = muzzle_point.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start, end)
	query.collision_mask = hitscan_collision_mask
	
	var shooter = get_parent().get_parent()
	if shooter is CollisionObject3D:
		query.exclude = [shooter.get_rid()]
		
	var result = space_state.intersect_ray(query)
	if result:
		# We hit a surface nearby! Push the player away from the aim direction
		if shooter and shooter.has_method("apply_kickback"):
			shooter.apply_kickback(-aim_dir * mode.reactive_kickback_force)

func get_aim_direction(spread_deg: float) -> Vector3:
	if not player_camera or not muzzle_point: return Vector3.FORWARD
	
	var screen_center = get_viewport().get_visible_rect().size / 2
	var cam_origin = player_camera.project_ray_origin(screen_center)
	var cam_dir = player_camera.project_ray_normal(screen_center)
	var camera_target = cam_origin + cam_dir * 100.0
	
	var space_state = player_camera.get_world_3d().direct_space_state
	var cam_query = PhysicsRayQueryParameters3D.create(cam_origin, camera_target)
	cam_query.collide_with_bodies = true
	
	var shooter = get_parent().get_parent()
	if shooter is CollisionObject3D:
		cam_query.exclude = [shooter.get_rid()]
		
	var cam_result = space_state.intersect_ray(cam_query)
	
	var final_target = camera_target
	if cam_result:
		final_target = cam_result.position
		
	var base_dir = (final_target - muzzle_point.global_position).normalized()
	
	# Apply spread
	if spread_deg > 0:
		var offset_x = randf_range(-1.0, 1.0)
		var offset_y = randf_range(-1.0, 1.0)
		var offset_z = randf_range(-1.0, 1.0)
		var rand_vec = Vector3(offset_x, offset_y, offset_z).normalized()
		var spread_rad = deg_to_rad(spread_deg)
		base_dir = base_dir.lerp(rand_vec, min(spread_rad, 1.0)).normalized()
		
	return base_dir

func _resolve_hitscan(mode: FireModeData, aim_dir: Vector3, charge_ratio: float = 1.0):
	var start = muzzle_point.global_position
	var end = start + aim_dir * mode.range_m
	
	var space_state = muzzle_point.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start, end)
	query.collision_mask = hitscan_collision_mask
	
	var shooter = get_parent().get_parent()
	if shooter is CollisionObject3D:
		query.exclude = [shooter.get_rid()]
		
	var result = space_state.intersect_ray(query)
	
	var final_end = end
	if result:
		final_end = result.position
		var collider = result.collider
		
		# Preview damage to scale final lethal hits accurately
		if collider.has_method("preview_damage"):
			collider.preview_damage(mode.damage)
			
		# Apply Effects FIRST (so knockback calculates based on pre-damage HP)
		for effect in mode.hit_effects:
			if effect.has_method("apply_effect"):
				effect.apply_effect(collider, result.position, result.normal, aim_dir, charge_ratio, mode.damage)
			
		# Deal Damage or Healing
		if mode.heals_target:
			if collider.has_method("heal"):
				collider.heal(mode.damage)
		else:
			if collider.has_method("take_damage"):
				collider.take_damage(mode.damage)
			
	# Render Beam (Temporary FX)
	_draw_beam(start, final_end)

func _resolve_projectile(mode: FireModeData, aim_dir: Vector3, charge_ratio: float = 1.0):
	if not mode.projectile_scene:
		push_warning("Attempted to fire projectile but no scene assigned!")
		return
		
	var proj = mode.projectile_scene.instantiate()
	get_tree().root.add_child(proj)
	
	# Shifting the projectile slightly forward to avoid self-collision
	proj.global_position = muzzle_point.global_position + aim_dir * 0.5
	
	if proj.has_method("initialize"):
		proj.initialize(aim_dir, mode, get_parent().get_parent(), charge_ratio)

func _draw_beam(start: Vector3, end: Vector3):
	var mesh_instance = MeshInstance3D.new()
	var cyl_mesh = CylinderMesh.new()
	cyl_mesh.top_radius = 0.03
	cyl_mesh.bottom_radius = 0.03
	cyl_mesh.height = start.distance_to(end)
	mesh_instance.mesh = cyl_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.0, 0.4) 
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.0, 0.7)
	mat.emission_energy_multiplier = 3.0
	cyl_mesh.material = mat
	
	get_tree().root.add_child(mesh_instance)
	mesh_instance.global_position = start.lerp(end, 0.5)
	
	var up = Vector3.UP
	if (end - start).normalized().abs().y > 0.99:
		up = Vector3.RIGHT 
	mesh_instance.look_at(end, up)
	mesh_instance.rotate_object_local(Vector3.RIGHT, PI/2.0)
	
	var timer = mesh_instance.get_tree().create_timer(0.05)
	timer.timeout.connect(mesh_instance.queue_free)
