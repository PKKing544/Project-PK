@tool
extends Node
class_name CloudManager

## A greyscale noise texture used to shape the clouds.
## Worley/cellular noise gives the best cloud look.
@export var cloud_texture: Texture2D:
	set(val):
		cloud_texture = val
		_update_materials()

## World-space scale of the clouds. Smaller = larger clouds.
@export var cloud_scale: float = 0.003:
	set(val):
		cloud_scale = val
		_update_materials()

## How fast the clouds move.
@export var cloud_speed: float = 0.006:
	set(val):
		cloud_speed = val
		_update_materials()

## Direction the clouds drift (XZ plane).
@export var cloud_direction: Vector2 = Vector2(1.0, 0.5):
	set(val):
		cloud_direction = val
		_update_materials()

## Noise threshold — raise to reduce cloud cover, lower to increase it.
@export var cloud_threshold: float = 0.5:
	set(val):
		cloud_threshold = val
		_update_materials()

## How soft the cloud edges are.
@export var cloud_feather: float = 0.15:
	set(val):
		cloud_feather = val
		_update_materials()

## How dark the shadows are. 0 = off, 1 = fully black.
@export var cloud_strength: float = 0.35:
	set(val):
		cloud_strength = val
		_update_materials()

func _ready() -> void:
	_update_materials()

func _process(_delta: float) -> void:
	# In the editor, update continuously so inspector changes are visible instantly
	if Engine.is_editor_hint():
		_update_materials()

func _update_materials() -> void:
	# 1. Update the shared wall/building material (res://art/prototype_grid.tres)
	var wall_mat = load("res://art/prototype_grid.tres")
	if wall_mat and wall_mat is ShaderMaterial:
		_apply_to_material(wall_mat)
	
	# 2. Update terrain & grass materials if terrain is present
	var terrain: MarchingSquaresTerrain = _find_terrain()
	if terrain:
		if terrain.terrain_material:
			_apply_to_material(terrain.terrain_material)
		if terrain.grass_mesh and terrain.grass_mesh.material:
			_apply_to_material(terrain.grass_mesh.material)

func _apply_to_material(mat: ShaderMaterial) -> void:
	if not mat:
		return
	# Set shader parameters
	mat.set_shader_parameter("cloud_texture", cloud_texture)
	mat.set_shader_parameter("cloud_scale", cloud_scale)
	mat.set_shader_parameter("cloud_speed", cloud_speed)
	mat.set_shader_parameter("cloud_direction", cloud_direction)
	mat.set_shader_parameter("cloud_threshold", cloud_threshold)
	mat.set_shader_parameter("cloud_feather", cloud_feather)
	mat.set_shader_parameter("cloud_strength", cloud_strength)

func _find_terrain() -> MarchingSquaresTerrain:
	# Check parent/siblings first
	var parent = get_parent()
	if parent:
		if parent is MarchingSquaresTerrain:
			return parent
		for child in parent.get_children():
			if child is MarchingSquaresTerrain:
				return child
				
	# Search active scene tree as fallback
	if is_inside_tree():
		var root = get_tree().current_scene
		if root:
			return _find_terrain_recursive(root)
	return null

func _find_terrain_recursive(node: Node) -> MarchingSquaresTerrain:
	if node is MarchingSquaresTerrain:
		return node
	for child in node.get_children():
		var found = _find_terrain_recursive(child)
		if found:
			return found
	return null
