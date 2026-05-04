extends CharacterBody3D
class_name BaseEnemy

@export_group("Base Stats")
@export var max_hp: float = 100.0
@export var knockback_weight: float = 800.0
@export var base_color: Color = Color(0.2, 0.5, 0.6)

var hp: float = 100.0
var is_dead: bool = false
var incoming_damage: float = 0.0
var linger_timer: float = 2.0
var has_bubble: bool = false
var current_bubble_node: Node3D = null

var knockback_comp: KnockbackComponent
var debug_label: Label3D
var player: Node3D

# To be assigned in subclasses if they have meshes
var mesh_materials: Array[StandardMaterial3D] = []

func get_hp_ratio() -> float:
	if hp - incoming_damage <= 0: return 0.0
	return hp / max_hp

func preview_damage(amount: float):
	incoming_damage = amount

func _ready():
	add_to_group("enemy")
	hp = max_hp
	player = get_tree().get_first_node_in_group("player")
	
	_setup_knockback()
	_setup_debug_label()
	_setup_materials()

func _setup_knockback():
	knockback_comp = KnockbackComponent.new()
	knockback_comp.body = self
	knockback_comp.weight = knockback_weight * scale.x
	add_child(knockback_comp)

func _setup_debug_label():
	debug_label = Label3D.new()
	debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	debug_label.position = Vector3(0, 1.5, 0)
	debug_label.outline_size = 4
	debug_label.font_size = 32
	add_child(debug_label)

func _setup_materials():
	# Subclasses can override or we can try to find meshes automatically
	for child in get_children():
		if child is MeshInstance3D and child.mesh:
			var mat = child.mesh.surface_get_material(0)
			if not mat: mat = child.mesh.material
			if mat is StandardMaterial3D:
				mesh_materials.append(mat)

func take_damage(amount: float, force_dir: Vector3 = Vector3.ZERO, raw_force: float = 0.0, _iframe_dur: float = 0.8, min_stun: float = 0.05):
	incoming_damage = 0.0
	if is_dead: return
	
	if has_bubble:
		return # Bubble mitigates damage
	
	hp -= amount
	
	if raw_force > 0 and knockback_comp:
		knockback_comp.apply_knockback(force_dir, raw_force, min_stun)
	
	_flash_color(Color(1, 0.5, 0))
	
	if hp <= 0:
		_die()

func heal(amount: float):
	if is_dead: return
	hp += amount
	if hp > max_hp:
		hp = max_hp
	
	_flash_color(Color(0, 1, 0))

func _flash_color(color: Color):
	for mat in mesh_materials:
		mat.albedo_color = color
	
	get_tree().create_timer(0.1).timeout.connect(func(): 
		if is_inside_tree() and not is_dead:
			for mat in mesh_materials:
				mat.albedo_color = base_color
	)

func _die():
	is_dead = true
	hp = 0
	set_collision_layer_value(1, false)
	
	for mat in mesh_materials:
		mat.albedo_color = Color(0.3, 0.3, 0.3)
	
	# Allow it to fall naturally if it was a turret
	if knockback_comp:
		knockback_comp.weight = 300.0
	
	_on_death()

func _on_death():
	# Override in subclasses for loot or effects
	pass

func _process(_delta: float):
	if is_instance_valid(debug_label):
		_update_debug_label()

func _update_debug_label():
	var txt = "[ %s | HP: %d ]\n" % [name, int(hp)]
	if is_dead: txt = "[ K.O. ]\n"
	debug_label.text = txt

func _physics_process(delta: float):
	if is_dead:
		_process_death_physics(delta)
		return
		
	if knockback_comp and knockback_comp.is_in_hitstun():
		return
		
	_process_ai(delta)
	_apply_movement(delta)

func _process_death_physics(delta: float):
	linger_timer -= delta
	if linger_timer <= 0:
		scale = scale.move_toward(Vector3.ZERO, delta * 4.0)
		if scale.x <= 0.05:
			queue_free()
			
	if not is_on_floor(): velocity.y -= 9.8 * delta
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	move_and_slide()

func _process_ai(_delta: float):
	# Subclasses override
	pass

func _apply_movement(delta: float):
	# Default gravity and friction
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 20.0 * delta)
	
	move_and_slide()
