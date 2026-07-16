extends Node3D
class_name Chunk

enum Tier { PINK = 0, YELLOW = 1, PURPLE = 2 }

var terrain_mesh: MeshInstance3D
var collision_body: StaticBody3D
var content_3d: Node3D
var content_2d: Sprite3D
var structure_scene_path: String = ""

var terrain_settings: TerrainSettings
var noise: FastNoiseLite
var path_noise: FastNoiseLite
var path_threshold: float = 0.05
var path_color: Color = Color("8B4513")
var path_dither_width: float = 0.015
var current_tier: Tier = Tier.PURPLE
var skip_terrain: bool = false  # Set by WorldManager when using baked ground

# Set by WorldManager — local XZ offset from chunk centre for structure placement
var _structure_local_offset: Vector3 = Vector3.ZERO
# Footprint (X, Z) of the fill platform that hides terrain clipping
var _fill_footprint: Vector2 = Vector2(50.0, 50.0)
# Hole footprint to skip terrain generation beneath structure
var _hole_footprint: Vector2 = Vector2.ZERO

const CHUNK_SIZE = 100.0

# Billboard mapping
const BILLBOARD_MAP = {
	"res://scenes/chunks/tower_chunk.tscn": "res://art/billboards/tower_chunk_billboard.jpg",
	"res://scenes/chunks/courtyard_chunk.tscn": "res://art/billboards/courtyard_chunk_billboard.jpg",
	"res://scenes/chunks/room_chunk.tscn": "res://art/billboards/room_chunk_billboard.jpg",
	"res://scenes/chunks/hall_chunk.tscn": "res://art/billboards/hall_chunk_billboard.png",
	"res://scenes/chunks/large_chunk_1.tscn": "res://art/billboards/large_chunk_1_billboard.jpg",
	"res://scenes/chunks/large_chunk_2.tscn": "res://art/billboards/large_chunk_2_billboard.jpg",
	"res://scenes/chunks/large_chunk_3.tscn": "res://art/billboards/large_chunk_3_billboard.jpg",
	"res://scenes/chunks/small_chunk_1.tscn": "res://art/billboards/small_chunk_1_billboard.jpg",
	"res://scenes/chunks/small_chunk_2.tscn": "res://art/billboards/small_chunk_2_billboard.jpg",
	"res://scenes/chunks/small_chunk_3.tscn": "res://art/billboards/small_chunk_3_billboard.jpg",
	"res://scenes/chunks/small_chunk_4.tscn": "res://art/billboards/small_chunk_4_billboard.jpg",
	"res://scenes/chunks/small_chunk_5.tscn": "res://art/billboards/small_chunk_5_billboard.jpg"
}

func _ready():
	# Setup terrain mesh
	terrain_mesh = MeshInstance3D.new()
	add_child(terrain_mesh)
	
	# Setup collision
	collision_body = StaticBody3D.new()
	add_child(collision_body)
	
	# Setup content nodes
	content_3d = Node3D.new()
	add_child(content_3d)
	
	content_2d = Sprite3D.new()
	content_2d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	content_2d.pixel_size = 0.1 # Large size
	content_2d.position.y = 25.0 # Elevated
	content_2d.hide()
	add_child(content_2d)

func init_chunk(settings: TerrainSettings, noise_obj: FastNoiseLite, path_noise_obj: FastNoiseLite, p_threshold: float, structure_path: String,
				local_offset: Vector3 = Vector3.ZERO, fill_footprint: Vector2 = Vector2(50.0, 50.0), hole_footprint: Vector2 = Vector2.ZERO):
	terrain_settings = settings
	noise = noise_obj
	path_noise = path_noise_obj
	path_threshold = p_threshold
	structure_scene_path = structure_path
	_structure_local_offset = local_offset
	_fill_footprint = fill_footprint
	_hole_footprint = hole_footprint
	
	var parent = get_parent()
	if parent and "path_color" in parent:
		path_color = parent.path_color
		path_dither_width = parent.path_dither_width
	
	if not skip_terrain:
		_generate_terrain()
	_load_structure()
	_update_tier(Tier.PURPLE) # Default to distant

