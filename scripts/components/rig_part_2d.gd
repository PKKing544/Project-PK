@tool
extends Sprite2D
class_name RigPart2D

@export_group("Procedural Animation")
@export var sway_amount: float = 0.0
@export var sway_speed: float = 1.0
@export var bob_amount: float = 0.0
@export var bob_speed: float = 1.0
@export var phase_offset: float = 0.0

var base_position: Vector2 = Vector2.ZERO
var base_rotation_degrees: float = 0.0
var _is_ready: bool = false

func _ready():
	base_position = position
	base_rotation_degrees = rotation_degrees
	_is_ready = true

func _notification(what):
	if Engine.is_editor_hint():
		if what == NOTIFICATION_TRANSFORM_CHANGED and _is_ready:
			base_position = position
			base_rotation_degrees = rotation_degrees

func _is_animating() -> bool:
	return Engine.has_meta("rig_animating") and Engine.get_meta("rig_animating")

func apply_animation(time: float):
	if _is_animating():
		rotation_degrees = base_rotation_degrees + sin(time * sway_speed + phase_offset) * sway_amount
		position.y = base_position.y + sin(time * bob_speed + phase_offset * 2.0) * bob_amount
	else:
		rotation_degrees = base_rotation_degrees
		position.y = base_position.y

func reset_animation():
	rotation_degrees = base_rotation_degrees
	position = base_position
