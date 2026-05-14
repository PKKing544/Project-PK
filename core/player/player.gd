extends CharacterBody3D # Character controller

@export var speed := 12.0
@export var acceleration := 80.0
@export var friction := 60.0
@export var turn_accel_multi := 3.0  # Acceleration boost when changing direction (1.0 = no boost)
@export var jump_velocity := 15.0
@export var max_air_jumps := 1
@export var coyote_time := 0.15
@export var jump_buffer_time := 0.15
@export var gravity := 35.0
@export var max_speed_multi := 5.0 # Safety net: Max speed as a multiplier of base speed
@export var short_hop_multi := 0.35 # How much upward velocity is kept on early jump release (short hop)

# New Mechanics 
@export var sneak_speed_multi := 0.2
@export var slide_boost := 10.0
@export var slide_friction := 4.0
@export var slide_jump_multi := 1.5

@export var wall_slide_speed := -2.0
@export var ground_pound_speed := -40.0
@export var wall_run_tilt := 25.0 # Degrees
@export var slide_slope_threshold_deg := 5.0 # Minimum slope angle to trigger slide instead of crouch

@export_group("Melee - Base Tap")
@export var melee_light_boost := 10.0
@export var melee_light_damage := 30.0
@export var melee_light_force := 150.0
@export var melee_charge_slow := 0.6
@export var base_swing_duration := 0.25
@export var base_lunge_window_ratio := 0.25
@export var base_pogo_bounce := 25.0
@export var base_pogo_upward_bias := 2.0
@export var melee_light_hitstop := 0.0

@export_group("Melee - Hitbox")
@export var hitbox_size_light := Vector3(1.5, 1.5, 1.5)
@export var hitbox_size_heavy := Vector3(2.5, 2.0, 2.5)
@export var hitbox_offset := Vector3(0.0, 0.0, -1.5)  # Forward offset from camera pivot
@export var melee_strafe_shift := 0.5 # How much the hitbox slides left/right when strafing
@export var hitbox_debug_visible := true

@export_group("Health")
@export var max_health: float = 100.0
var current_health: float = 100.0
@export var invincibility_duration: float = 0.8
var invincibility_timer: float = 0.0
var flash_timer: float = 0.0
var knockback_comp: KnockbackComponent

@export_group("Equipment")
@export var equipped_hand: HandData
@export var equipped_attachment: AttachmentData
@export var equipped_ability: AbilityData
@export var equipped_dash: DashData
@export var equipped_heavy_attack: HeavyAttackData

@export_group("Outline")
@export var use_outline: bool = true:
	set(val):
		use_outline = val
		_refresh_outlines()
@export var outline_color: Color = Color.WHITE:
	set(val):
		outline_color = val
		_refresh_outlines()
@export var outline_width: float = 4.0:
	set(val):
		outline_width = val
		_refresh_outlines()
@export var outline_depth_offset: float = 0.001:
	set(val):
		outline_depth_offset = val
		_refresh_outlines()


@export var mouse_sensitivity := 0.002

@export var camera_follow_speed := 15.0
@export var max_camera_roll := 1.0

@export var base_fov := 75.0
@export var jump_fov := 90.0
@export var shoot_fov := 60.0
@export var fov_lerp_speed := 8.0
@export var shoulder_offset := 0.6  # Over-the-shoulder horizontal shift when aiming
@export var shoulder_lift := 0.4    # Over-the-shoulder vertical lift when aiming

var base_camera_h: float = 0.0
var base_camera_v: float = 0.0

var debug_ui_label: Label
var health_bar: ProgressBar

# Nodes
@onready var visuals = $Visuals
@onready var base_sprite = $Visuals/BaseSprite
@onready var aim_setup = $Visuals/AimSetup
@onready var pk_body = $Visuals/AimSetup/Pkbody
@onready var pk_arm = $Visuals/AimSetup/Pkarm
@onready var pk_hand = $Visuals/AimSetup/Pkhand
@onready var camera_pivot = $CameraPivot
@onready var spring_arm = $CameraPivot/SpringArm3D
@onready var camera = $CameraPivot/SpringArm3D/Camera3D

# RayCast for ledge detection
var ledge_ray: RayCast3D

# Textures
var tex_idle = preload("res://art/idle.png")
var tex_run = preload("res://art/run.png")
var tex_jump = preload("res://art/jump.png")
var tex_dash = preload("res://art/dash.png")
var tex_slide = preload("res://art/slide.png")
var tex_backup = preload("res://art/backup.png")
var tex_side = preload("res://art/side.png")
var tex_sideinvert = preload("res://art/sideinvert.png")
var tex_sneak = preload("res://art/sneak.png")
var tex_crosshair = preload("res://art/Crosshair.png")

var tex_pkbody = preload("res://art/Pkbody.png")
var tex_pkarm = preload("res://art/pkarm.png")
var tex_pkhand = preload("res://art/Pkhand.png")

var is_dashing = false
var dash_timer = 0.0

var aim_mode = false
var hand_manager: HandManager

var is_sneaking = false
var is_sliding = false
var current_slide_speed = 0.0
var initial_slide_speed = 0.0

var can_air_dash = true
var wall_latch = false
var is_wall_running = false
var zoom_linger_timer = 0.0

var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var current_air_jumps = 0
var was_on_floor_last_frame = false

