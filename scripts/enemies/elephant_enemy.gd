extends BaseEnemy

# Elephant specifics
@export_group("AI Settings")
@export var detection_range: float = 80.0
@export var bubble_range: float = 100.0
@export var float_distance: float = 1.5

var target_height: float = 4.0
var hover_timer: float = 0.0
var active_bubble_shield: Node3D = null
var bubbled_target: Node3D = null
var heal_cooldown: float = 0.0

var wander_timer: float = 0.0
var wander_dir: Vector3 = Vector3.ZERO

var debug_line: MeshInstance3D = null

func _ready():
	super._ready()
	
	target_height = global_position.y
	
	if knockback_comp:
		knockback_comp.hitstun_gravity_multiplier = 0.1 # Very slow balloon fall when hit
	
	_setup_debug_line()
			
	var cone = get_node_or_null("VisionCone")
	if cone:
		cone.visible = false

func _setup_debug_line():
	debug_line = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = 1.0
	debug_line.mesh = cyl
	var dmat = StandardMaterial3D.new()
	dmat.albedo_color = Color(1, 0, 1, 0.5)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyl.material = dmat
	add_child(debug_line)
	debug_line.set_as_top_level(true)

func take_damage(amount: float, force_dir: Vector3 = Vector3.ZERO, raw_force: float = 0.0, _iframe_dur: float = 0.8, min_stun: float = 0.05):
	super.take_damage(amount, force_dir, raw_force, _iframe_dur, min_stun)
	
	if not is_dead and (not active_bubble_shield or not is_instance_valid(active_bubble_shield)):
		_cast_bubble()

func _update_debug_label():
	var txt = "[ Elephant | HP: %d ]\n" % int(hp)
	if is_dead: txt = "[ K.O. ]\n"
	debug_label.text = txt

func _process(delta: float):
	super._process(delta)
	_update_debug_line()

func _update_debug_line():
	if is_instance_valid(debug_line):
		if is_instance_valid(bubbled_target) and is_instance_valid(active_bubble_shield) and not is_dead and bubbled_target != self:
			debug_line.visible = true
			var p1 = global_position
			var p2 = bubbled_target.global_position
			var dist = p1.distance_to(p2)
			if dist > 0.01:
				debug_line.global_position = (p1 + p2) / 2.0
				var dir = p1.direction_to(p2)
				var up = Vector3.UP if abs(dir.y) < 0.99 else Vector3.RIGHT
				debug_line.look_at(p2, up)
				debug_line.rotate_object_local(Vector3.RIGHT, PI/2.0)
				debug_line.scale = Vector3(1, dist, 1)
		else:
			debug_line.visible = false

func _process_death_physics(delta: float):
	linger_timer -= delta
	if linger_timer <= 0:
		scale = scale.move_toward(Vector3.ZERO, delta * 4.0)
		if scale.x <= 0.05:
			queue_free()
	if not is_on_floor():
		velocity.y -= 1.5 * delta # Fall very slowly when dead
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	move_and_slide()

func _apply_movement(delta: float):
	# Hovering logic
	hover_timer += delta * 2.0
	var hover_offset = (sin(hover_timer) - 1.0) * (float_distance / 2.0)
	
	var target_y = target_height + hover_offset
	var y_diff = target_y - global_position.y
	velocity.y = y_diff * 2.0
	
	# Wandering logic
	if wander_timer > 0:
		wander_timer -= delta
	else:
		wander_timer = randf_range(2.0, 5.0)
		var angle = randf() * TAU
		wander_dir = Vector3(cos(angle), 0, sin(angle)) * randf_range(1.0, 2.5)
	
	velocity.x = move_toward(velocity.x, wander_dir.x, 2.0 * delta)
	velocity.z = move_toward(velocity.z, wander_dir.z, 2.0 * delta)
	
	move_and_slide()

func _process_ai(delta: float):
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player: return
		
	_check_bubble_range()
	_bubble_ai_logic()
	_healing_ai_logic(delta)

func _check_bubble_range():
	if is_instance_valid(active_bubble_shield) and is_instance_valid(bubbled_target):
		if bubbled_target != self and global_position.distance_to(bubbled_target.global_position) > bubble_range:
			active_bubble_shield.queue_free()
			if "has_bubble" in bubbled_target:
				bubbled_target.has_bubble = false
			active_bubble_shield = null
			bubbled_target = null

func _bubble_ai_logic():
	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player < detection_range: 
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(global_position, player.global_position, 1) 
		var result = space_state.intersect_ray(query)
		
		if not result or result.collider == player:
			if not active_bubble_shield or not is_instance_valid(active_bubble_shield):
				_cast_bubble()

func _healing_ai_logic(delta: float):
	if heal_cooldown > 0:
		heal_cooldown -= delta
	else:
		var heal_target = _find_heal_target()
		if heal_target:
			_heal_target(heal_target)
			heal_cooldown = 3.0

func _cast_bubble():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var best_target = null
	var best_score = -99999.0
	
	for e in enemies:
		if "is_dead" in e and e.is_dead: continue
		if "has_bubble" not in e: continue
		if e.has_bubble: continue
		
		if e != self and e.global_position.distance_to(global_position) > bubble_range:
			continue
		
		var score = 0.0
		
		if e != self:
			if e.get_script() == self.get_script():
				score += 200.0
			else:
				score += 1000.0
			
		if "hp" in e and "max_hp" in e and e.hp < e.max_hp:
			var missing_hp_ratio = 1.0 - (e.hp / e.max_hp)
			score += 500.0 * missing_hp_ratio
			
		var d = e.global_position.distance_to(global_position)
		score -= d
		
		if score > best_score:
			best_score = score
			best_target = e
			
	if not best_target:
		best_target = self
			
	if best_target:
		bubbled_target = best_target
		best_target.has_bubble = true
		
		var shield_script = load("res://scripts/enemies/bubble_shield.gd")
		var shield = shield_script.new()
		get_parent().add_child(shield)
		shield.target = best_target
		
		if best_target is CollisionObject3D:
			best_target.add_collision_exception_with(shield)
			shield.add_collision_exception_with(best_target)
			
		active_bubble_shield = shield

func _find_heal_target() -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if e == self or ("is_dead" in e and e.is_dead): continue
		if e.global_position.distance_to(global_position) > 30.0: continue
		
		if not e.has_method("get_hp_ratio"): continue
		var hp_ratio = e.get_hp_ratio()
		if hp_ratio < 0.5:
			var time_since_attack = 10.0
			if "last_attack_time" in e:
				time_since_attack = Time.get_ticks_msec() / 1000.0 - e.last_attack_time
			if time_since_attack > 5.0:
				return e
	return null

func _heal_target(target: Node3D):
	var to_target = (target.global_position - global_position).normalized()
	velocity += to_target * 5.0
	
	if target.global_position.distance_to(global_position) < 8.0:
		if "hp" in target and "max_hp" in target:
			target.hp = min(target.max_hp, target.hp + 20.0)

func _on_death():
	if is_instance_valid(active_bubble_shield):
		active_bubble_shield.queue_free()
	if is_instance_valid(bubbled_target) and "has_bubble" in bubbled_target:
		bubbled_target.has_bubble = false
	_spawn_loot()

func _spawn_loot():
	var orb_scene = load("res://systems/pickups/pickup_orb.tscn")
	var orb = orb_scene.instantiate()
	get_parent().add_child(orb)
	orb.global_position = global_position + Vector3(0, 1.0, 0)
	orb.pickup_type = 1 # BLACK_INK
	orb.value = 20.0
