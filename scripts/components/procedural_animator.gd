class_name ProceduralAnimator extends Node

@export var enabled: bool = true
@export var target_nodes: Array[Node3D] = []

@export var sway_speed: float = 2.0
@export var sway_amount: float = 0.1
@export var time_offset: float = 0.0

var _time: float = 0.0

func _process(delta: float) -> void:
	if not enabled: return
	
	_time += delta * sway_speed
	var offset = sin(_time + time_offset) * sway_amount
	
	for node in target_nodes:
		if is_instance_valid(node):
			# Base sway around Z axis (2D rotation in SegmentedSpriteRig)
			node.rotation.z = offset
