extends Node
class_name KnockbackComponent

@export var body: CharacterBody3D
@export var weight: float = 1.0
@export var ground_friction: float = 15.0
@export var air_friction: float = 4.0
@export var health_scaling_enabled: bool = true
@export var hitstun_gravity_multiplier: float = 0.4 # Airballoon gravity
@export var max_speed: float = 60.0 # Prevents tunneling through floors
@export var wall_bounce_multiplier: float = 0.0

var knockback_velocity: Vector3 = Vector3.ZERO
var hitstun_timer: float = 0.0

var last_raw_force: float = 0.0
var last_health_mult: float = 1.0
var last_accel: float = 0.0

func _physics_process(delta: float):
	if hitstun_timer > 0:
		hitstun_timer -= delta
		
		# Apply airballoon gravity (slower fall during hitstun)
		var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		knockback_velocity.y -= gravity * hitstun_gravity_multiplier * delta
		
		# Apply friction/damping based on state
		var current_friction = ground_friction if body and body.is_on_floor() else air_friction
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, current_friction * delta)
		
		# Clamp speed
		if knockback_velocity.length() > max_speed:
			knockback_velocity = knockback_velocity.normalized() * max_speed
			
		# Apply directly to body for the duration of hitstun
		if body:
			body.velocity = knockback_velocity
			body.move_and_slide()

func apply_knockback(force_dir: Vector3, raw_force: float, min_stun: float = 0.05):
	if not body: return
	
	var health_mult = 1.0
	if health_scaling_enabled and body.has_method("get_hp_ratio"):
		health_mult = lerp(3.0, 1.0, clamp(body.get_hp_ratio(), 0.0, 1.0))
		
	var acceleration = (raw_force * health_mult) / max(weight * 0.1, 1.0)
	knockback_velocity += force_dir.normalized() * acceleration
	
	last_raw_force = raw_force
	last_health_mult = health_mult
	last_accel = acceleration
	
	# Clamp to max safe speed
	if knockback_velocity.length() > max_speed:
		knockback_velocity = knockback_velocity.normalized() * max_speed
		
	hitstun_timer = max(hitstun_timer, min_stun)

func is_in_hitstun() -> bool:
	return hitstun_timer > 0.0
