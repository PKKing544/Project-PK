@tool
extends BaseEnemy

@export_group("AI Settings")
@export var threat_radius: float = 40.0
@export var fire_radius: float = 20.0
@export var melee_radius: float = 8.0

@export_group("Attack Settings")
@export var projectile_speed: float = 40.0
@export var charge_time: float = 1.8
@export var fire_delay: float = 1.0
@export var fireball_damage: float = 20.0
@export var flamethrower_dps: float = 8.0
@export var projectile_spread: float = 0.08 # Max radians of random spread

@export_group("Wall Cling & Visuals")
@export var visuals_scale: float = 3.0
@export var max_extend_dist: float = 0.05
@export var extend_speed: float = 4.0
@export var surface_alignment_speed: float = 10.0
@export var default_body_dist: float = 0.5
@export var local_body_center: Vector3 = Vector3(0, -0.65, -0.2)
@export var minisun_offset: Vector3 = Vector3(0, -0.3, -0.26)
@export var flipped_tail_x_offset: float = 0.08
@export var editor_snap_to_surface: bool = true:
	set(val):
		editor_snap_to_surface = val
		if Engine.is_editor_hint() and editor_snap_to_surface and is_inside_tree() and not _is_snapping:
			_is_snapping = true
			_editor_snap_to_surface()
			_is_snapping = false


enum State { SLEEP, CHARGING, FLAMETHROWER }
var current_state: State = State.SLEEP

var charge_timer: float = 0.0
var fireball_charged: bool = false

var last_known_player_pos: Vector3 = Vector3.ZERO
var hold_fireball_timer: float = 0.0
var head_physics: CharacterBody3D

# Nodes
var visuals: Node3D
var sprite_body: Sprite3D
var sprite_tail: Sprite3D
var sprite_head: Sprite3D
var sprite_whiskers: Sprite3D
var head_pivot: Node3D
var aim_pivot: Node3D
var mouth_fireball: Node3D
var sweet_spot: Node3D
var flamethrower_area: Area3D
var flamethrower_mesh: MeshInstance3D
var head_material: StandardMaterial3D
var head_collision: CollisionShape3D = null

# Visual helpers
var default_head_pos: Vector3 = Vector3(0, -0.35, -0.5)
var default_tail_pos: Vector3 = Vector3(0.216, -0.299, -0.105)
var default_tail_offset: Vector3 = Vector3.ZERO
var surface_normal: Vector3 = Vector3.UP
var current_charge_raise: float = 0.0
var editor_helper: Node3D = null
var _first_frame: bool = true
var _is_snapping: bool = false

var platform_node: Node3D = null
var last_platform_global_transform: Transform3D

# Preloaded scenes — avoid synchronous load() on every shot
const FIREBALL_SCENE = preload("res://scenes/enemies/fireball.tscn")
const ORB_SCENE      = preload("res://systems/pickups/pickup_orb.tscn")

