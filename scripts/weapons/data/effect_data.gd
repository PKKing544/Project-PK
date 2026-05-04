extends Resource
class_name EffectData

# Base method to override for custom effects applied on hit
func apply_effect(_target: Node3D, _hit_point: Vector3, _normal: Vector3, _hit_direction: Vector3, _charge_ratio: float = 1.0, _damage: float = 0.0):
	pass
