extends Area3D
class_name BaseProjectile

var compiled_mode: FireModeData
var move_dir: Vector3
var distance_traveled: float = 0.0
var max_distance: float = 200.0
var fall_velocity: float = 0.0

var shooter: Node3D
var charge_ratio: float = 1.0

func _ready():
	self.body_entered.connect(_on_body_entered)

func initialize(direction: Vector3, data: FireModeData, shooter_node: Node3D = null, ratio: float = 1.0):
	shooter = shooter_node
	charge_ratio = ratio
	move_dir = direction.normalized()
	compiled_mode = data
	
	if move_dir.length_squared() > 0.001:
		look_at(global_position + move_dir, Vector3.UP)
	
	# Visual/Physical Scale representation of charge (up to 2x size)
	scale = Vector3.ONE * lerp(1.0, 2.0, charge_ratio)

func _physics_process(delta: float):
	if not compiled_mode: return
	
	fall_velocity += compiled_mode.projectile_gravity * delta
	
	var current_vel = move_dir * compiled_mode.projectile_speed_m_s
	current_vel.y -= fall_velocity
	
	var step = current_vel * delta
	global_position += step
	distance_traveled += step.length()
	
	if current_vel.length_squared() > 0.001:
		var target_look = global_position + current_vel
		# Avoid look_at errors by checking if up vector is parallel
		var up_vec = Vector3.UP
		if current_vel.normalized().abs().y > 0.99:
			up_vec = Vector3.RIGHT
		look_at(target_look, up_vec)
	
	if distance_traveled > max_distance:
		queue_free()

func _on_body_entered(body: Node3D):
	if body == shooter:
		return
		
	var is_player_projectile = shooter and shooter.is_in_group("player")
	if "has_bubble" in body and body.has_bubble:
		if not is_player_projectile:
			return # Pass through the bubble! (No damage, no destruction)
			
	# Execute effects FIRST (so knockback calculates based on pre-damage HP)
	var final_dmg = compiled_mode.damage * lerp(1.0, 3.0, charge_ratio)
	
	if body.has_method("preview_damage"):
		body.preview_damage(final_dmg)
		
	for effect in compiled_mode.hit_effects:
		if effect.has_method("apply_effect"):
			effect.apply_effect(body, global_position, -move_dir, move_dir, charge_ratio, final_dmg)
		
	# Apply damage or healing
	if compiled_mode.heals_target:
		if body.has_method("heal"):
			body.heal(final_dmg)
	else:
		if body.has_method("take_damage"):
			body.take_damage(final_dmg)
		
	queue_free()
