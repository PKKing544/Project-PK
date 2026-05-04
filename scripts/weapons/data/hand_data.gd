extends Resource
class_name HandData

@export var hand_name: String = "Hand"
@export var hand_texture: Texture2D
@export var max_ink: float = 100.0
@export var passive_ink_regen_per_sec: float = 10.0

@export var primary_mode: FireModeData
@export var secondary_mode: FireModeData
