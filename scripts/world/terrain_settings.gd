extends Resource
class_name TerrainSettings

@export var generation_seed: int = 1337
@export var frequency: float = 0.01
@export var height_scale: float = 20.0
@export var quantization: float = 0.5 # Snapping height to grid
@export var resolution: float = 5.0 # Distance between vertices