func _ready():
	outline_use_billboard = false
	super._ready()
	bubble_radius = 4.5
	# 6. Viewport Alignment & Platform Tracking (Editor Tool Mode & Root Alignment)

	# Transitioned to @tool mode so placement changes calculate and display in real-time.
	# Initialized surface_normal to match editor-placed local Y-axis to prevent snapping.
	# Changed alignment logic to rotate the root CharacterBody3D node itself, ensuring child 
	# coordinate spaces remain clean and alignment gizmos reflect the physical surface.
	surface_normal = global_transform.basis.y.normalized()
	max_extend_dist = abs(max_extend_dist)
	if max_extend_dist < 1.0: max_extend_dist = 6.0 # Fallback if it was too small
	
	if Engine.is_editor_hint():
		set_notify_transform(true)
		_create_editor_helper()
	else:
		head_physics = CharacterBody3D.new()
		head_physics.collision_layer = 0
		head_physics.collision_mask = 1 # Environment
		var col = CollisionShape3D.new()
		var shape = SphereShape3D.new()
		shape.radius = 0.6
		col.shape = shape
		head_physics.add_child(col)
		add_child(head_physics)
		head_physics.position = default_head_pos
	
	visuals = get_node_or_null("Visuals")
	if visuals:
		head_pivot = visuals.get_node_or_null("HeadPivot")
		sprite_body = visuals.get_node_or_null("SpriteBody")
		sprite_tail = visuals.get_node_or_null("SpriteTail")
		
		if sprite_body: sprites.append(sprite_body)
		if sprite_tail: sprites.append(sprite_tail)
		if head_pivot:
			for child in head_pivot.get_children():
				if child is Sprite3D and child.name != "SpriteMiniSun":
					sprites.append(child)
		
	if sprite_tail:
		default_tail_pos = sprite_tail.position
		sprite_tail.transform.basis = Basis().rotated(Vector3.UP, PI)
		
	if head_pivot:
		default_head_pos = head_pivot.position
		
	if sprite_tail and head_pivot:
		default_tail_offset = default_tail_pos - default_head_pos
		
	if head_pivot:
		# Shift head sprites forward to prevent clipping with the body, center Y to the pivot
		sprite_head = head_pivot.get_node_or_null("SpriteHead")
		if sprite_head:
			sprite_head.position = Vector3(0, 0, -0.25)
		sprite_whiskers = head_pivot.get_node_or_null("SpriteWhiskers")
		if sprite_whiskers:
			sprite_whiskers.position = Vector3(0, 0, -0.27)
		var sprite_minisun = head_pivot.get_node_or_null("SpriteMiniSun")
		if sprite_minisun:
			sprite_minisun.position = minisun_offset
			
		sweet_spot = head_pivot.get_node_or_null("SweetSpotHitbox")
		if sweet_spot and sweet_spot is CollisionObject3D:
			sweet_spot.collision_mask = 0 # Prevents the head from colliding with the floor
			head_collision = sweet_spot.get_node_or_null("HeadCollision")
			
			if not Engine.is_editor_hint():
				sweet_spot.get_parent().remove_child(sweet_spot)
				if aim_pivot: aim_pivot.add_child(sweet_spot)
				else: add_child(sweet_spot)
			
		# SpriteMiniSun replaces the old sphere mesh — same scale-based charge animation
		mouth_fireball = head_pivot.get_node_or_null("SpriteMiniSun")
		if not mouth_fireball:
			mouth_fireball = head_pivot.get_node_or_null("MouthFireball")
		flamethrower_area = head_pivot.get_node_or_null("FlamethrowerArea")
		if flamethrower_area:
			# Fix pivot dynamically so we can rotate the flamethrower from the head
			var current_pos = flamethrower_area.position
			flamethrower_area.position = Vector3.ZERO
			for child in flamethrower_area.get_children():
				if child is Node3D:
					child.position.z += (current_pos.z / flamethrower_area.scale.z)
					child.position.y += (current_pos.y / flamethrower_area.scale.y)
					child.position.x += (current_pos.x / flamethrower_area.scale.x)
					
			flamethrower_mesh = flamethrower_area.get_node_or_null("FlamethrowerMesh")
			if not flamethrower_area.body_entered.is_connected(_on_flame_body_entered):
				flamethrower_area.body_entered.connect(_on_flame_body_entered)
			if not flamethrower_area.area_entered.is_connected(_on_flame_area_entered):
				flamethrower_area.area_entered.connect(_on_flame_area_entered)
			
		var hb = head_pivot.get_node_or_null("HeadMesh")
		if hb and hb.mesh:
			head_material = hb.mesh.surface_get_material(0)
			if not head_material: head_material = hb.mesh.material
			if head_material:
				mesh_materials.append(head_material)
			
	if mouth_fireball: mouth_fireball.scale = Vector3.ZERO
	if flamethrower_area: flamethrower_area.monitoring = false
	if flamethrower_mesh: flamethrower_mesh.visible = false
	
	_refresh_outlines()

func head_hit(amount: float):
	if is_dead: return
	
	if fireball_charged:
		# EXPLOSION!
		amount *= 1.8 # Incredible damage
		fireball_charged = false
		charge_timer = 0.0
		if mouth_fireball: mouth_fireball.scale = Vector3.ZERO
		
		if knockback_comp:
			var kb_dir = (global_position - head_pivot.global_position).normalized()
			if kb_dir.length_squared() < 0.1: kb_dir = Vector3.UP
			kb_dir = (kb_dir + Vector3.UP * 0.5).normalized()
			knockback_comp.apply_knockback(kb_dir, 150000.0)
			
	take_damage(amount, Vector3.ZERO, 0.0)

