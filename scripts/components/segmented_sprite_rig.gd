@tool
extends Node3D
class_name SegmentedSpriteRig

@export_group("Rig Settings")
@export var auto_sort: bool = true
@export var depth_spacing: float = 0.0 # Physical depth is handled purely by 2D z-index now
@export var face_camera: bool = true
@export var y_billboard_only: bool = true
@export var flip_horizontal: bool = false

@export_group("Procedural Animation")
@export var enable_animation: bool = true
@export var global_speed_scale: float = 1.0

var _time: float = 0.0
var _viewport: SubViewport
var _canvas_group: CanvasGroup
var _output_sprite: Sprite3D
var _sprite_map: Dictionary = {}

func _ready():
	if Engine.is_editor_hint(): return
	
	# Create 2D pipeline
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = Vector2i(1024, 1024)
	add_child(_viewport)
	
	_canvas_group = CanvasGroup.new()
	var outline_mat = ShaderMaterial.new()
	outline_mat.shader = preload("res://materials/canvas_outline.gdshader")
	var base_enemy = _find_base_enemy(self)
	var o_color = Color.WHITE
	var o_width = 4.0
	if base_enemy:
		o_color = base_enemy.outline_color
		o_width = base_enemy.outline_width
		if not base_enemy.use_outline:
			o_width = 0.0
	outline_mat.set_shader_parameter("outline_color", o_color)
	outline_mat.set_shader_parameter("outline_width", o_width)
	_canvas_group.material = outline_mat
	_viewport.add_child(_canvas_group)
	
	_output_sprite = Sprite3D.new()
	_output_sprite.texture = _viewport.get_texture()
	_output_sprite.pixel_size = 0.007
	_output_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
	_output_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(_output_sprite)
	
	# Map all Sprite3D children
	var all_sprites = _get_all_sprites(self, [])
	for child in all_sprites:
		if child is Sprite3D and child != _output_sprite:
			var s2d = Sprite2D.new()
			s2d.texture = child.texture
			s2d.hframes = child.hframes
			s2d.vframes = child.vframes
			s2d.frame = child.frame
			s2d.offset = child.offset
			s2d.centered = child.centered
			s2d.flip_h = child.flip_h
			s2d.flip_v = child.flip_v
			s2d.region_enabled = child.region_enabled
			s2d.region_rect = child.region_rect
			
			_canvas_group.add_child(s2d)
			_sprite_map[child] = s2d
			
			if _output_sprite.pixel_size == 0.007 and child.pixel_size > 0:
				_output_sprite.pixel_size = child.pixel_size
			
			child.visible = false

func _find_base_enemy(node: Node) -> Node:
	var curr = node.get_parent()
	while curr:
		if curr is BaseEnemy:
			return curr
		curr = curr.get_parent()
	return null

func _process(delta: float):
	if enable_animation and not Engine.is_editor_hint():
		_time += delta * global_speed_scale
		
	var sort_index = 0
	
	var all_sprites = _get_all_sprites(self, [])
	for child in all_sprites:
		if child is Sprite3D and child != _output_sprite:
			# 1. Enforce purely flat 2D depth so they don't clip
			child.position.z = 0.0
			
			# 2. Procedural Animation (3D)
			if enable_animation and child is RigPart3D:
				if Engine.is_editor_hint():
					child.reset_animation()
				else:
					child.apply_animation(_time)
					
			# 3. Map to 2D
			if not Engine.is_editor_hint() and _sprite_map.has(child):
				var s2d: Sprite2D = _sprite_map[child]
				var local_to_rig = Transform3D.IDENTITY
				var curr_node = child
				while curr_node and curr_node != self:
					local_to_rig = curr_node.transform * local_to_rig
					curr_node = curr_node.get_parent()
				
				var ps = child.pixel_size
				if ps <= 0: ps = 0.01
				
				# 3D to 2D Projection
				var pos2d = Vector2(local_to_rig.origin.x, -local_to_rig.origin.y) / ps
				pos2d += Vector2(_viewport.size) / 2.0
				s2d.position = pos2d
				
				var raw_x = Vector2(local_to_rig.basis.x.x, -local_to_rig.basis.x.y)
				var raw_y = Vector2(local_to_rig.basis.y.x, -local_to_rig.basis.y.y)
				
				var scale_x = raw_x.length()
				var scale_y = 1.0
				
				# Prevent division by zero
				if scale_x > 0.0001:
					# Godot 3D Top is +Y. Godot 2D Top is -Y. 
					# This means we want the 2D Y axis to perfectly oppose raw_y.
					# Using a 2D cross product, we calculate the exact required Y scale to preserve mirroring.
					scale_y = (raw_y.x * raw_x.y - raw_y.y * raw_x.x) / scale_x
				else:
					scale_y = raw_y.length()
				
				s2d.rotation = raw_x.angle()
				
				var final_flip_v = child.flip_v
				if scale_y < 0:
					scale_y = abs(scale_y)
					final_flip_v = !final_flip_v
					
				s2d.scale = Vector2(scale_x, scale_y)
				
				# Flips are applied natively in 2D on top of the calculated scale matrix
				s2d.flip_h = child.flip_h
				s2d.flip_v = final_flip_v
				
				if auto_sort:
					s2d.z_index = sort_index
					
			sort_index += 1

	# 4. Billboarding & Flipping
	if face_camera and not Engine.is_editor_hint():
		var cam = get_viewport().get_camera_3d()
		if cam:
			var target_pos = cam.global_position
			var up_vec = global_transform.basis.y.normalized()
			
			if y_billboard_only:
				# Project camera position onto the local XZ plane defined by the UP vector
				var to_cam = target_pos - global_position
				var up_projection = to_cam.project(up_vec)
				target_pos = global_position + (to_cam - up_projection)
			
			# Prevent errors if camera is exactly above/below
			if global_position.distance_squared_to(target_pos) > 0.001:
				look_at(target_pos, up_vec)
				
			# Handle Flipping (determines if camera is to the left or right of our original forward vector)
			var local_cam = to_local(cam.global_position)
			# If flip_horizontal is active, we invert the X scale of the entire rig.
			# This cleanly mirrors all child positions and sprites without messing up their Z-planes!
			var base_scale = scale
			base_scale.x = abs(base_scale.x) * (-1.0 if flip_horizontal else 1.0)
			scale = base_scale

func _get_all_sprites(node: Node, arr: Array) -> Array:
	for child in node.get_children():
		if child is SpriteBase3D:
			arr.append(child)
		arr = _get_all_sprites(child, arr)
	return arr
