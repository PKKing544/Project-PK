extends AbilityData
class_name BloomAbilityData

@export var bloom_mode: FireModeData

func execute(player: Node3D) -> bool:
	if not player.has_method("apply_kickback"): return false
	
	var hand_manager = player.get_node_or_null("HandManager")
	if not hand_manager: return false
	
	# Trigger the bloom shot through the hand manager
	if hand_manager.try_fire(bloom_mode):
		# Apply kickback manually if the fire mode doesn't
		player.apply_kickback(-player.camera.global_transform.basis.z * 10.0)
		return true
		
	return false
