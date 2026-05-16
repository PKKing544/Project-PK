extends Node3D
class_name GrassManager

@export var interact_radius: float = 1.5
@export var player_node: Node3D

# Cached list of all grass materials found in the scene
var _grass_materials: Array[ShaderMaterial] = []
var _last_scan_time: float = 0.0
const SCAN_INTERVAL: float = 2.0 # Rescan every 2s to pick up newly baked chunks

func _ready():
	if not player_node:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0]
		else:
			var root = get_tree().current_scene
			if root:
				player_node = root.find_child("Player", true, false)
	_scan_for_grass_materials()

func _scan_for_grass_materials():
	_grass_materials.clear()
	_scan_tree_for_grass(get_tree().current_scene)

func _scan_tree_for_grass(node: Node):
	if node == null:
		return
	if node is MultiMeshInstance3D:
		var mat = node.material_override
		if mat is ShaderMaterial and not _grass_materials.has(mat):
			# Only grab shaders that have the character_positions uniform
			if mat.get_shader_parameter("character_positions") != null:
				_grass_materials.append(mat)
	for child in node.get_children():
		_scan_tree_for_grass(child)

func _process(delta):
	if not player_node or not is_instance_valid(player_node):
		return

	# Periodically rescan for newly baked/spawned grass chunks
	_last_scan_time += delta
	if _last_scan_time >= SCAN_INTERVAL or _grass_materials.is_empty():
		_last_scan_time = 0.0
		_scan_for_grass_materials()

	if _grass_materials.is_empty():
		return

	var pos = player_node.global_position
	var char_data = PackedVector4Array()
	char_data.resize(64)
	char_data.fill(Vector4.ZERO)
	char_data[0] = Vector4(pos.x, pos.y, pos.z, interact_radius)

	for mat in _grass_materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("character_positions", char_data)
