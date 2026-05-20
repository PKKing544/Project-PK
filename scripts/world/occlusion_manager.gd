extends Node3D
class_name OcclusionManager

## The shared wall material (prototype_grid.tres)
@export var wall_material: ShaderMaterial

var _player: Node3D
var _camera: Camera3D

func _ready() -> void:
	await get_tree().process_frame
	_camera = get_viewport().get_camera_3d()
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _process(_delta: float) -> void:
	if not wall_material:
		return
	if not _camera or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if not _player or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0]
		return
	wall_material.set_shader_parameter("player_world_pos", _player.global_position)
	wall_material.set_shader_parameter("camera_world_pos", _camera.global_position)
