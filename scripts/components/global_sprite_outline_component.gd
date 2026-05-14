extends Node
class_name GlobalSpriteOutlineComponent

@export var outline_color: Color = Color.WHITE:
	set(val):
		outline_color = val
		_update_materials()
		
@export_range(1.0, 10.0) var outline_width: float = 1.0:
	set(val):
		outline_width = val
		_update_materials()
		
@export var depth_offset: float = 0.05:
	set(val):
		depth_offset = val
		_update_materials()

const SHADER = preload("res://materials/depth_outline.gdshader")
var active_materials: Array[ShaderMaterial] = []

func _ready():
	# Wait for the next frame so all children are fully initialized
	call_deferred("_apply_outlines")

func _apply_outlines():
	var parent = get_parent()
	if not parent: return
	_scan_and_apply(parent)

func _scan_and_apply(node: Node):
	if node is Sprite3D:
		var mat = ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("outline_color", outline_color)
		mat.set_shader_parameter("outline_width", outline_width)
		mat.set_shader_parameter("depth_offset", depth_offset)
		mat.set_shader_parameter("tex", node.texture)
		
		# Set as overlay so it draws over/under the base sprite without replacing it
		node.material_overlay = mat
		active_materials.append(mat)
		
	for child in node.get_children():
		_scan_and_apply(child)

func _update_materials():
	for mat in active_materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("outline_color", outline_color)
			mat.set_shader_parameter("outline_width", outline_width)
			mat.set_shader_parameter("depth_offset", depth_offset)

func _process(delta):
	# Keep textures in sync just in case animation swaps them
	if Engine.get_frames_drawn() % 5 == 0:
		_sync_textures(get_parent())

func _sync_textures(node: Node):
	if node is Sprite3D and node.material_overlay is ShaderMaterial:
		node.material_overlay.set_shader_parameter("tex", node.texture)
	for child in node.get_children():
		_sync_textures(child)
