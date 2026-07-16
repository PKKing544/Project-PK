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
## When true: picks a completely random seed for the path generation every time you play the game!
@export var randomize_path_seed_on_play: bool = true

@export_group("Structure Generation")
## Percentage chance (0.0 to 1.0) that a non-path chunk will randomly spawn a structure.
## Guaranteed spawns (2 of each) will still place regardless of this chance.
@export var structure_spawn_chance: float = 0.5

@export_group("Path Generation")
## Optional custom noise for paths. If left empty, one will be generated automatically.
## You can assign a FastNoiseLite here to preview what the noise looks like!
@export var custom_path_noise: FastNoiseLite
## How curvy/winding the organic path noise is (only used if custom_path_noise is empty).
@export var path_frequency: float = 0.005
## How wide the organic paths are. Increase this if paths are too thin or hard to see.
@export var path_threshold: float = 0.05
## The dirt color for the organic paths.
@export var path_color: Color = Color("8B4513")
## How soft/dithered the edges of the path are on the terrain (0.0 for hard edge).
@export var path_dither_width: float = 0.015

var noise: FastNoiseLite
var path_noise: FastNoiseLite
var chunks = {} # Vector2i -> Chunk
const GRID_SIZE = 9
const CHUNK_SIZE = 100.0

# Per-structure footprint (X, Z) for the fill platform
const STRUCTURE_FOOTPRINTS: Dictionary = {
	"res://scenes/chunks/room_chunk.tscn":      Vector2(56.0, 56.0),
	"res://scenes/chunks/tower_chunk.tscn":     Vector2(20.0, 20.0),
	"res://scenes/chunks/courtyard_chunk.tscn": Vector2(70.0, 70.0),
	"res://scenes/chunks/hall_chunk.tscn":      Vector2(70.0, 45.0),
	"res://scenes/chunks/large_chunk_1.tscn":   Vector2(50.0, 50.0),
	"res://scenes/chunks/large_chunk_2.tscn":   Vector2(50.0, 50.0),
	"res://scenes/chunks/large_chunk_3.tscn":   Vector2(60.0, 60.0),
	"res://scenes/chunks/small_chunk_1.tscn":   Vector2(30.0, 30.0),
	"res://scenes/chunks/small_chunk_2.tscn":   Vector2(25.0, 40.0),
	"res://scenes/chunks/small_chunk_3.tscn":   Vector2(25.0, 45.0),
	"res://scenes/chunks/small_chunk_4.tscn":   Vector2(35.0, 30.0),
	"res://scenes/chunks/small_chunk_5.tscn":   Vector2(30.0, 30.0),
}

# The hole cut into the procedural terrain mesh so structures can be hollow beneath.
# Slightly smaller than the outer dimensions of the buildings to hide jagged cuts.
const HOLE_FOOTPRINTS: Dictionary = {
	"res://scenes/chunks/room_chunk.tscn":      Vector2(10.0, 10.0),
	"res://scenes/chunks/tower_chunk.tscn":     Vector2(18.0, 18.0),
	"res://scenes/chunks/courtyard_chunk.tscn": Vector2(18.0, 18.0),
	"res://scenes/chunks/hall_chunk.tscn":      Vector2(8.0, 38.0),
	"res://scenes/chunks/large_chunk_1.tscn":   Vector2(26.0, 26.0),
	"res://scenes/chunks/large_chunk_2.tscn":   Vector2(36.0, 36.0),
	"res://scenes/chunks/large_chunk_3.tscn":   Vector2(36.0, 36.0),
	"res://scenes/chunks/small_chunk_1.tscn":   Vector2(12.0, 12.0),
	"res://scenes/chunks/small_chunk_2.tscn":   Vector2(6.0, 22.0),
	"res://scenes/chunks/small_chunk_3.tscn":   Vector2(8.0, 18.0),
	"res://scenes/chunks/small_chunk_4.tscn":   Vector2(14.0, 10.0),
	"res://scenes/chunks/small_chunk_5.tscn":   Vector2(12.0, 12.0),
}

# Slope sampling grid per chunk (GRID x GRID = candidates)
const CANDIDATE_GRID   := 4
const PLACEMENT_MARGIN := 18.0  # Stay this many metres from chunk edge