var is_charging_melee = false
var melee_charge_timer = 0.0
var heavy_melee_cooldown_timer = 0.0
var is_swinging_melee = false
var melee_swing_timer = 0.0
var melee_active_swing_duration = 0.25
var melee_is_heavy = false
var has_pogoed_this_swing = false
var long_jump_timer := 0.0 # Grace period to prevent ground-pound during a long jump
var melee_hitbox: Area3D
var melee_hitbox_shape: BoxShape3D
var melee_hitbox_debug_mesh: MeshInstance3D
var hit_entities_this_swing: Array[Node] = []

var ability_cooldown_timer: float = 0.0
var is_attachment_active: bool = true

var spawn_point := Vector3(0, 3, 0)
var kill_floor_y := -45.0

var is_dead := false
var death_timer := 0.0
var death_rotation := 0.0

var blob_shadow_ray: RayCast3D
var blob_shadow_mesh: MeshInstance3D

func _ready():
	add_to_group("player")
	
	knockback_comp = KnockbackComponent.new()
	knockback_comp.body = self
	knockback_comp.weight = 2000.0 # Standard player weight
	knockback_comp.ground_friction = 15.0
	knockback_comp.air_friction = 4.0
	add_child(knockback_comp)
	
	current_health = max_health
	base_camera_h = camera.h_offset
	base_camera_v = camera.v_offset
	
	camera.h_offset = base_camera_h + shoulder_offset
	camera.v_offset = base_camera_v + shoulder_lift
	
	# --- DEBUG UI SETUP ---
	var canvas = CanvasLayer.new()
	debug_ui_label = Label.new()
	debug_ui_label.position = Vector2(20, 20)
	debug_ui_label.add_theme_font_size_override("font_size", 24)
	debug_ui_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	debug_ui_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	debug_ui_label.add_theme_constant_override("outline_size", 6)
	canvas.add_child(debug_ui_label)
	
	health_bar = ProgressBar.new()
	health_bar.max_value = max_health
	health_bar.value = max_health
	health_bar.custom_minimum_size = Vector2(300, 30)
	health_bar.position = Vector2(20, 100) # Below debug text
	health_bar.modulate = Color(0.2, 0.8, 0.2)
	canvas.add_child(health_bar)
	
	var equip_menu = preload("res://ui/debug_equipment_menu.tscn").instantiate()
	equip_menu.player = self
	canvas.add_child(equip_menu)
	
	add_child(canvas)
	# ----------------------
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_pivot.top_level = true
	spawn_point = global_position
	
	base_sprite.texture = tex_idle
	pk_body.texture = tex_pkbody
	pk_arm.texture = tex_pkarm
	pk_hand.texture = tex_pkhand
	
	ledge_ray = RayCast3D.new()
	ledge_ray.target_position = Vector3(0, -2.5, 0)
	add_child(ledge_ray)
	
	var canvas_layer = CanvasLayer.new()
	var crosshair_bg = CenterContainer.new()
	crosshair_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crosshair_rect = TextureRect.new()
	crosshair_rect.texture = tex_crosshair
	crosshair_rect.custom_minimum_size = Vector2(32, 32)
	crosshair_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crosshair_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_bg.add_child(crosshair_rect)
	canvas_layer.add_child(crosshair_bg)
	add_child(canvas_layer)
	
	blob_shadow_ray = RayCast3D.new()
	blob_shadow_ray.target_position = Vector3(0, -100, 0)
	add_child(blob_shadow_ray)
	
	blob_shadow_mesh = MeshInstance3D.new()
	blob_shadow_mesh.top_level = true
	var smesh = CylinderMesh.new()
	smesh.height = 0.01
	smesh.top_radius = 0.35
	smesh.bottom_radius = 0.35
	var smat = StandardMaterial3D.new()
	smat.albedo_color = Color(0, 0, 0, 0.5)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_shadow_mesh.mesh = smesh
	blob_shadow_mesh.material_override = smat
	add_child(blob_shadow_mesh)
	
	if not equipped_heavy_attack:
		var default_heavy = load("res://scripts/weapons/data/instances/heavy_attacks/default_heavy.tres")
		if default_heavy:
			equipped_heavy_attack = default_heavy
			
	if not equipped_dash:
		equipped_dash = load("res://scripts/weapons/data/instances/dashes/default_dash.tres")
		
	if not equipped_ability:
		equipped_ability = load("res://scripts/weapons/data/instances/abilities/default_ability.tres")
		
	if not equipped_attachment:
		equipped_attachment = load("res://scripts/weapons/data/instances/attachments/default_attachment.tres")

	# --- Melee Hitbox Setup ---
	melee_hitbox = Area3D.new()
	melee_hitbox.name = "MeleeHitbox"
	melee_hitbox.collision_layer = 0
	melee_hitbox.collision_mask = 1

	var col = CollisionShape3D.new()
	melee_hitbox_shape = BoxShape3D.new()
	melee_hitbox_shape.size = hitbox_size_light
	col.shape = melee_hitbox_shape
	melee_hitbox.add_child(col)
	melee_hitbox.position = hitbox_offset
	camera_pivot.add_child(melee_hitbox)

	# Debug mesh — a wireframe outline, shown only while swinging
	melee_hitbox_debug_mesh = MeshInstance3D.new()
	var dbg_mesh = BoxMesh.new()
	melee_hitbox_debug_mesh.mesh = dbg_mesh
	
	var dbg_mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
		shader_type spatial;
		render_mode unshaded, wireframe;
		void fragment() {
			ALBEDO = vec3(1.0, 0.2, 0.1);
		}
	"""
	dbg_mat.shader = shader
	melee_hitbox_debug_mesh.material_override = dbg_mat
	melee_hitbox_debug_mesh.visible = false
	melee_hitbox.add_child(melee_hitbox_debug_mesh)

	# HandManager Setup
	hand_manager = HandManager.new()
	hand_manager.name = "HandManager"
	var resolver = ShotResolver.new()
	resolver.name = "ShotResolver"
	hand_manager.add_child(resolver)
	add_child(hand_manager)
	
	resolver.player_camera = camera
	resolver.muzzle_point = pk_hand
	hand_manager.hand_changed.connect(_on_hand_changed)
	
	if not equipped_hand:
		equipped_hand = load("res://scripts/weapons/data/instances/hands/charge_projectile_hand.tres")
	
	if equipped_hand:
		hand_manager.equip_hand(equipped_hand, equipped_attachment)
		
	if use_outline:
		_setup_outlines()

func _refresh_outlines():
	if not is_node_ready(): return
	if not use_outline:
		var parts = [base_sprite, pk_body, pk_arm, pk_hand]
		for s in parts:
			if s and is_instance_valid(s):
				s.material_overlay = null
	else:
		_setup_outlines()

func _setup_outlines():
	if not use_outline: return
	var outline_shader = preload("res://materials/depth_outline.gdshader")
	var parts = [base_sprite, pk_body, pk_arm, pk_hand]
	for s in parts:
		if s and is_instance_valid(s):
			var mat = ShaderMaterial.new()
			mat.shader = outline_shader
			mat.set_shader_parameter("tex", s.texture)
			mat.set_shader_parameter("outline_color", outline_color)
			mat.set_shader_parameter("outline_width", outline_width)
			mat.set_shader_parameter("depth_offset", outline_depth_offset)
			s.material_overlay = mat

func _set_base_texture(tex: Texture2D):
	if base_sprite.texture != tex:
		base_sprite.texture = tex
		if base_sprite.material_overlay is ShaderMaterial:
			base_sprite.material_overlay.set_shader_parameter("tex", tex)


func _on_hand_changed(hand: HandData):
	if hand and hand.hand_texture:
		pk_hand.texture = hand.hand_texture
		if pk_hand.material_overlay is ShaderMaterial:
			pk_hand.material_overlay.set_shader_parameter("tex", pk_hand.texture)


func update_equipment():
	if equipped_hand:
		var att = equipped_attachment if is_attachment_active else null
		hand_manager.equip_hand(equipped_hand, att)

func _input(event):
	if event is InputEventKey and event.keycode == KEY_R and event.pressed:
		get_tree().reload_current_scene()
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/2.5, PI/2.5)
	
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	if is_dead:
		death_timer -= delta
		
		# Death Visuals: Spin and Turn Red
		death_rotation += delta * 15.0 # Fast spin
		base_sprite.rotation.z = death_rotation
		base_sprite.modulate = Color(2.0, 0.2, 0.2) # Glowing red
		pk_body.modulate = Color(2.0, 0.2, 0.2)
		pk_arm.modulate = Color(2.0, 0.2, 0.2)
		pk_hand.modulate = Color(2.0, 0.2, 0.2)
		
		# Handle death-specific movement (let knockback carry them)
		if not knockback_comp.is_in_hitstun():
			velocity.y -= gravity * delta
			move_and_slide()
			
		# Camera still follows
		var target_cam_pos = global_position + Vector3(0, 1.5, 0)
		camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, delta * camera_follow_speed)
		
		if death_timer <= 0:
			_respawn()
		return
		
	# Timers
	if long_jump_timer > 0:
		long_jump_timer -= delta
		
	if invincibility_timer > 0:
		invincibility_timer -= delta
		# Visual flickering for I-frames
		visuals.visible = fmod(invincibility_timer, 0.1) > 0.05
	else:
		visuals.visible = true
		
	# Input Direction - Calculated early so all systems can access it
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_dir = (camera_pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
	if flash_timer > 0:
		flash_timer -= delta
		_apply_visual_flash(true)
	else:
		_apply_visual_flash(false)

	# Handle Knockback
	if knockback_comp and knockback_comp.is_in_hitstun():
		return # Let component handle movement


	# Kill floor respawn
	if global_position.y < kill_floor_y:
		global_position = spawn_point
		velocity = Vector3.ZERO
		camera_pivot.global_position = spawn_point + Vector3(0, 1.5, 0)
		is_dashing = false
		is_charging_melee = false
		is_swinging_melee = false
		return

	# Update blob shadow
	blob_shadow_ray.global_position = global_position
	blob_shadow_ray.force_raycast_update()
	if blob_shadow_ray.is_colliding():
		blob_shadow_mesh.visible = true
		blob_shadow_mesh.global_position = blob_shadow_ray.get_collision_point() + Vector3(0, 0.05, 0)
	else:
		blob_shadow_mesh.visible = false

	# Camera follow delay
	var target_cam_pos = global_position + Vector3(0, 1.5, 0)
	camera_pivot.global_position = camera_pivot.global_position.lerp(target_cam_pos, delta * camera_follow_speed)
	
	var crouch_pressed = Input.is_action_pressed("sneak")
	
	if ability_cooldown_timer > 0:
		ability_cooldown_timer -= delta
		
	if Input.is_action_just_pressed("ability") and equipped_ability and ability_cooldown_timer <= 0:
		if equipped_ability.execute(self):
			ability_cooldown_timer = equipped_ability.cooldown_sec
			
	if Input.is_action_just_pressed("toggle_attachment"):
		is_attachment_active = not is_attachment_active
		update_equipment()
	
	# Floor and Wall Resets
	if is_on_floor():
		can_air_dash = true
		is_wall_running = false
		coyote_timer = coyote_time
		current_air_jumps = max_air_jumps
		
		# Clamp to run speed on landing (unless actively sliding)
		if not was_on_floor_last_frame and not crouch_pressed:
			var curr_hz = Vector3(velocity.x, 0, velocity.z)
			if curr_hz.length() > speed:
				curr_hz = curr_hz.normalized() * speed
				velocity.x = curr_hz.x
				velocity.z = curr_hz.z
	else:
		if coyote_timer > 0:
			coyote_timer -= delta
			
	if is_on_wall():
		can_air_dash = true
		current_air_jumps = max_air_jumps

	was_on_floor_last_frame = is_on_floor()

	# Wall State Detection
	var touching_wall = is_on_wall() and not is_on_floor()
	var wall_normal = Vector3.ZERO
	if touching_wall:
		wall_normal = get_wall_normal()
	
	# Melee Logic (Input, Swing timers)
	var melee_pressed = Input.is_action_pressed("melee")
	
	if heavy_melee_cooldown_timer > 0:
		heavy_melee_cooldown_timer -= delta
	
	if is_charging_melee:
		if Input.is_action_just_pressed("shoot") or crouch_pressed:
			is_charging_melee = false
			melee_charge_timer = 0.0
		elif not melee_pressed or melee_charge_timer >= 3.0:
			var charge_threshold = equipped_heavy_attack.charge_threshold if equipped_heavy_attack else 0.3
			is_charging_melee = false
			is_swinging_melee = true
			has_pogoed_this_swing = false
			hit_entities_this_swing.clear()
			
			var look_dir = -camera.global_transform.basis.z
			if look_dir.length_squared() > 0:
				look_dir = look_dir.normalized()
				
			if melee_charge_timer >= charge_threshold and equipped_heavy_attack and heavy_melee_cooldown_timer <= 0:
				melee_is_heavy = true
				melee_active_swing_duration = equipped_heavy_attack.swing_duration
				velocity += look_dir * equipped_heavy_attack.lunge_boost
				heavy_melee_cooldown_timer = equipped_heavy_attack.cooldown_duration
			else:
				melee_is_heavy = false
				melee_active_swing_duration = base_swing_duration
				velocity += look_dir * melee_light_boost
				
			melee_swing_timer = melee_active_swing_duration
			melee_charge_timer = 0.0
		else:
			melee_charge_timer += delta
	elif melee_pressed and not is_swinging_melee:
		is_charging_melee = true
		melee_charge_timer = 0.0

	# Melee Pogo collision handler
	if is_swinging_melee:
		_process_melee_active_frames()
		
		var window_ratio = equipped_heavy_attack.lunge_window_ratio if melee_is_heavy and equipped_heavy_attack else base_lunge_window_ratio
		var passed_ratio = 1.0 - (melee_swing_timer / melee_active_swing_duration)
		
		# If the lunge window has passed, aggressively dampen horizontal momentum
		if passed_ratio > window_ratio:
			var damp_speed = speed
			var hz_vel = Vector3(velocity.x, 0, velocity.z)
			if hz_vel.length() > damp_speed:
				hz_vel = hz_vel.move_toward(hz_vel.normalized() * damp_speed, 150.0 * delta)
				velocity.x = hz_vel.x
				velocity.z = hz_vel.z
		
		melee_swing_timer -= delta
		if melee_swing_timer <= 0:
			is_swinging_melee = false
			if melee_hitbox_debug_mesh:
				melee_hitbox_debug_mesh.visible = false
			
		if melee_is_heavy and not has_pogoed_this_swing and touching_wall:
			_execute_pogo(wall_normal, 1.0) # Walls always provide 100% bounce

	# Airborne Logic & Gravity
	wall_latch = false
	
	if not is_on_floor():
		if touching_wall:
			if is_dashing:
				is_wall_running = true
				velocity.y = move_toward(velocity.y, 0, gravity * delta * 2.0)
			else:
				is_wall_running = false
				if crouch_pressed:
					wall_latch = true
					velocity.y = max(velocity.y, wall_slide_speed)
				elif velocity.y < 0:
					velocity.y = max(velocity.y, wall_slide_speed)
				else:
					velocity.y -= gravity * delta
		else:
			is_wall_running = false
			if crouch_pressed and long_jump_timer <= 0:
				velocity.y = ground_pound_speed
			elif not is_swinging_melee:
				velocity.y -= gravity * delta
	else:
		is_wall_running = false

	# Jump Buffer & Coyote & Double Jump
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	elif jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# Variable Jump Height (Short Hop): Cut upward velocity when jump is released early
	if Input.is_action_just_released("jump") and velocity.y > 0 and not is_on_floor():
		velocity.y *= short_hop_multi

	if jump_buffer_timer > 0:
		if is_on_floor() or coyote_timer > 0:
			var current_spd = Vector3(velocity.x, 0, velocity.z).length()
			# Even more permissive: check for high speed + crouch button directly
			var long_jump_eligible = is_sliding or (Input.is_action_pressed("sneak") and current_spd > speed + 0.1)
			
			if long_jump_eligible:
				print("LONG JUMP TRIGGERED! Speed: ", current_spd)
				# Long Jump: Jumping while sliding at high speeds
				# Hold Control for a low, fast arc; Release for a high, floating arc
				var jump_arc_multi = 0.65 if crouch_pressed else 1.2
				velocity.y = jump_velocity * jump_arc_multi
				
				# Set a small grace period where holding Control won't trigger a ground-pound
				if crouch_pressed:
					long_jump_timer = 0.5 
				
				# Give a horizontal speed boost based on slide momentum
				var hz_boost = 1.1 # 10% extra horizontal kick
				velocity.x *= hz_boost
				velocity.z *= hz_boost
				
				# Add a flat forward "leap" force — use velocity dir if no input is held
				var leap_dir = move_dir if move_dir != Vector3.ZERO else Vector3(velocity.x, 0, velocity.z).normalized()
				velocity += leap_dir * 10.0
			else:
				# Normal jump
				velocity.y = jump_velocity
				
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
		elif touching_wall:
			velocity.y = jump_velocity
			velocity += wall_normal * speed
			is_dashing = false
			can_air_dash = true
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
		elif current_air_jumps > 0:
			velocity.y = jump_velocity
			current_air_jumps -= 1
			jump_buffer_timer = 0.0
			is_dashing = false # Break out of dash

	# Dash
	if Input.is_action_just_pressed("dash") and not is_dashing:
		if is_on_floor() or can_air_dash:
			is_dashing = true
			dash_timer = equipped_dash.duration_sec if equipped_dash else 0.2
			if not is_on_floor():
				can_air_dash = false
			
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			is_wall_running = false
			
			# Exit dash smoothly into run speed IF we aren't B-hopping
			var is_b_hopping = not is_on_floor() or crouch_pressed
			if not is_b_hopping:
				var hz_vel = Vector3(velocity.x, 0, velocity.z)
				if hz_vel.length() > speed:
					hz_vel = hz_vel.normalized() * speed
					velocity.x = hz_vel.x
					velocity.z = hz_vel.z


	
	# Slope Detection
	var slope_angle = 0.0
	var is_on_slope = false
	var floor_normal = Vector3.UP
	if is_on_floor():
		floor_normal = get_floor_normal()
		slope_angle = floor_normal.angle_to(Vector3.UP)
		if slope_angle > deg_to_rad(slide_slope_threshold_deg):
			is_on_slope = true
	
	var slope_factor = move_dir.dot(floor_normal) if is_on_floor() else 0.0
	
	# Ground Sneak and Slide logic
	is_sneaking = false
	if crouch_pressed and is_on_floor():
		# Maintain slide even on flat ground if we have high momentum
		var can_slide = is_on_slope or (is_sliding and current_slide_speed > speed + 1.0)
		
		if can_slide:
			if not is_sliding:
				is_sliding = true
				var current_hz_speed_init = Vector3(velocity.x, 0, velocity.z).length()
				current_slide_speed = max(current_hz_speed_init, speed + slide_boost)
				initial_slide_speed = current_slide_speed
		else:
			is_sneaking = true
			is_sliding = false
	else:
		# If we were sliding and released Control (or jumped), return to run speed
		# BUT skip clamping if we just did a long jump — preserve the momentum!
		if is_sliding and long_jump_timer <= 0:
			var hz_vel = Vector3(velocity.x, 0, velocity.z)
			if hz_vel.length() > speed:
				var clamped = hz_vel.normalized() * speed
				velocity.x = clamped.x
				velocity.z = clamped.z
		is_sliding = false

	# Slide Funneling (Gravity pulling you down slopes)
	# Only funnel if we are actually moving downhill (slope_factor > 0)
	if is_sliding and is_on_slope and slope_factor > 0.0:
		var downhill_dir = (Vector3.DOWN - floor_normal * Vector3.DOWN.dot(floor_normal)).normalized()
		
		# Reduced funneling strength so the player can steer away from the downhill path
		var funnel_strength = clamp(current_slide_speed / (speed + slide_boost), 0.1, 0.4)
		if move_dir != Vector3.ZERO:
			move_dir = move_dir.lerp(downhill_dir, funnel_strength).normalized()
		else:
			move_dir = downhill_dir

	if is_sliding:
		# Calculate dynamic friction based on slope
		var dynamic_friction = slide_friction
		
		if slope_factor < -0.01:
			# Going uphill: Increase friction to drain momentum (much more forgiving now)
			dynamic_friction -= slope_factor * 80.0
		elif slope_factor > 0.15:
			# Going downhill: More gradual acceleration (negative friction)
			# Only triggers on slopes steeper than ~8.6 degrees
			dynamic_friction = -12.0 - (slope_factor * 60.0)
			
		current_slide_speed -= dynamic_friction * delta
		
		# If going uphill, we lose all momentum and drop to a crawl (sneak speed). 
		# If flat or downhill, we maintain at least walking speed.
		var min_speed = (speed * sneak_speed_multi) if slope_factor < -0.05 else speed
		
		# Uncapped downhill speed - let the momentum build like water!
		current_slide_speed = max(current_slide_speed, min_speed)

	var target_speed = speed
	if is_dashing or is_wall_running:
		target_speed = equipped_dash.speed if equipped_dash else 60.0
	elif is_sliding:
		target_speed = current_slide_speed
	elif is_sneaking:
		target_speed = speed * sneak_speed_multi
	elif is_charging_melee and is_on_floor():
		target_speed = speed * melee_charge_slow
	
	# Skater Camera Tilt (Procedural Roll)
	var target_roll = 0.0
	target_roll -= input_dir.x * max_camera_roll
	if is_wall_running:
		var w_dot = camera_pivot.transform.basis.x.dot(wall_normal)
		target_roll += sign(w_dot) * 15.0 # Aggressive lean away from wall
	camera.rotation_degrees.z = lerp(camera.rotation_degrees.z, target_roll, delta * 10.0)

	# Ledge Prevention (Edge Detection)
	if is_sneaking and move_dir != Vector3.ZERO and is_on_floor():
		ledge_ray.global_position = global_position + (move_dir.normalized() * 0.8) + Vector3(0, 0.5, 0)
		ledge_ray.force_raycast_update()
		if not ledge_ray.is_colliding():
			move_dir = Vector3.ZERO 

	# Force latch to wall
	if wall_latch:
		move_dir = -wall_normal
		
	# Assume forward dash if no input
	if is_dashing and move_dir == Vector3.ZERO:
		var cam_forward = -camera_pivot.global_transform.basis.z
		cam_forward.y = 0
		if cam_forward.length_squared() > 0:
			move_dir = cam_forward.normalized()

	# Apply Movement
	var current_hz_speed = Vector3(velocity.x, 0, velocity.z).length()
	
	if move_dir != Vector3.ZERO:
		var accel = acceleration
		if not is_on_floor(): accel *= 0.5
		if is_dashing: accel = 2000.0 
		if is_sneaking: accel = 500.0 
		if is_sliding:
			# Smoothly scale down accel the steeper uphill you go
			# slope_factor is negative uphill; clamp to 0..1 range for lerp
			var uphill_t = clamp(-slope_factor * 10.0, 0.0, 1.0)
			accel = lerp(1000.0, 80.0, uphill_t)
		
		# Boost accel when turning: the more perpendicular the input, the bigger the kick
		var dot = move_dir.dot(Vector3(velocity.x, 0, velocity.z).normalized())
		var turn_t = clamp(1.0 - dot, 0.0, 1.0)  # 0 = going straight, 1 = full reverse
		var effective_accel = accel * lerp(1.0, turn_accel_multi, turn_t)
		if (is_sliding and is_on_floor()) or current_hz_speed < target_speed or dot < 0.7:
			velocity.x = move_toward(velocity.x, move_dir.x * target_speed, effective_accel * delta)
			velocity.z = move_toward(velocity.z, move_dir.z * target_speed, effective_accel * delta)
	else:
		var fric = friction
		if not is_on_floor(): fric *= 0.5
		
		# If we are moving faster than max speed (from a blast), use lower friction so we sail!
		if current_hz_speed > target_speed + 2.0:
			fric = 5.0 # Air resistance style
			
		velocity.x = move_toward(velocity.x, 0, fric * delta)
		velocity.z = move_toward(velocity.z, 0, fric * delta)

	# Safety net: Global speed cap (Horizontal only)
	var global_max_speed = speed * max_speed_multi
	var hz_vel_current = Vector3(velocity.x, 0, velocity.z)
	if hz_vel_current.length() > global_max_speed:
		var clamped_hz = hz_vel_current.normalized() * global_max_speed
		velocity.x = clamped_hz.x
		velocity.z = clamped_hz.z

	# Increase floor snap to keep player glued to slopes during fast slides
	floor_snap_length = 0.5 if is_sliding else 0.1
	move_and_slide()
	
	if is_sliding and current_slide_speed <= speed + 0.1 and not is_on_slope:
		is_sliding = false
		
	# Shooting Logic & Zoom Linger
	if zoom_linger_timer > 0:
		zoom_linger_timer -= delta

	var trigger_pressed = Input.is_action_pressed("shoot") and not is_charging_melee
	hand_manager.set_trigger(trigger_pressed)
	
	if trigger_pressed:
		zoom_linger_timer = 0.5
		
	aim_mode = trigger_pressed or zoom_linger_timer > 0

	# Dynamic Camera FOV Zoom
	var target_fov = base_fov
	if not is_on_floor():
		if is_dashing:
			target_fov = jump_fov + 15.0 # Extra FOV kick during air dash
		else:
			target_fov = jump_fov
	
	# Add speed-based FOV scaling (highly noticeable when sliding downhill)
	var speed_bonus = max(0.0, current_hz_speed - speed)
	target_fov += speed_bonus * 1.5 # 1.5 FOV units per m/s above walk speed
	
	if aim_mode or zoom_linger_timer > 0:
		target_fov = shoot_fov
	camera.fov = lerp(camera.fov, target_fov, delta * fov_lerp_speed)
	
	# Update Debug UI at the end of the frame
	if debug_ui_label and hand_manager:
		var max_ink = hand_manager.current_hand.max_ink if hand_manager.current_hand else 0.0
		var att_status = "ON" if is_attachment_active else "OFF"
		var horiz_vel = Vector3(velocity.x, 0, velocity.z).length()
		var long_jump_text = " [LONG JUMP!]" if long_jump_timer > 0 else ""
		debug_ui_label.text = "Speed: %.1f (Tgt: %.1f) m/s%s\nInk: %.1f / %.1f\nCharge: %.2fs\nAtt: %s" % [horiz_vel, target_speed, long_jump_text, hand_manager.current_ink, max_ink, hand_manager.charge_accumulated, att_status]
	
	var is_on_wall_visual = touching_wall 
	update_visuals(input_dir, is_on_wall_visual, wall_normal)

# Hand logic has been migrated exclusively to HandManager

func update_visuals(input_dir: Vector2, touching_wall: bool, wall_normal: Vector3):
	base_sprite.rotation_degrees.z = 0.0
	base_sprite.flip_h = false
	
	if aim_mode or is_charging_melee or is_swinging_melee:
		base_sprite.visible = false
		aim_setup.visible = true
		
		aim_setup.rotation.y = camera_pivot.rotation.y
		
		# Animate the Melee Swing
		var target_pitch = spring_arm.rotation.x
		var hand_pos = Vector3(0.35, 0.2, -0.5)
		
		if is_charging_melee:
			var charge_threshold = equipped_heavy_attack.charge_threshold if equipped_heavy_attack else 0.3
			var charge_ratio = clamp(melee_charge_timer / charge_threshold, 0.0, 1.0)
			# Tilt backwards heavily (positive Z rads tilt UP visually in local)
			target_pitch += lerp(0.0, deg_to_rad(60.0), charge_ratio)
			hand_pos += Vector3(0.0, charge_ratio * 0.3, charge_ratio * 0.2)
		elif is_swinging_melee:
			var swing_progress = 1.0 - (melee_swing_timer / melee_active_swing_duration)
			var base_arc = deg_to_rad(60.0) if melee_is_heavy else deg_to_rad(30.0)
			# Swipe from max cockback all the way down to strike point
			var strike_arc = lerp(base_arc, deg_to_rad(-45.0), swing_progress)
			target_pitch += strike_arc
			
			# Push punch out
			hand_pos += Vector3(-0.15, -swing_progress * 0.2, -sin(swing_progress * PI) * 0.8)
			
		pk_arm.rotation.z = target_pitch
		pk_hand.rotation.z = target_pitch
		
		pk_arm.position = Vector3(0.2, 0.2, -0.2)
		pk_hand.position = hand_pos
	else:
		base_sprite.visible = true
		aim_setup.visible = false
		
		if is_wall_running:
			_set_base_texture(tex_run)
			var dot = camera_pivot.transform.basis.x.dot(wall_normal)
			if dot > 0:
				base_sprite.rotation_degrees.z = -wall_run_tilt 
			else:
				base_sprite.rotation_degrees.z = wall_run_tilt
		elif is_dashing:
			_set_base_texture(tex_dash)
		elif touching_wall:
			_set_base_texture(tex_jump)
		elif not is_on_floor():
			_set_base_texture(tex_jump)
		elif is_sliding:
			_set_base_texture(tex_slide)
		elif is_sneaking:
			_set_base_texture(tex_sneak)
		elif Input.is_action_pressed("interact"):
			_set_base_texture(tex_backup)
		elif input_dir == Vector2.ZERO:
			_set_base_texture(tex_idle)
		else:
			if input_dir.y > 0.5:
				_set_base_texture(tex_backup)
			elif input_dir.x > 0.5:
				_set_base_texture(tex_sideinvert)
				base_sprite.flip_h = true
			elif input_dir.x < -0.5:
				_set_base_texture(tex_side)
			else:
				_set_base_texture(tex_run)

func apply_kickback(force: Vector3):
	velocity += force
	if is_on_floor() and force.length() > 5.0:
		velocity.y += force.length() * 0.15 # Add an actual physical jump velocity perfectly scaled to the weapon

func take_damage(amount: float, force_dir: Vector3 = Vector3.ZERO, raw_force: float = 0.0, iframe_dur: float = 0.8, min_stun: float = 0.05):
	if invincibility_timer > 0 and iframe_dur > 0:
		return
		
	current_health -= amount
	current_health = clamp(current_health, 0.0, max_health)
	
	# Start I-frames and Flash (only if requested)
	if iframe_dur > 0:
		invincibility_timer = iframe_dur
		
	flash_timer = 0.15 # Still flash visually so we know we're hurting
	
	# Apply Knockback with health and ammo-based scaling
	if knockback_comp and force_dir != Vector3.ZERO:
		# 1. Health Multiplier: 1.0x at 100%, up to 3.0x at 0%
		var health_ratio = current_health / max_health
		var health_mult = 1.0 + (1.0 - health_ratio) * 4.0
		
		# 2. Ammo (Ink) Multiplier: 1.0x at Full, up to 2.0x at Empty
		var ammo_mult = 1.0
		if hand_manager and hand_manager.current_hand:
			var ammo_ratio = hand_manager.current_ink / hand_manager.current_hand.max_ink
			ammo_mult = 1.0 + (1.0 - ammo_ratio) * 3.0 # Max 2.0x weight loss from low ink
			
		var total_mult = health_mult * ammo_mult
		
		# 3. Base Force + Attack Bonus
		var base_force = 120.0 # Guaranteed base nudge
		var final_force = (base_force + raw_force) * total_mult
		
		knockback_comp.apply_knockback(force_dir, final_force, min_stun)
	
	if health_bar:
		health_bar.value = current_health
		
	if current_health <= 0 and not is_dead:
		die()

func _apply_visual_flash(active: bool):
	var color = Color(5.0, 5.0, 5.0) if active else Color.WHITE # Overbright white
	base_sprite.modulate = color
	pk_body.modulate = color
	pk_arm.modulate = color
	pk_hand.modulate = color

func heal(amount: float):
	current_health += amount
	current_health = clamp(current_health, 0.0, max_health)
	if health_bar:
		health_bar.value = current_health

func die():
	is_dead = true
	death_timer = 2.0
	death_rotation = 0.0
	# Optional: Give a final "pop" if they aren't moving much
	if velocity.length() < 10.0:
		velocity += Vector3(randf_range(-5,5), 15.0, randf_range(-5,5))

func _respawn():
	is_dead = false
	current_health = max_health
	if health_bar: health_bar.value = max_health
	global_position = spawn_point
	velocity = Vector3.ZERO
	camera_pivot.global_position = spawn_point + Vector3(0, 1.5, 0)
	
	# Reset visuals
	base_sprite.rotation.z = 0
	base_sprite.modulate = Color.WHITE
	pk_body.modulate = Color.WHITE
	pk_arm.modulate = Color.WHITE
	pk_hand.modulate = Color.WHITE
	
	# Reset states
	is_dashing = false
	is_charging_melee = false
	is_swinging_melee = false
	ability_cooldown_timer = 0.0
	current_health = max_health
	if health_bar:
		health_bar.value = current_health

# --- Melee Framework ---

func _process_melee_active_frames():
	if not melee_hitbox: return
	
	# Sync position and vertical rotation
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var horizontal_shift = input_dir.x * melee_strafe_shift
	melee_hitbox.position = hitbox_offset + Vector3(horizontal_shift, 0, 0)
	
	melee_hitbox.rotation.x = spring_arm.rotation.x
	
	# Size the hitbox for the current attack type
	var target_size = hitbox_size_heavy if melee_is_heavy else hitbox_size_light
	if melee_hitbox_shape.size != target_size:
		melee_hitbox_shape.size = target_size
		if melee_hitbox_debug_mesh and melee_hitbox_debug_mesh.mesh is BoxMesh:
			(melee_hitbox_debug_mesh.mesh as BoxMesh).size = target_size
	
	# Show debug visualization
	if hitbox_debug_visible and melee_hitbox_debug_mesh:
		melee_hitbox_debug_mesh.visible = true
	
	var overlap = melee_hitbox.get_overlapping_bodies()
	for body in overlap:
		if body == self: continue
		if body in hit_entities_this_swing: continue
		
		hit_entities_this_swing.append(body)
		
		# Modular definition, easily swappable based on equipped heavy attack
		var dmg = equipped_heavy_attack.damage if melee_is_heavy and equipped_heavy_attack else melee_light_damage
		var force = equipped_heavy_attack.knockback_force if melee_is_heavy and equipped_heavy_attack else melee_light_force
		var hitstop = equipped_heavy_attack.hitstop_duration if melee_is_heavy and equipped_heavy_attack else melee_light_hitstop
		_apply_melee_hit(body, dmg, force, hitstop)

func _apply_melee_hit(target: Node, damage: float, force: float, hitstop: float):
	var hit_connected = false
	
	if target.has_method("take_damage"):
		target.take_damage(damage)
		hit_connected = true
		
	if "knockback_comp" in target and target.knockback_comp:
		var hit_dir = -camera_pivot.global_transform.basis.z.normalized()
		hit_dir += Vector3.UP * 0.25 # Upward tilt for a launcher effect
		target.knockback_comp.apply_knockback(hit_dir.normalized(), force)
		hit_connected = true
		
	if hit_connected:
		_trigger_hitstop(hitstop)
		if melee_is_heavy:
			if not has_pogoed_this_swing:
				var impact_normal = (global_position - target.global_position).normalized()
				
				# Scale pogo force by enemy size: bigger = more bounce
				var size_mult = 1.0
				if "scale" in target:
					# Average the scale for a more accurate 'size' feel
					var avg_scale = (target.scale.x + target.scale.y + target.scale.z) / 3.0
					size_mult = clamp(avg_scale, 0.8, 1.4)
					
				if "has_bubble" in target and target.has_bubble:
					size_mult *= 2.2 # MASSIVELY increases pogo bounce
					impact_normal = Vector3.UP # Force perfectly upward bounce
					velocity.y = max(0, velocity.y) # Erase falling velocity so it's always a huge bounce
				
				_execute_pogo(impact_normal, size_mult)
				
			if equipped_heavy_attack and equipped_heavy_attack.refund_on_hit:
				heavy_melee_cooldown_timer = 0.0

func _execute_pogo(impact_normal: Vector3, multiplier: float = 1.0):
	if has_pogoed_this_swing: return
	has_pogoed_this_swing = true
	
	var bias = equipped_heavy_attack.pogo_upward_bias if equipped_heavy_attack else base_pogo_upward_bias
	var bounce_dir = impact_normal + Vector3.UP * bias
	var pogo_force = equipped_heavy_attack.pogo_bounce if equipped_heavy_attack else base_pogo_bounce
	
	# Apply size scaling
	velocity += bounce_dir.normalized() * (pogo_force * multiplier)
	can_air_dash = true
	current_air_jumps = max_air_jumps
	is_swinging_melee = false # Force cancel the visual swing to show impact

func _trigger_hitstop(duration: float):
	if duration <= 0: return
	Engine.time_scale = 0.05
	# ignore_time_scale = true allows the timer to run on real-world unscaled time
	var timer = get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func(): if is_inside_tree(): Engine.time_scale = 1.0)
