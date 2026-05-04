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

enum State { SLEEP, CHARGING, FLAMETHROWER }
var current_state: State = State.SLEEP

var charge_timer: float = 0.0
var fireball_charged: bool = false

# Nodes
var head_pivot: Node3D
var mouth_fireball: MeshInstance3D
var flamethrower_area: Area3D
var flamethrower_mesh: MeshInstance3D
var head_material: StandardMaterial3D

func _ready():
	super._ready()
	
	head_pivot = get_node_or_null("HeadPivot")
	if head_pivot:
		var sweet_spot = head_pivot.get_node_or_null("SweetSpotHitbox")
		if sweet_spot and sweet_spot is CollisionObject3D:
			sweet_spot.collision_mask = 0 # Prevents the head from colliding with the floor
			
		mouth_fireball = head_pivot.get_node_or_null("MouthFireball")
		flamethrower_area = head_pivot.get_node_or_null("FlamethrowerArea")
		if flamethrower_area:
			flamethrower_mesh = flamethrower_area.get_node_or_null("FlamethrowerMesh")
			flamethrower_area.body_entered.connect(_on_flame_body_entered)
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
		velocity = Vector3.ZERO
		if is_on_floor():
			velocity.y = -1.0
		elif is_on_ceiling():
			velocity.y = 1.0
		elif is_on_wall():
			velocity = -get_wall_normal() * 1.0
		
	move_and_slide()

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

	_track_player(delta)
	_execute_state_logic(delta, dist_to_player)

func _track_player(delta: float):
	if current_state != State.SLEEP and head_pivot:
		var target_pos = player.global_position + Vector3(0, 1.0, 0)
		var prev = head_pivot.global_transform
		var up = Vector3.UP
		if abs((target_pos - head_pivot.global_position).normalized().y) > 0.99:
			up = Vector3.RIGHT
		head_pivot.look_at(target_pos, up)
		var target_tr = head_pivot.global_transform
		head_pivot.global_transform = prev.interpolate_with(target_tr, delta * 5.0)

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
			if mouth_fireball: mouth_fireball.scale = Vector3.ONE * scale_val
			if charge_timer >= charge_time:
				fireball_charged = true
				if mouth_fireball: mouth_fireball.scale = Vector3.ONE * 1.5
		else:
			if dist_to_player <= fire_radius:
				_fire_projectile()
				fireball_charged = false
				charge_timer = -fire_delay
				if mouth_fireball: mouth_fireball.scale = Vector3.ZERO
				
	elif current_state == State.FLAMETHROWER:
		if flamethrower_area: 
			flamethrower_area.monitoring = true
			if flamethrower_mesh: flamethrower_mesh.visible = true
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
	var proj_scene = load("res://scenes/enemies/fireball.tscn")
	if proj_scene and head_pivot:
		var proj = proj_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = head_pivot.global_position + (-head_pivot.global_transform.basis.z * 1.5)
		proj.direction = -head_pivot.global_transform.basis.z.normalized()
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
	var orb_scene = load("res://systems/pickups/pickup_orb.tscn")
	var count = 4
	for i in range(count):
		var orb = orb_scene.instantiate()
		get_parent().add_child(orb)
		orb.global_position = global_position + Vector3(0, 1.0, 0)
		orb.pickup_type = 0 # BLACK_INK
		orb.value = 10.0
