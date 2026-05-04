extends Node3D
class_name WorldManager

@export var player: Node3D
@export var terrain_settings: TerrainSettings
@export var view_bias: float = 60.0 # Distance for PINK/YELLOW tier transition

var noise: FastNoiseLite
var chunks = {} # Vector2i -> Chunk
const GRID_SIZE = 9
const CHUNK_SIZE = 100.0

# Chunk archetype pool
const CHUNK_POOL = [
	"res://scenes/chunks/room_chunk.tscn",
	"res://scenes/chunks/tower_chunk.tscn",
	"res://scenes/chunks/courtyard_chunk.tscn",
	"res://scenes/chunks/hall_chunk.tscn"
]

func _ready():
	if not terrain_settings:
		print("Error: No TerrainSettings assigned to WorldManager.")
		return
		
	_init_noise()
	_generate_grid()

func _init_noise():
	noise = FastNoiseLite.new()
	noise.seed = terrain_settings.generation_seed
	noise.frequency = terrain_settings.frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

func _generate_grid():
	var offset = int(GRID_SIZE / 2.0)
	
	for z in range(-offset, offset + 1):
		for x in range(-offset, offset + 1):
			_create_chunk(x, z)

func _create_chunk(gx: int, gz: int):
	var chunk = Chunk.new()
	chunk.name = "Chunk_%d_%d" % [gx, gz]
	chunk.position = Vector3(gx * CHUNK_SIZE, 0, gz * CHUNK_SIZE)
	add_child(chunk)
	
	# Pick a random structure based on grid position (deterministic-ish)
	var pool_idx = abs(gx + gz * 13) % CHUNK_POOL.size()
	var structure = CHUNK_POOL[pool_idx]
	
	chunk.init_chunk(terrain_settings, noise, structure)
	chunks[Vector2i(gx, gz)] = chunk

func _process(_delta):
	if not player: return
	
	var player_pos = player.global_position
	
	for coord in chunks:
		var chunk = chunks[coord]
		var dist = player_pos.distance_to(chunk.global_position)
		
		var new_tier = Chunk.Tier.PURPLE
		if dist < view_bias:
			new_tier = Chunk.Tier.PINK
		elif dist < view_bias * 2.5:
			new_tier = Chunk.Tier.YELLOW
			
		if chunk.current_tier != new_tier:
			chunk._update_tier(new_tier)
