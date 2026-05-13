@tool
extends Node3D
class_name TerrainPainter

@export var terrain_settings: TerrainSettings
@export var chunk_size: float = 100.0
@export var resolution: float = 5.0

## Flat height array, row-major: index = gx + gz * grid_w
@export var height_data: PackedFloat32Array = PackedFloat32Array()
@export var grid_w: int = 0
@export var grid_h: int = 0

## Inspector buttons — click these to run the action
@export_tool_button("Bake from Noise", "Reload")       var _btn_bake  = bake_from_noise
@export_tool_button("Rebuild Mesh",    "MeshInstance3D") var _btn_mesh  = rebuild_mesh
@export_tool_button("Build Collision", "CollisionShape3D") var _btn_col = build_collision

var _mesh_instance: MeshInstance3D
var _static_body: StaticBody3D
var _col_shape: CollisionShape3D
var _material: Material

func _ready():
	_setup_nodes()
	if height_data.size() > 0:
		rebuild_mesh()

func _setup_nodes():
	_mesh_instance = _get_or_create("_TerrainMesh", MeshInstance3D)
	_static_body  = _get_or_create("_TerrainBody",  StaticBody3D)
	var mat_path = "res://art/prototype_grid.tres"
	if ResourceLoader.exists(mat_path):
		_material = load(mat_path)

func _get_or_create(child_name: String, type: Variant) -> Node:
	var n = find_child(child_name, false)
	if n:
		return n
	n = type.new()
	n.name = child_name
	add_child(n)
	if Engine.is_editor_hint():
		n.owner = get_tree().edited_scene_root
	return n

# ────────────────────────────────────────────────────────────
# Public API
# ────────────────────────────────────────────────────────────

func bake_from_noise() -> void:
	if not terrain_settings:
		push_error("TerrainPainter: assign TerrainSettings first!")
		return

	var noise := FastNoiseLite.new()
	noise.seed      = terrain_settings.generation_seed
	noise.frequency = terrain_settings.frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

	var steps := int(chunk_size / resolution)
	grid_w = steps + 1
	grid_h = steps + 1
	height_data.resize(grid_w * grid_h)

	for gz in range(grid_h):
		for gx in range(grid_w):
			var wx := global_position.x + gx * resolution - chunk_size * 0.5
			var wz := global_position.z + gz * resolution - chunk_size * 0.5
			var h  := noise.get_noise_2d(wx, wz) * terrain_settings.height_scale
			h = snapped(h, terrain_settings.quantization)
			height_data[gx + gz * grid_w] = h

	rebuild_mesh()
	print("TerrainPainter: baked %d x %d vertices" % [grid_w, grid_h])


func paint_at(world_pos: Vector3, radius: float, strength: float, mode: int) -> void:
	if height_data.size() == 0:
		return

	var lx := world_pos.x - global_position.x + chunk_size * 0.5
	var lz := world_pos.z - global_position.z + chunk_size * 0.5

	var x0 := clampi(int((lx - radius) / resolution),     0, grid_w - 1)
	var x1 := clampi(int((lx + radius) / resolution) + 1, 0, grid_w - 1)
	var z0 := clampi(int((lz - radius) / resolution),     0, grid_h - 1)
	var z1 := clampi(int((lz + radius) / resolution) + 1, 0, grid_h - 1)

	# Pre-compute flatten target
	var flat_h := 0.0
	if mode == 2:
		var cnt := 0
		for gz in range(z0, z1 + 1):
			for gx in range(x0, x1 + 1):
				var dist := Vector2(gx * resolution - lx, gz * resolution - lz).length()
				if dist <= radius:
					flat_h += height_data[gx + gz * grid_w]
					cnt += 1
		if cnt > 0:
			flat_h /= cnt

	for gz in range(z0, z1 + 1):
		for gx in range(x0, x1 + 1):
			var dist := Vector2(gx * resolution - lx, gz * resolution - lz).length()
			if dist > radius:
				continue
			var falloff := pow(1.0 - dist / radius, 2.0)
			var idx     := gx + gz * grid_w
			match mode:
				0: height_data[idx] += strength * falloff
				1: height_data[idx] -= strength * falloff
				2: height_data[idx]  = lerpf(height_data[idx], flat_h, falloff * 0.3)
				3: height_data[idx]  = lerpf(height_data[idx], _avg_neighbors(gx, gz), falloff * 0.25)

	rebuild_mesh()


func rebuild_mesh() -> void:
	if not _mesh_instance:
		_setup_nodes()
	if height_data.size() == 0:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for gz in range(grid_h - 1):
		for gx in range(grid_w - 1):
			var v0 := _vtx(gx,     gz)
			var v1 := _vtx(gx + 1, gz)
			var v2 := _vtx(gx + 1, gz + 1)
			var v3 := _vtx(gx,     gz + 1)
			st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
			st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v3)

	st.generate_normals()
	_mesh_instance.mesh = st.commit()
	if _material:
		_mesh_instance.material_override = _material


func build_collision() -> void:
	if not _mesh_instance or not _mesh_instance.mesh:
		push_error("TerrainPainter: rebuild mesh first!")
		return

	for c in _static_body.get_children():
		c.queue_free()

	_col_shape = CollisionShape3D.new()
	_col_shape.shape = _mesh_instance.mesh.create_trimesh_shape()
	_static_body.add_child(_col_shape)
	if Engine.is_editor_hint():
		_col_shape.owner = get_tree().edited_scene_root
	print("TerrainPainter: collision built.")


func get_height_at_world(wx: float, wz: float) -> float:
	if height_data.size() == 0:
		return 0.0
	var gx := clampi(int((wx - global_position.x + chunk_size * 0.5) / resolution), 0, grid_w - 1)
	var gz := clampi(int((wz - global_position.z + chunk_size * 0.5) / resolution), 0, grid_h - 1)
	return height_data[gx + gz * grid_w]

# ────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────

func _vtx(gx: int, gz: int) -> Vector3:
	var h := height_data[gx + gz * grid_w] if (gx + gz * grid_w) < height_data.size() else 0.0
	return Vector3(gx * resolution - chunk_size * 0.5, h, gz * resolution - chunk_size * 0.5)

func _avg_neighbors(gx: int, gz: int) -> float:
	var total := 0.0
	var n     := 0
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var nx := gx + dx; var nz := gz + dz
			if nx >= 0 and nx < grid_w and nz >= 0 and nz < grid_h:
				total += height_data[nx + nz * grid_w]
				n += 1
	return total / n if n > 0 else 0.0