func _generate_terrain():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var res = terrain_settings.resolution
	var steps = int(CHUNK_SIZE / res)
	
	for z in range(steps):
		for x in range(steps):
			var x0 = x * res
			var z0 = z * res
			var x1 = (x + 1) * res
			var z1 = (z + 1) * res
			
			# Check if this quad is inside the hole footprint
			if structure_scene_path != "" and _hole_footprint != Vector2.ZERO:
				var quad_cx = (x0 + x1) / 2.0 - (CHUNK_SIZE / 2.0)
				var quad_cz = (z0 + z1) / 2.0 - (CHUNK_SIZE / 2.0)
				var dx = abs(quad_cx - _structure_local_offset.x)
				var dz = abs(quad_cz - _structure_local_offset.z)
				if dx < (_hole_footprint.x / 2.0) and dz < (_hole_footprint.y / 2.0):
					continue
			
			var v0 = _get_vertex(x0, z0)
			var v1 = _get_vertex(x1, z0)
			var v2 = _get_vertex(x1, z1)
			var v3 = _get_vertex(x0, z1)
			
			var c0 = _get_color(x0, z0)
			var c1 = _get_color(x1, z0)
			var c2 = _get_color(x1, z1)
			var c3 = _get_color(x0, z1)
			
			# Triangle 1
			st.set_color(c0)
			st.add_vertex(v0)
			st.set_color(c1)
			st.add_vertex(v1)
			st.set_color(c2)
			st.add_vertex(v2)
			
			# Triangle 2
			st.set_color(c0)
			st.add_vertex(v0)
			st.set_color(c2)
			st.add_vertex(v2)
			st.set_color(c3)
			st.add_vertex(v3)
			
	st.generate_normals()
	terrain_mesh.mesh = st.commit()
	
	# Apply the green grid shader material to the generated terrain
	var grid_mat = load("res://art/prototype_grid.tres")
	if grid_mat:
		terrain_mesh.material_override = grid_mat
	
	# Create static collision
	terrain_mesh.create_trimesh_collision()
	# The auto-created collision is a child of the mesh instance
	for child in terrain_mesh.get_children():
		if child is StaticBody3D:
			# Move shape to our managed body for easier tier control
			var shape_node = child.get_child(0)
			child.remove_child(shape_node)
			collision_body.add_child(shape_node)
			child.queue_free()

func _get_vertex(lx: float, lz: float) -> Vector3:
	var gx = global_position.x + lx - (CHUNK_SIZE / 2.0)
	var gz = global_position.z + lz - (CHUNK_SIZE / 2.0)
	var h = noise.get_noise_2d(gx, gz) * terrain_settings.height_scale
	
	# Quantize height
	h = snapped(h, terrain_settings.quantization)
	
	return Vector3(lx - (CHUNK_SIZE / 2.0), h, lz - (CHUNK_SIZE / 2.0))

func _get_color(lx: float, lz: float) -> Color:
	if not path_noise:
		return Color.WHITE
		
	var gx = global_position.x + lx - (CHUNK_SIZE / 2.0)
	var gz = global_position.z + lz - (CHUNK_SIZE / 2.0)
	
	var center_val = path_noise.get_noise_2d(0, 0)
	var path_val = path_noise.get_noise_2d(gx, gz) - center_val
	var abs_val = abs(path_val)
	
	var final_color = path_color
	
	if abs_val < path_threshold:
		var dist_from_edge = path_threshold - abs_val
		var blend = 1.0
		if path_dither_width > 0.0:
			blend = clamp(dist_from_edge / path_dither_width, 0.0, 1.0)
			
		final_color.a = blend
		return final_color
		
	final_color.a = 0.0
	return final_color

func _load_structure():
	if structure_scene_path == "" or not FileAccess.file_exists(structure_scene_path):
		return
	var scene = load(structure_scene_path)
	if not scene:
		return

	var inst = scene.instantiate()
	content_3d.add_child(inst)

	var sx := _structure_local_offset.x
	var sz := _structure_local_offset.z

	# Sample a 3x3 grid across the structure footprint to find the minimum
	# terrain height. Placing at the minimum means terrain can never rise
	# above the structure floor — no clipping, no visible base.
	var min_h := INF
	var half_x := _fill_footprint.x * 0.5
	var half_z := _fill_footprint.y * 0.5
	const STEPS := 3
	for fi in range(STEPS + 1):
		for fj in range(STEPS + 1):
			var fx := sx + lerpf(-half_x, half_x, float(fi) / float(STEPS))
			var fz := sz + lerpf(-half_z, half_z, float(fj) / float(STEPS))
			var lx := clampf(fx + CHUNK_SIZE * 0.5, 0.0, CHUNK_SIZE)
			var lz := clampf(fz + CHUNK_SIZE * 0.5, 0.0, CHUNK_SIZE)
			min_h = min(min_h, _get_vertex(lx, lz).y)

	# 0.5 m below minimum so walls emerge naturally from the ground
	inst.position = Vector3(sx, min_h - 0.5, sz)

func _update_tier(new_tier: Tier):
	current_tier = new_tier
	
	match current_tier:
		Tier.PINK, Tier.YELLOW:
			content_3d.show()
			content_3d.process_mode = PROCESS_MODE_INHERIT  # re-enable physics + AI
			content_2d.hide()
			collision_body.process_mode = PROCESS_MODE_INHERIT
			if terrain_mesh:
				terrain_mesh.show()
		Tier.PURPLE:
			content_3d.hide()
			content_3d.process_mode = PROCESS_MODE_DISABLED  # pause CSG physics + enemy AI
			content_2d.show()
			if not skip_terrain:
				collision_body.process_mode = PROCESS_MODE_DISABLED
			if terrain_mesh:
				terrain_mesh.hide()
			
			# Load billboard texture once on first PURPLE transition
			if content_2d.texture == null and BILLBOARD_MAP.has(structure_scene_path):
				content_2d.texture = load(BILLBOARD_MAP[structure_scene_path])
			
			if structure_scene_path == "res://scenes/chunks/hall_chunk.tscn":
				content_2d.pixel_size = 0.4


func get_height_at_pos(global_pos: Vector2) -> float:
	return noise.get_noise_2d(global_pos.x, global_pos.y) * terrain_settings.height_scale