# Chunk archetype pool
const CHUNK_POOL = [
	"res://scenes/chunks/room_chunk.tscn",
	"res://scenes/chunks/tower_chunk.tscn",
	"res://scenes/chunks/courtyard_chunk.tscn",
	"res://scenes/chunks/hall_chunk.tscn",
	"res://scenes/chunks/large_chunk_1.tscn",
	"res://scenes/chunks/large_chunk_2.tscn",
	"res://scenes/chunks/large_chunk_3.tscn",
	"res://scenes/chunks/small_chunk_1.tscn",
	"res://scenes/chunks/small_chunk_2.tscn",
	"res://scenes/chunks/small_chunk_3.tscn",
	"res://scenes/chunks/small_chunk_4.tscn",
	"res://scenes/chunks/small_chunk_5.tscn",
]

func _ready():
	add_to_group("world_manager")
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
	
	if custom_path_noise:
		path_noise = custom_path_noise
	else:
		path_noise = FastNoiseLite.new()
		if randomize_path_seed_on_play:
			randomize()
			path_noise.seed = randi()
		else:
			path_noise.seed = terrain_settings.generation_seed + 123
		path_noise.frequency = path_frequency
		path_noise.noise_type = FastNoiseLite.TYPE_PERLIN

func _generate_grid():
	var offset = int(GRID_SIZE / 2.0)
	var coords = []
	for z in range(-offset, offset + 1):
		for x in range(-offset, offset + 1):
			coords.append(Vector2i(x, z))
			
	var rng = RandomNumberGenerator.new()
	rng.seed = terrain_settings.generation_seed
	if baked_terrain_mode:
		rng.randomize()
		
	# Fisher-Yates shuffle
	for i in range(coords.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = coords[i]
		coords[i] = coords[j]
		coords[j] = temp
		
	var structure_assignments = {}
	var center_val = path_noise.get_noise_2d(0, 0)
	var unblocked_coords = []
	for c in coords:
		unblocked_coords.append(c)
			
	# Guaranteed 2 of each structure
	for structure in CHUNK_POOL:
		for i in range(2):
			if unblocked_coords.size() > 0:
				var c = unblocked_coords.pop_back()
				structure_assignments[c] = structure
				
	# Fill remaining with random chance
	while unblocked_coords.size() > 0:
		var c = unblocked_coords.pop_back()
		if rng.randf() < structure_spawn_chance:
			var random_structure = CHUNK_POOL[rng.randi() % CHUNK_POOL.size()]
			structure_assignments[c] = random_structure
		else:
			structure_assignments[c] = ""
			
	# Instantiate
	for c in structure_assignments.keys():
		_create_chunk(c.x, c.y, structure_assignments[c])

func _create_chunk(gx: int, gz: int, structure: String):
	var chunk = Chunk.new()
	chunk.name = "Chunk_%d_%d" % [gx, gz]
	chunk.position = Vector3(gx * CHUNK_SIZE, 0, gz * CHUNK_SIZE)
	chunk.skip_terrain = baked_terrain_mode
	add_child(chunk)
	
	var local_offset := _find_best_local_offset(gx, gz)
	
	# If the offset's y-component is INF, it means we couldn't find ANY spot off the path!
	if local_offset.y == INF:
		structure = "" # Cancel the structure placement
		local_offset.y = 0.0
		
	var footprint: Vector2 = STRUCTURE_FOOTPRINTS.get(structure, Vector2(50.0, 50.0))
	var hole: Vector2 = HOLE_FOOTPRINTS.get(structure, Vector2(0.0, 0.0))
	
	chunk.init_chunk(terrain_settings, noise, path_noise, path_threshold, structure, local_offset, footprint, hole)
	chunks[Vector2i(gx, gz)] = chunk


# Returns the local-space XZ offset (from chunk centre) with the lowest slope.
func _find_best_local_offset(gx: int, gz: int) -> Vector3:
	var best_offset := Vector3(0, INF, 0) # Use y=INF to indicate failure
	var best_slope  := INF
	var half        := CHUNK_SIZE * 0.5
	var center_val = path_noise.get_noise_2d(0, 0)

	for i in range(CANDIDATE_GRID):
		for j in range(CANDIDATE_GRID):
			var t_x: float = float(i) / float(max(CANDIDATE_GRID - 1, 1))
			var t_z: float = float(j) / float(max(CANDIDATE_GRID - 1, 1))
			var lx  := lerpf(-half + PLACEMENT_MARGIN, half - PLACEMENT_MARGIN, t_x)
			var lz  := lerpf(-half + PLACEMENT_MARGIN, half - PLACEMENT_MARGIN, t_z)
			var wx  := gx * CHUNK_SIZE + lx
			var wz  := gz * CHUNK_SIZE + lz
			
			# Check if this candidate spot is on or too close to the path
			var path_val = path_noise.get_noise_2d(wx, wz) - center_val
			if abs(path_val) < path_threshold + 0.05:
				continue
			
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