func _update_debug_label():
	var txt = "[ Axolotl | HP: %d ]\n" % int(hp)
	if is_dead: txt = "[ K.O. ]\n"
	if fireball_charged: txt += "(Fireball Ready!)\n"
	debug_label.text = txt

func _apply_movement(delta: float):
	# Stick to surface (turret behavior)
	if not is_on_floor() and not is_on_wall() and not is_on_ceiling():
		velocity.y -= 9.8 * delta
		velocity.x = 0
		velocity.z = 0
	else:
		# Ground the enemy and apply a tiny glue velocity to keep collision flags updated
		# without causing sliding/drifting on slopes or curved surfaces.
		velocity = -surface_normal * 0.05
		
	move_and_slide()
	
	if is_on_floor():
		surface_normal = get_floor_normal()
	elif is_on_wall():
		surface_normal = get_wall_normal()
	elif get_slide_collision_count() > 0:
		surface_normal = get_slide_collision(0).get_normal()
	elif is_on_ceiling():
		surface_normal = Vector3.DOWN

func _process_ai(delta: float):
	if not player:
		player = get_tree().get_first_node_in_group("player") 
		if not player: return
	
	var dist_to_player = global_position.distance_to(player.global_position)
	
	if dist_to_player > threat_radius:
		current_state = State.SLEEP
	elif dist_to_player <= melee_radius:
		current_state = State.FLAMETHROWER
	else:
		current_state = State.CHARGING

	_execute_state_logic(delta, dist_to_player)

var _los_excludes_cache: Array[RID] = []
var _los_excludes_timer: float = 0.0

# Raycast from head to player centre — returns true if nothing blocks the path.
func _has_line_of_sight() -> bool:
	if not head_pivot or not player: return false
	var from = head_pivot.global_position
	var to   = player.global_position + Vector3(0, 1.0, 0)
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	
	if _los_excludes_cache.is_empty() or _los_excludes_timer <= 0.0:
		_los_excludes_cache.clear()
		if player: _los_excludes_cache.append(player.get_rid())
		for node in get_tree().get_nodes_in_group("enemy"):
			_los_excludes_cache.append(node.get_rid())
			for child in node.get_children():
				if child is CollisionObject3D:
					_los_excludes_cache.append(child.get_rid())
					for grandchild in child.get_children():
						if grandchild is CollisionObject3D:
							_los_excludes_cache.append(grandchild.get_rid())
			# Also exclude bubble shields
			if node.get("current_bubble_node") and is_instance_valid(node.current_bubble_node):
				_los_excludes_cache.append(node.current_bubble_node.get_rid())
		# Exclude enemy_hurtbox group too (SweetSpotHitbox etc)
		for node in get_tree().get_nodes_in_group("enemy_hurtbox"):
			if node is CollisionObject3D:
				_los_excludes_cache.append(node.get_rid())
		_los_excludes_timer = 0.5
		
	query.exclude = _los_excludes_cache
	
	var result = space.intersect_ray(query)
	return result.is_empty()

