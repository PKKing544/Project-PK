@tool
extends Sprite3D
class_name RigPart3D

@export_group("Procedural Animation")
@export var sway_amount: float = 0.0
@export var sway_speed: float = 1.0
@export var bob_amount: float = 0.0
@export var bob_speed: float = 1.0
@export var phase_offset: float = 0.0

var base_position: Vector3 = Vector3.ZERO
var base_rotation_degrees: Vector3 = Vector3.ZERO
var _is_ready: bool = false
func _ready():
	# Store the original positions set in the editor
	base_position = position
	base_rotation_degrees = rotation_degrees
	_is_ready = true

func _notification(what):
	# If the user moves the node in the editor, update the base position
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and _is_ready:
		if not _is_animating():
			base_position = position
			base_rotation_degrees = rotation_degrees

func _process(delta):
	pass

func _is_animating() -> bool:
	return Engine.has_meta("rig_animating") and Engine.get_meta("rig_animating")

func apply_animation(time: float):
	if not _is_ready: return
	
	# Mark as animating so we don't overwrite base_position via notifications
	Engine.set_meta("rig_animating", true)
	
	var current_sway = sin(time * sway_speed + phase_offset) * sway_amount
	var current_bob = sin(time * bob_speed + phase_offset) * bob_amount
	
	# Apply offsets to base values
	rotation_degrees.z = base_rotation_degrees.z + current_sway
	position.y = base_position.y + current_bob
	
	Engine.set_meta("rig_animating", false)

func reset_animation():
	if not _is_ready: return
	Engine.set_meta("rig_animating", true)
	position = base_position
	rotation_degrees = base_rotation_degrees
	Engine.set_meta("rig_animating", false)
