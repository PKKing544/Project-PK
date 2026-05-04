extends Resource
class_name AbilityData

@export var ability_name: String = "Generic Ability"
@export var cooldown_sec: float = 2.0
@export var ink_cost: float = 10.0

func execute(_player: Node3D) -> bool:
	# To be overridden by specific abilities
	return true
