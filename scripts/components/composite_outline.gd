@tool
extends Node
class_name CompositeOutline

enum BillboardMode { DISABLED, SPHERICAL, FIXED_Y }

@export var outline_color: Color = Color.WHITE:
	set(val):
		outline_color = val
		_update_materials()

@export_range(1.0, 10.0) var outline_width: float = 1.0:
	set(val):
		outline_width = val
		_update_materials()

@export_range(0.0, 1.0) var depth_offset: float = 0.05:
	set(val):
		depth_offset = val
		_update_materials()

@export var billboard_mode: BillboardMode = BillboardMode.FIXED_Y:
	set(val):
		billboard_mode = val
		_rebuild_shader()

var shader: Shader

func _ready():
	_rebuild_shader()

func _rebuild_shader():
	if not shader:
		shader = Shader.new()
		
	var v_code = ""
	if billboard_mode == BillboardMode.FIXED_Y:
		v_code = """
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
"""
	elif billboard_mode == BillboardMode.SPHERICAL:
		v_code = """
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
"""

	var shader_code = """
shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width = 1.0;
uniform float depth_offset = 0.05;

void vertex() {
%s
	
	// Push into screen to prevent overlapping other sprites in front of it
	VERTEX.z -= depth_offset;
}

void fragment() {
	vec4 base_color = texture(tex, UV);
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
	
	if (base_color.a < 0.1 && outline > 0.1) {
		ALBEDO = outline_color.rgb * COLOR.rgb;
		ALPHA = 1.0;
	} else {
		ALPHA = 0.0;
	}
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
""" % v_code

	shader.code = shader_code
	_update_materials()

func _update_materials():
	if not is_inside_tree(): return
	if not shader: return
	
	var parent = get_parent()
	var sprites = _find_sprites(parent)
	
	for s in sprites:
		if not s.material_overlay or not s.material_overlay is ShaderMaterial:
			s.material_overlay = ShaderMaterial.new()
			s.material_overlay.shader = shader
		elif s.material_overlay.shader != shader:
			s.material_overlay.shader = shader
		
		var mat = s.material_overlay as ShaderMaterial
		mat.set_shader_parameter("tex", s.texture)
		mat.set_shader_parameter("outline_color", outline_color)
		mat.set_shader_parameter("outline_width", outline_width)
		mat.set_shader_parameter("depth_offset", depth_offset)

func _process(_delta):
	# Keep texture synced if animations change it in-game
	if not Engine.is_editor_hint():
		var parent = get_parent()
		var sprites = _find_sprites(parent)
		for s in sprites:
			if s.material_overlay is ShaderMaterial:
				s.material_overlay.set_shader_parameter("tex", s.texture)

func _find_sprites(node: Node) -> Array[Sprite3D]:
	var result: Array[Sprite3D] = []
	if node is Sprite3D:
		result.append(node)
	for child in node.get_children():
		if child != self:
			result.append_array(_find_sprites(child))
	return result
