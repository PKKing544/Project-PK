extends Node3D
class_name OcclusionManager

## How fast meshes fade in/out
@export var fade_speed: float = 8.0
## Approximate player height — the check aims at the player's mid-point
@export var target_height: float = 2.0
## How wide the "tube" between camera and player is for occlusion detection.
## Raise this if walls aren't fading reliably.
@export var occlude_radius: float = 3.0

var _camera: Camera3D
var _player: Node3D
var _geo_nodes: Array[GeometryInstance3D] = []
var _scan_timer: float = 0.0
const SCAN_INTERVAL := 3.0

func _ready() -> void:
	await get_tree().process_frame
	_find_references()
	_scan_for_geometry()

func _find_references() -> void:
	_camera = get_viewport().get_camera_3d()
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _scan_for_geometry() -> void:
	_geo_nodes.clear()
	_scan_node(get_tree().current_scene)

func _scan_node(node: Node) -> void:
	if node == null:
		return
	# Only grab CSGCombiner3D roots — these are what actually render the baked geometry
	# Skip CSGBox3D / CSGCylinder3D etc. since they're just bake inputs
	if node.get_class() == "CSGCombiner3D":
		_geo_nodes.append(node as GeometryInstance3D)
	elif node is MeshInstance3D:
		_geo_nodes.append(node as GeometryInstance3D)
	for child in node.get_children():
		_scan_node(child)

func _process(delta: float) -> void:
	if not _camera or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if not _player or not is_instance_valid(_player):
		_find_references()
	if not _camera or not _player:
		return

	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan_for_geometry()

	var cam_pos := _camera.global_position
	# Aim at the player's center (mid-height), not their feet
	var target_pos := _player.global_position + Vector3(0.0, target_height * 0.5, 0.0)
	var line_vec := target_pos - cam_pos
	var line_len := line_vec.length()
	if line_len < 0.001:
		return
	var line_dir := line_vec / line_len

	for geo in _geo_nodes:
		if not is_instance_valid(geo):
			continue

		var node_pos := geo.global_position
		var to_node := node_pos - cam_pos

		# Project node position onto the camera→player line
		var proj := to_node.dot(line_dir)

		var target_fade: float
		# Is this node actually between the camera and the player?
		if proj > 0.5 and proj < line_len - 0.5:
			# Perpendicular distance from the node to the camera→player line
			var closest := cam_pos + line_dir * proj
			var perp_dist := node_pos.distance_to(closest)
			# Smoothly fade from fully hidden (perp_dist=0) to fully visible (perp_dist=occlude_radius)
			target_fade = smoothstep(0.0, occlude_radius, perp_dist)
		else:
			target_fade = 1.0

		var current = geo.get_instance_shader_parameter("fade_amount")
		var current_val := 1.0 if current == null else float(current)
		if abs(current_val - target_fade) > 0.001:
			geo.set_instance_shader_parameter(
				"fade_amount",
				move_toward(current_val, target_fade, fade_speed * delta)
			)
