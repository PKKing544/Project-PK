extends Area3D
class_name PickupOrb

enum Type { BLACK_INK, PINK_INK, KEY, ITEM }
@export var pickup_type: Type = Type.BLACK_INK
@export var value: float = 20.0

var player: Node3D
var is_magnetized: bool = false
var velocity: Vector3 = Vector3.ZERO
var magnet_speed: float = 0.0

func _ready():
	# Initial "pop" animation when spawnedd
	velocity = Vector3(randf_range(-2, 2), randf_range(4, 7), randf_range(-2, 2))
	
	# Visual setup based on type
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh:
		var mat = mesh.get_active_material(0)
		if mat:
			mat = mat.duplicate()
			match pickup_type:
				Type.BLACK_INK: mat.albedo_color = Color(0.1, 0.1, 0.1)
				Type.PINK_INK: mat.albedo_color = Color(1.0, 0.2, 0.8)
			mesh.set_surface_override_material(0, mat)

func _physics_process(delta: float):
	if is_magnetized and player:
		# Minecraft style: fly to player (target feet)
		var dir = (player.global_position + Vector3(0, 1.0, 0)) - global_position
		magnet_speed += delta * 40.0 # Accelerate
		global_position += dir.normalized() * magnet_speed * delta
		
		if dir.length() < 0.8:
			_on_absorbed()
	else:
		# Gravity and Physics
		velocity.y -= 20.0 * delta
		var motion = velocity * delta
		
		# Perform a simple raycast downwards to find the floor
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(global_position, global_position + motion + Vector3(0, -0.3, 0))
		query.collision_mask = 1 # Environment/Floor layer
		var result = space_state.intersect_ray(query)
		
		if result:
			# Hit the floor!
			global_position = result.position + Vector3(0, 0.05, 0)
			velocity.y = abs(velocity.y) * 0.5 # Bounce up
		else:
			global_position += motion
			# Apply friction
			velocity.x = move_toward(velocity.x, 0, delta * 2.0)
			velocity.z = move_toward(velocity.z, 0, delta * 2.0)

	# Check for player proximity to start magnetism
	if not is_magnetized:
		if not player:
			player = get_tree().get_first_node_in_group("player")
		
		if player and global_position.distance_to(player.global_position) < 12.0:
			is_magnetized = true

func _on_absorbed():
	if not player: return
	
	match pickup_type:
		Type.BLACK_INK:
			var hm = player.get_node_or_null("HandManager")
			if hm:
				hm.current_ink = min(hm.current_ink + value, hm.current_hand.max_ink if hm.current_hand else 100.0)
				hm.emit_signal("ink_changed", hm.current_ink, hm.current_hand.max_ink if hm.current_hand else 100.0)
		Type.PINK_INK:
			if "ability_cooldown_timer" in player:
				player.ability_cooldown_timer = max(0, player.ability_cooldown_timer - value)
			if player.has_method("heal"):
				player.heal(value)
				
	# TODO: Play sound effect
	queue_free()