func _track_player(delta: float):
	if _los_excludes_timer > 0.0:
		_los_excludes_timer -= delta
		
	if Engine.is_editor_hint() or not head_physics or not visuals: return
	
	var has_los = _has_line_of_sight()
	var player_node = player if is_instance_valid(player) else get_tree().get_first_node_in_group("player")
	
	if current_state != State.SLEEP:
		if player_node and has_los:
			last_known_player_pos = player_node.global_position + Vector3(0, 1.0, 0)
			
		var target_pos = last_known_player_pos if last_known_player_pos != Vector3.ZERO else (player_node.global_position + Vector3(0, 1.0, 0) if player_node else global_position)
		if aim_pivot:
			aim_pivot.look_at(target_pos, global_transform.basis.y)
			
		if flamethrower_area and current_state == State.FLAMETHROWER:
			# Rotate flamethrower to track player
			flamethrower_area.look_at(target_pos, global_transform.basis.y)
			# Clamp the pitch so it only looks up/down slightly (e.g., +/- 30 degrees)
			var rot = flamethrower_area.rotation
			rot.x = clamp(rot.x, deg_to_rad(-30.0), deg_to_rad(30.0))
			flamethrower_area.rotation = rot
		elif flamethrower_area:
			# Reset flamethrower rotation when not firing
			flamethrower_area.rotation = flamethrower_area.rotation.lerp(Vector3.ZERO, delta * 5.0)
			
		var target_local = to_local(target_pos)
		var to_target_local = target_local - local_body_center
		
		# Actively move up and down to match player's Y position
		var ideal_head_pos = local_body_center
		ideal_head_pos.y = target_local.y
			
		# Stretch horizontally towards the player
		var dir_xz = Vector3(to_target_local.x, 0, to_target_local.z)
		if dir_xz.length_squared() > 0.01:
			dir_xz = dir_xz.normalized()
			ideal_head_pos += dir_xz * max_extend_dist
			
		var global_ideal = to_global(ideal_head_pos)
		
		var move_dir = (global_ideal - head_physics.global_position)
		if move_dir.length() > 0.01:
			head_physics.velocity = move_dir * extend_speed
		else:
			head_physics.velocity = Vector3.ZERO
			
		head_physics.move_and_slide()
		
		# Clamp distance
		var current_dist = (head_physics.position - local_body_center).length()
		if current_dist > max_extend_dist:
			head_physics.position = local_body_center + (head_physics.position - local_body_center).normalized() * max_extend_dist
			
	else:
		var global_ideal = to_global(default_head_pos)
		var move_dir = (global_ideal - head_physics.global_position)
		head_physics.velocity = move_dir * extend_speed
		head_physics.move_and_slide()
		
	if head_pivot:
		head_pivot.position = head_physics.position
		
		if current_state != State.SLEEP and last_known_player_pos != Vector3.ZERO:
			# Billboard rotation towards target
			var target_pos = last_known_player_pos
			var local_target = head_pivot.to_local(target_pos)
			var angle = atan2(local_target.y, local_target.x)
			
			# Head tilt at max extension
			var dist_ratio = (head_physics.position - local_body_center).length() / max_extend_dist
			var tilt = 0.0
			if dist_ratio > 0.95:
				tilt = 0.3 * sign(local_target.y)
				
			var target_rot = angle + tilt
			if sprite_head: sprite_head.rotation.z = lerp_angle(sprite_head.rotation.z, target_rot, delta * 8.0)
			if sprite_whiskers: sprite_whiskers.rotation.z = lerp_angle(sprite_whiskers.rotation.z, target_rot, delta * 8.0)
			if mouth_fireball: mouth_fireball.rotation.z = lerp_angle(mouth_fireball.rotation.z, target_rot, delta * 8.0)
		else:
			if sprite_head: sprite_head.rotation.z = lerp_angle(sprite_head.rotation.z, 0.0, delta * 5.0)
			if sprite_whiskers: sprite_whiskers.rotation.z = lerp_angle(sprite_whiskers.rotation.z, 0.0, delta * 5.0)
			if mouth_fireball: mouth_fireball.rotation.z = lerp_angle(mouth_fireball.rotation.z, 0.0, delta * 5.0)

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and not _is_snapping:
		if editor_snap_to_surface:
			_is_snapping = true
			_editor_snap_to_surface()
			_is_snapping = false

