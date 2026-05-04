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
var current_tier: Tier = Tier.PURPLE

const CHUNK_SIZE = 100.0

# Billboard mapping
const BILLBOARD_MAP = {
	"res://scenes/chunks/tower_chunk.tscn": "res://art/billboards/tower_chunk_billboard.jpg",
	"res://scenes/chunks/courtyard_chunk.tscn": "res://art/billboards/courtyard_chunk_billboard.jpg",
	"res://scenes/chunks/room_chunk.tscn": "res://art/billboards/room_chunk_billboard.jpg",
	"res://scenes/chunks/hall_chunk.tscn": "res://art/billboards/hall_chunk_billboard.jpg"
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

func init_chunk(settings: TerrainSettings, noise_obj: FastNoiseLite, structure_path: String):
	terrain_settings = settings
	noise = noise_obj
	structure_scene_path = structure_path
	
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
			
			var v0 = _get_vertex(x0, z0)
			var v1 = _get_vertex(x1, z0)
			var v2 = _get_vertex(x1, z1)
			var v3 = _get_vertex(x0, z1)
			
			# Triangle 1
			st.add_vertex(v0)
			st.add_vertex(v1)
			st.add_vertex(v2)
			
			# Triangle 2
			st.add_vertex(v0)
			st.add_vertex(v2)
			st.add_vertex(v3)
			
	st.generate_normals()
	terrain_mesh.mesh = st.commit()
	
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

func _load_structure():
	if structure_scene_path == "" or not FileAccess.file_exists(structure_scene_path):
		return
		
	var scene = load(structure_scene_path)
	if scene:
		var inst = scene.instantiate()
		content_3d.add_child(inst)
		
		# Sample height at center for placement
		var center_h = _get_vertex(CHUNK_SIZE/2.0, CHUNK_SIZE/2.0).y
		inst.position.y = center_h

func _update_tier(new_tier: Tier):
	current_tier = new_tier
	
	match current_tier:
		Tier.PINK: # Immediate
			content_3d.show()
			content_2d.hide()
			collision_body.process_mode = PROCESS_MODE_INHERIT
		Tier.YELLOW: # Inner
			content_3d.show()
			content_2d.hide()
			collision_body.process_mode = PROCESS_MODE_INHERIT
		Tier.PURPLE: # Distant
			content_3d.hide()
			content_2d.show()
			collision_body.process_mode = PROCESS_MODE_DISABLED
			
			# Load billboard if not already loaded
			if content_2d.texture == null and BILLBOARD_MAP.has(structure_scene_path):
				content_2d.texture = load(BILLBOARD_MAP[structure_scene_path])

func get_height_at_pos(global_pos: Vector2) -> float:
	return noise.get_noise_2d(global_pos.x, global_pos.y) * terrain_settings.height_scale
