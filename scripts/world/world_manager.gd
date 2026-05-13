extends Node3D
class_name WorldManager

@export var player: Node3D
@export var terrain_settings: TerrainSettings
## PINK tier  = dist < view_bias          (full 3D, collision on)
## YELLOW tier = dist < view_bias * 2.5   (full 3D, collision on)
## PURPLE tier = beyond that              (2D billboard, collision off)
## Chunk size is 100 m, so default 200 keeps ~5 chunks radius fully 3D.
@export var view_bias: float = 200.0

## When true: chunks skip terrain mesh generation (use baked ground instead).
## Structures are still spawned randomly each run.
@export var baked_terrain_mode: bool = false

var noise: FastNoiseLite
var chunks = {} # Vector2i -> Chunk
const GRID_SIZE = 9
const CHUNK_SIZE = 100.0

# Per-structure footprint (X, Z) for the fill platform
const STRUCTURE_FOOTPRINTS: Dictionary = {
	"res://scenes/chunks/room_chunk.tscn":      Vector2(56.0, 56.0),
	"res://scenes/chunks/tower_chunk.tscn":     Vector2(20.0, 20.0),
	"res://scenes/chunks/courtyard_chunk.tscn": Vector2(70.0, 70.0),
	"res://scenes/chunks/hall_chunk.tscn":      Vector2(70.0, 45.0),
}

# Slope sampling grid per chunk (GRID x GRID = candidates)
const CANDIDATE_GRID   := 4
const PLACEMENT_MARGIN := 18.0  # Stay this many metres from chunk edge

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
	chunk.skip_terrain = baked_terrain_mode
	add_child(chunk)
	
	# Baked mode: fully random structure each run.
	# Procedural mode: deterministic hash (original behaviour).
	var pool_idx: int
	if baked_terrain_mode:
		pool_idx = randi() % CHUNK_POOL.size()
	else:
		pool_idx = abs(gx + gz * 13) % CHUNK_POOL.size()
	var structure: String = CHUNK_POOL[pool_idx]
	
	# Find flattest spot within this chunk for structure placement
	var local_offset := _find_best_local_offset(gx, gz)
	var footprint: Vector2 = STRUCTURE_FOOTPRINTS.get(structure, Vector2(50.0, 50.0))
	
	chunk.init_chunk(terrain_settings, noise, structure, local_offset, footprint)
	chunks[Vector2i(gx, gz)] = chunk


# Returns the local-space XZ offset (from chunk centre) with the lowest slope.
func _find_best_local_offset(gx: int, gz: int) -> Vector3:
	var best_offset := Vector3.ZERO
	var best_slope  := INF
	var half        := CHUNK_SIZE * 0.5

	for i in range(CANDIDATE_GRID):
		for j in range(CANDIDATE_GRID):
			var t_x: float = float(i) / float(max(CANDIDATE_GRID - 1, 1))
			var t_z: float = float(j) / float(max(CANDIDATE_GRID - 1, 1))
			var lx  := lerpf(-half + PLACEMENT_MARGIN, half - PLACEMENT_MARGIN, t_x)
			var lz  := lerpf(-half + PLACEMENT_MARGIN, half - PLACEMENT_MARGIN, t_z)
			var wx  := gx * CHUNK_SIZE + lx
			var wz  := gz * CHUNK_SIZE + lz
			
			var slope := _calc_slope(wx, wz)
			if slope < best_slope:
				best_slope  = slope
				best_offset = Vector3(lx, 0.0, lz)
	
	return best_offset


# Gradient magnitude of the noise height field at world position (wx, wz).
func _calc_slope(wx: float, wz: float) -> float:
	var step := terrain_settings.resolution
	var h0   := noise.get_noise_2d(wx,        wz)        * terrain_settings.height_scale
	var hx   := noise.get_noise_2d(wx + step, wz)        * terrain_settings.height_scale
	var hz   := noise.get_noise_2d(wx,        wz + step) * terrain_settings.height_scale
	return Vector2((hx - h0) / step, (hz - h0) / step).length()

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