func _editor_snap_to_surface():
	var space_state = get_world_3d().direct_space_state
	if not space_state: return
	
	# Gather excludes: self and all child CollisionObject3D nodes (like SweetSpotHitbox)
	var excludes: Array[RID] = [get_rid()]
	var stack = [self]
	while stack.size() > 0:
		var curr = stack.pop_back()
		if curr is CollisionObject3D and curr != self:
			excludes.append(curr.get_rid())
		for child in curr.get_children():
			stack.append(child)
			
	var best_hit = {}
	
	# Try using the editor camera raycast first, as it represents the user's line of sight
	var cam = get_viewport().get_camera_3d()
	if cam:
		var cam_pos = cam.global_position
		var drag_dir = (global_position - cam_pos).normalized()
		if drag_dir.length_squared() > 0.001:
			var start_dist = min(2.0, cam_pos.distance_to(global_position) - 0.1)
			if start_dist > 0.0:
				var ray_start = global_position - drag_dir * start_dist
				var ray_end = global_position + drag_dir * 5.0
				var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
				query.collision_mask = 1
				query.exclude = excludes
				var res = space_state.intersect_ray(query)
				if res:
					best_hit = res
					
	# Fallback if camera ray didn't hit anything: check local down and world down
	if best_hit.is_empty():
		var center = global_position + global_transform.basis.y.normalized() * 0.5
		var fallbacks = [
			-global_transform.basis.y.normalized() * 4.0, # local down
			Vector3.DOWN * 4.0                            # world down
		]
		var closest_dist = 9999.0
		for dir in fallbacks:
			var query = PhysicsRayQueryParameters3D.create(center, center + dir)
			query.collision_mask = 1
			query.exclude = excludes
			var res = space_state.intersect_ray(query)
			if res and center.distance_to(res.position) < closest_dist:
				closest_dist = center.distance_to(res.position)
				best_hit = res
				
	if not best_hit.is_empty():
		var hit_norm = best_hit.normal
		surface_normal = hit_norm
		
		var global_y_scale = global_transform.basis.y.length()
		var y_axis = hit_norm.normalized()
		var base_dir = global_transform.basis.z
		if abs(y_axis.dot(base_dir)) > 0.99:
			base_dir = global_transform.basis.x
		var z_axis = base_dir.slide(y_axis).normalized()
		var x_axis = y_axis.cross(z_axis).normalized()
		z_axis = x_axis.cross(y_axis).normalized()
		
		var target_basis = Basis(x_axis, y_axis, z_axis) * global_y_scale
		var local_bottom = Vector3(0, -0.9, 0)
		var target_position = best_hit.position - target_basis * local_bottom
		
		if not global_position.is_equal_approx(target_position) or not global_transform.basis.is_equal_approx(target_basis):
			global_transform = Transform3D(target_basis, target_position)

func _process(delta: float):
	if Engine.is_editor_hint():
		if head_pivot:
			head_pivot.transform.basis = Basis.IDENTITY
			head_pivot.scale = Vector3(0.5, 0.5, 0.5)
			head_pivot.position = default_head_pos
		_update_visuals_only(delta)
		return
		
	super._process(delta)
	if not is_dead:
		_update_visuals_only(delta)

func _update_visuals_only(delta: float):
	if is_dead: return
	
	var player_node = player if is_instance_valid(player) else get_tree().get_first_node_in_group("player")
	var target_global = global_position + global_transform.basis.z
	
	if player_node:
		target_global = player_node.global_position + Vector3(0, 1.0, 0)
	elif Engine.is_editor_hint():
		var cam = get_viewport().get_camera_3d()
		if cam:
			target_global = cam.global_position
			
	if visuals:
		# Determine if the player is on the left side of the screen
		var is_left = false
		var cam = get_viewport().get_camera_3d()
		if cam:
			var player_cam_local = cam.to_local(target_global)
			var enemy_cam_local = cam.to_local(global_position)
			is_left = player_cam_local.x < enemy_cam_local.x
		else:
			var player_local = visuals.to_local(target_global)
			is_left = player_local.x < 0
			
		if visuals is SegmentedSpriteRig:
			visuals.flip_horizontal = is_left
		else:
			if sprite_body:
				sprite_body.flip_h = is_left
			if sprite_tail:
				sprite_tail.flip_h = is_left
				
	var target_raise = 0.0
	if current_state == State.CHARGING:
		var progress = clamp(charge_timer / charge_time, 0.0, 1.0)
		target_raise = 0.45 * progress  # Up to 0.45 units raise
	
	current_charge_raise = lerp(current_charge_raise, target_raise, delta * 5.0)
	
	if sprite_head:
		sprite_head.position.y = current_charge_raise
	if sprite_whiskers:
		sprite_whiskers.position.y = current_charge_raise
	if mouth_fireball:
		mouth_fireball.position.y = minisun_offset.y + current_charge_raise
	if sweet_spot and sweet_spot.get_parent() == head_pivot:
		sweet_spot.position.y = current_charge_raise

