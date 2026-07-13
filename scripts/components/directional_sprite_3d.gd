@tool
extends Sprite3D
class_name DirectionalSprite3D

const OUTLINE_SHADER_CODE = """
shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width = 1.0;

void fragment() {
	vec4 base_color = texture(tex, UV) * COLOR;
	vec2 size = vec2(textureSize(tex, 0));
	
	float outline = 0.0;
	
	outline += texture(tex, UV + vec2(-outline_width, 0.0) / size).a;
	outline += texture(tex, UV + vec2(outline_width, 0.0) / size).a;
	outline += texture(tex, UV + vec2(0.0, -outline_width) / size).a;
	outline += texture(tex, UV + vec2(0.0, outline_width) / size).a;
	
	outline += texture(tex, UV + vec2(-outline_width, outline_width) / size).a;
	outline += texture(tex, UV + vec2(outline_width, outline_width) / size).a;
	outline += texture(tex, UV + vec2(-outline_width, -outline_width) / size).a;
	outline += texture(tex, UV + vec2(outline_width, -outline_width) / size).a;
	
	outline = min(outline, 1.0);
	
	vec4 final_color = base_color;
	if (base_color.a < 0.1 && outline > 0.1) {
		final_color = outline_color * COLOR;
	}

	
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.1;
}
"""

@export_group("Textures")
@export var main_texture: Texture2D:
	set(val):
		main_texture = val
		_update_texture_state()

@export var above_texture: Texture2D:
	set(val):
		above_texture = val
		_update_texture_state()

@export var below_texture: Texture2D:
	set(val):
		below_texture = val
		_update_texture_state()

@export_group("Billboard Settings")
## If false, uses Godot's instant built-in billboard. If true, manually rotates smoothly.
@export var use_smooth_billboard: bool = true:
	set(val):
		use_smooth_billboard = val
		_update_billboard_mode()

## If true, the sprite will only rotate on the horizontal Y-axis, keeping it perfectly upright and aligned with character collision.
@export var fixed_y_billboard: bool = false:
	set(val):
		fixed_y_billboard = val
		_update_billboard_mode()

## How fast the sprite rotates to face the camera (lower = more drifty delay)
@export var smooth_speed: float = 8.0

## The angle (in degrees) to switch to the above/below sprite.
@export_range(0.0, 90.0) var vertical_angle_threshold: float = 25.0:
	set(val):
		vertical_angle_threshold = val
		_update_texture_state()



@export_group("Outline Settings")
@export var use_outline: bool = false:
	set(val):
		use_outline = val
		_update_material()

@export var outline_color: Color = Color.WHITE:
	set(val):
		outline_color = val
		_update_material()

@export_range(1.0, 10.0) var outline_width: float = 1.0:
	set(val):
		outline_width = val
		_update_material()


func _ready():
	_update_billboard_mode()

func _update_billboard_mode():
	if Engine.is_editor_hint() or not use_smooth_billboard:
		if fixed_y_billboard:
			billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		else:
			billboard = BaseMaterial3D.BILLBOARD_ENABLED
	else:
		billboard = BaseMaterial3D.BILLBOARD_DISABLED


func _process(delta: float):

	var cam = _get_camera()
	if not cam:
		return

		
	var target_pos = cam.global_position
	# If the camera is exactly at our position, avoid errors
	if global_position.is_equal_approx(target_pos):
		return
		
	var dir_to_cam = (target_pos - global_position).normalized()
	
	# Texture Switching Logic
	var angle = rad_to_deg(asin(dir_to_cam.y))
	if angle > vertical_angle_threshold and above_texture != null:
		_set_active_texture(above_texture)
	elif angle < -vertical_angle_threshold and below_texture != null:
		_set_active_texture(below_texture)
	else:
		_set_active_texture(main_texture)

			
	# Smooth Rotation Logic
	if use_smooth_billboard and not Engine.is_editor_hint():
		var look_target = target_pos
		var up_vec = Vector3.UP
		
		if fixed_y_billboard:
			# Flatten the target position so we only rotate horizontally (Yaw)
			look_target.y = global_position.y
		else:
			if abs(dir_to_cam.y) > 0.99:
				up_vec = Vector3.RIGHT
				
		if not global_position.is_equal_approx(look_target):
			# Sprite3D's front is the +Z axis. look_at points the -Z axis at the target.
			# So we look away from the target to make the +Z axis face the target.
			var dir_from_target = (global_position - look_target).normalized()
			var reverse_target = global_position + dir_from_target
			
			var target_transform = global_transform.looking_at(reverse_target, up_vec)
			
			var current_quat = global_transform.basis.get_rotation_quaternion()
			var target_quat = target_transform.basis.get_rotation_quaternion()

			# Slerp for smooth rotation
			var next_quat = current_quat.slerp(target_quat, min(1.0, smooth_speed * delta))
			global_transform.basis = Basis(next_quat)
			
			# Ensure scale is preserved
			scale = scale

func _get_camera() -> Camera3D:
	if Engine.is_editor_hint():
		var vp = get_viewport()
		if vp and vp.get_camera_3d():
			return vp.get_camera_3d()
		# Fallback to finding any active camera in the editor tree
		var root = get_tree().root
		var cameras = root.find_children("*", "Camera3D", true, false)
		for c in cameras:
			if c.is_inside_tree() and c.current:
				return c as Camera3D
		if cameras.size() > 0:
			return cameras[0] as Camera3D
	else:
		if get_viewport():
			return get_viewport().get_camera_3d()
	return null

func _set_active_texture(new_tex: Texture2D):
	if texture != new_tex:
		texture = new_tex
		_update_material()

func _update_material():
	if use_outline:
		if not material_override or not material_override is ShaderMaterial:
			var mat = ShaderMaterial.new()
			var shader = Shader.new()
			shader.code = OUTLINE_SHADER_CODE
			mat.shader = shader
			material_override = mat
		
		var sm = material_override as ShaderMaterial
		sm.set_shader_parameter("tex", texture)
		sm.set_shader_parameter("outline_color", outline_color)
		sm.set_shader_parameter("outline_width", outline_width)
	else:
		material_override = null

	if material_overlay is ShaderMaterial:
		material_overlay.set_shader_parameter("tex", texture)

func _update_texture_state():
	# Used when changing properties in the editor
	if Engine.is_editor_hint() and not is_inside_tree():
		texture = main_texture
	_update_material()