func _update_wall_cling_physics(delta: float):
	if is_dead: return
	
	# 1. Smoothly align root node (self) basis with surface_normal
	var global_y_scale = global_transform.basis.y.length()
	var y_axis = surface_normal.normalized()
	
	var base_dir = global_transform.basis.z
	if abs(y_axis.dot(base_dir)) > 0.99:
		base_dir = global_transform.basis.x
	var z_axis = base_dir.slide(y_axis).normalized()
	var x_axis = y_axis.cross(z_axis).normalized()
	z_axis = x_axis.cross(y_axis).normalized()
	
	var target_basis = Basis(x_axis, y_axis, z_axis)
	var current_rot = Quaternion(global_transform.basis.orthonormalized())
	var target_rot = Quaternion(target_basis.orthonormalized())
	
	var next_basis = Basis(current_rot.slerp(target_rot, delta * surface_alignment_speed))
	global_transform.basis = next_basis * global_y_scale
	
	# 2. Reset BodyCollision local basis to IDENTITY (inherits root rotation)
	if has_node("BodyCollision"):
		var col = $BodyCollision
		col.transform.basis = Basis.IDENTITY

func _snap_to_nearest_surface():
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return
		
	var global_y_scale = global_transform.basis.y.length()
	
	# Extended raycast from local y = 1.0 to y = -2.5 to handle editor clipping
	var local_start = Vector3(0.375, 1.0, 0)
	var local_end = Vector3(0.375, -2.5, 0)
	var global_start = global_transform * local_start
	var global_end = global_transform * local_end
	
	var query = PhysicsRayQueryParameters3D.create(global_start, global_end)
	query.collision_mask = 1 # Environment layer
	query.exclude = [get_rid()]
	
	var result = space_state.intersect_ray(query)
	if result:
		var hit_pos = result.position
		var hit_norm = result.normal
		
		# Set surface normal
		surface_normal = hit_norm
		
		# 1. Align the root global_transform basis with the hit normal, preserving uniform scale
		var y_axis = hit_norm.normalized()
		var base_dir = global_transform.basis.z
		if abs(y_axis.dot(base_dir)) > 0.99:
			base_dir = global_transform.basis.x
		var z_axis = base_dir.slide(y_axis).normalized()
		var x_axis = y_axis.cross(z_axis).normalized()
		z_axis = x_axis.cross(y_axis).normalized()
		global_transform.basis = Basis(x_axis, y_axis, z_axis) * global_y_scale
		
		# 2. Position the root so that the bottom of the collision box (local y = -0.9) is flush with the wall
		var local_bottom = Vector3(0, -0.9, 0)
		global_position = hit_pos - global_transform.basis * local_bottom
		
		# Reset platforms tracking
		platform_node = null
		
		# Apply a small push-in velocity to make sure collision flags update
		velocity = -surface_normal * 0.1
		move_and_slide()

func _physics_process(delta: float):
	if Engine.is_editor_hint():
		return
		
	if _first_frame:
		_first_frame = false
		var global_y_scale = global_transform.basis.y.length()
		global_transform.basis = global_transform.basis.orthonormalized() * global_y_scale
		_snap_to_nearest_surface()
		
	if not is_dead and is_instance_valid(platform_node):
		var platform_trans = platform_node.global_transform
		var local_transform = last_platform_global_transform.affine_inverse() * global_transform
		global_transform = platform_trans * local_transform
		
		var platform_rot_change = platform_trans.basis * last_platform_global_transform.basis.inverse()
		surface_normal = (platform_rot_change * surface_normal).normalized()
		
		last_platform_global_transform = platform_trans
		
	super._physics_process(delta)
	
	if not is_dead:
		_update_wall_cling_physics(delta)
		
		# Track player in physics frame
		_track_player(delta)
		
		# Neck Orbit / HeadPivot Position Update (Physics)
		if visuals and head_pivot:
			var player_node = player if is_instance_valid(player) else get_tree().get_first_node_in_group("player")
			var target_head_pos = default_head_pos
			
			if current_state != State.SLEEP and player_node:
				var target_pos = player_node.global_position + Vector3(0, 1.0, 0)
				var player_local = visuals.to_local(target_pos)
				
				var to_player_local = player_local - local_body_center
				var dist_to_player_local = to_player_local.length()
				
				var extend_ratio = clamp(dist_to_player_local / 10.0, 0.4, 1.0)
				var target_extend_dist = max_extend_dist * extend_ratio
				
				var dir = to_player_local.normalized()
				if dir.y < 0.1:
					dir.y = 0.1
					dir = dir.normalized()
					
				target_head_pos = local_body_center + dir * target_extend_dist
				
			head_pivot.position = head_pivot.position.lerp(target_head_pos, delta * extend_speed)
			
		# Sync decoupled hitbox (SweetSpotHitbox)
		if sweet_spot and head_pivot:
			sweet_spot.global_transform = head_pivot.global_transform
			sweet_spot.global_transform.basis = head_pivot.global_transform.basis.orthonormalized()
			if head_collision:
				head_collision.position = Vector3(0, current_charge_raise * (visuals_scale * 0.5), 0)
				
		var found_platform: Node3D = null
		if is_on_floor() or is_on_wall() or is_on_ceiling():
			if get_slide_collision_count() > 0:
				for i in range(get_slide_collision_count()):
					var collision = get_slide_collision(i)
					var collider = collision.get_collider()
					if collider and (collider is StaticBody3D or collider is AnimatableBody3D or collider is CharacterBody3D or collider is RigidBody3D):
						found_platform = collider
						break
		if found_platform:
			platform_node = found_platform
			last_platform_global_transform = platform_node.global_transform
		else:
			platform_node = null

func _execute_state_logic(delta: float, dist_to_player: float):
	if current_state == State.SLEEP:
		charge_timer = 0.0
		fireball_charged = false
		if mouth_fireball: mouth_fireball.scale = mouth_fireball.scale.lerp(Vector3.ZERO, delta * 5.0)
		if flamethrower_area: flamethrower_area.monitoring = false
		if flamethrower_mesh: flamethrower_mesh.visible = false
		
	elif current_state == State.CHARGING:
		if flamethrower_area: flamethrower_area.monitoring = false
		if flamethrower_mesh: flamethrower_mesh.visible = false
		
		if not fireball_charged:
			charge_timer += delta
			var scale_val = clamp(charge_timer / charge_time, 0.0, 1.0)
			var base_minisun_scale = Vector3(-2, 2, -2)
			if mouth_fireball: mouth_fireball.scale = base_minisun_scale * scale_val
			if charge_timer >= charge_time:
				fireball_charged = true
				if mouth_fireball: mouth_fireball.scale = base_minisun_scale * 1.5
		else:
			# Hold fire indefinitely until we have a clear shot
			if _has_line_of_sight():
				if dist_to_player <= fire_radius:
					_fire_projectile()
					fireball_charged = false
					charge_timer = -fire_delay
					if mouth_fireball: mouth_fireball.scale = Vector3.ZERO
				
	elif current_state == State.FLAMETHROWER:
		var can_see = _has_line_of_sight()
		if flamethrower_area:
			flamethrower_area.monitoring = can_see
			if flamethrower_mesh: flamethrower_mesh.visible = can_see
			if can_see:
				_tick_flamethrower_damage(delta)
		
		if mouth_fireball: mouth_fireball.scale = mouth_fireball.scale.lerp(Vector3.ZERO, delta * 40.0)

func _tick_flamethrower_damage(delta: float):
	for body in flamethrower_area.get_overlapping_bodies():
		if body == self: continue
		if body.is_in_group("enemy") or body.is_in_group("enemy_hurtbox"): continue
		
		if body.has_method("take_damage"):
			body.take_damage(flamethrower_dps * delta, Vector3.ZERO, 0.0, 0.0, 0.0)
			
			if body.get("invincibility_timer") != null and body.invincibility_timer <= 0:
				var push_dir = (body.global_position - head_pivot.global_position).normalized()
				push_dir.y += 0.4 
				body.take_damage(0.0, push_dir.normalized(), 250.0, 0.1, 0.02)

func _fire_projectile():
	if not aim_pivot: return
	var proj = FIREBALL_SCENE.instantiate()
	get_parent().add_child(proj)
	proj.creator = self
	proj.global_position = head_pivot.global_position + (-aim_pivot.global_transform.basis.z * 1.5)
	
	var dir = -aim_pivot.global_transform.basis.z.normalized()
	# Apply slight random spread
	var random_offset = Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)) * projectile_spread
	proj.direction = (dir + random_offset).normalized()
	proj.speed = projectile_speed
	proj.damage = fireball_damage

func _on_flame_body_entered(body: Node3D):
	if body.is_in_group("player"):
		print("Player entered flamethrower!")

func _on_flame_area_entered(area: Area3D):
	if area.has_method("queue_free") and area.is_in_group("player_projectile"):
		area.queue_free()

func _on_death():
	_spawn_loot()

func _spawn_loot():
	var count = 4
	for i in range(count):
		var orb = ORB_SCENE.instantiate()
		get_parent().add_child(orb)
		orb.global_position = global_position + Vector3(0, 1.0, 0)
		orb.pickup_type = 0 # BLACK_INK
		orb.value = 10.0

func _exit_tree():
	if is_instance_valid(editor_helper):
		editor_helper.queue_free()

func _create_editor_helper():
	var existing = get_node_or_null("EditorSurfaceGuide")
	if existing:
		existing.queue_free()
		
	editor_helper = Node3D.new()
	editor_helper.name = "EditorSurfaceGuide"
	
	# Center of collision shape offset: Vector3(0.375, 0.3, 0)
	# Bottom of collision shape offset: Vector3(0, -0.9, 0)
	var local_bottom = Vector3(0, -0.9, 0)
	
	# Create a flat box representing the contact rectangle (matching bottom of collision shape)
	var disc_mesh = MeshInstance3D.new()
	disc_mesh.name = "ContactDisc"
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(4.5, 0.02, 3.2)
	disc_mesh.mesh = box_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.5, 0.35) # Semi-transparent magenta
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	box_mesh.material = mat
	
	disc_mesh.position = local_bottom
	editor_helper.add_child(disc_mesh)
	
	# Create 4 thin borders around the contact rectangle for high visibility
	var border_mat = StandardMaterial3D.new()
	border_mat.albedo_color = Color(1.0, 0.0, 0.5, 0.9) # Solid magenta
	border_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	
	# Front border
	var f_border = MeshInstance3D.new()
	var f_mesh = BoxMesh.new()
	f_mesh.size = Vector3(4.5, 0.04, 0.04)
	f_mesh.material = border_mat
	f_border.mesh = f_mesh
	f_border.position = local_bottom + Vector3(0, 0, -1.6)
	editor_helper.add_child(f_border)
	
	# Back border
	var b_border = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(4.5, 0.04, 0.04)
	b_mesh.material = border_mat
	b_border.mesh = b_mesh
	b_border.position = local_bottom + Vector3(0, 0, 1.6)
	editor_helper.add_child(b_border)
	
	# Left border
	var l_border = MeshInstance3D.new()
	var l_mesh = BoxMesh.new()
	l_mesh.size = Vector3(0.04, 0.04, 3.2)
	l_mesh.material = border_mat
	l_border.mesh = l_mesh
	l_border.position = local_bottom + Vector3(-2.25, 0, 0)
	editor_helper.add_child(l_border)
	
	# Right border
	var r_border = MeshInstance3D.new()
	var r_mesh = BoxMesh.new()
	r_mesh.size = Vector3(0.04, 0.04, 3.2)
	r_mesh.material = border_mat
	r_border.mesh = r_mesh
	r_border.position = local_bottom + Vector3(2.25, 0, 0)
	editor_helper.add_child(r_border)
	
	# Create a stem pointing from center of collision shape to contact plane (yellow/gold)
	var stem_mesh = MeshInstance3D.new()
	stem_mesh.name = "Stem"
	var stem_cyl = CylinderMesh.new()
	stem_cyl.top_radius = 0.04
	stem_cyl.bottom_radius = 0.04
	stem_cyl.height = 1.2
	stem_mesh.mesh = stem_cyl
	
	var stem_mat = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(1.0, 0.8, 0.0, 0.9) # Gold/yellow
	stem_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	stem_cyl.material = stem_mat
	
	stem_mesh.position = local_bottom + Vector3(0, 0.6, 0) # Midpoint between -0.9 and 0.3
	editor_helper.add_child(stem_mesh)
	
	# Create a text label
	var label = Label3D.new()
	label.name = "ContactLabel"
	label.text = "ALIGN THIS RECTANGLE FLUSH TO SURFACE"
	label.font_size = 20
	label.outline_size = 5
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = local_bottom + Vector3(0, 0.1, 1.7) # Just outside back border
	label.modulate = Color(1.0, 0.0, 0.5) # Magenta
	editor_helper.add_child(label)
	
	add_child(editor_helper)
