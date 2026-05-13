## Bake Level 01 Terrain
## ──────────────────────────────────────────────────────────────
## Run this ONCE via: Script Editor → File → Run  (or Ctrl+Shift+X)
## It generates res://scenes/world/level_01_terrain.mesh from the
## same noise parameters used in grid_test.tscn.
## After running, the mesh is saved and level_01.tscn uses it.
## ──────────────────────────────────────────────────────────────
@tool
extends EditorScript

# ── Match these to grid_test.tscn's TerrainSettings sub_resource ──
const SEED         : int   = 1337
const FREQUENCY    : float = 0.002
const HEIGHT_SCALE : float = 60.0
const QUANTIZATION : float = 0.5
const RESOLUTION   : float = 5.0    # metres between vertices

# ── Area to bake  (9 chunks × 100 m = 900 m total) ────────────────
const WORLD_SIZE   : float = 900.0
const SAVE_PATH    : String = "res://scenes/world/level_01_terrain.mesh"

func _run() -> void:
	print("=== Baking Level 01 Terrain ===")

	# Build noise identical to what WorldManager / Chunk uses
	var noise := FastNoiseLite.new()
	noise.seed       = SEED
	noise.frequency  = FREQUENCY
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

	var st    := SurfaceTool.new()
	var steps := int(WORLD_SIZE / RESOLUTION)
	var half  := WORLD_SIZE * 0.5

	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in range(steps):
		for x in range(steps):
			# World-space corners — matches chunk.gd's _get_vertex() sampling
			var x0 := x       * RESOLUTION - half
			var z0 := z       * RESOLUTION - half
			var x1 := (x + 1) * RESOLUTION - half
			var z1 := (z + 1) * RESOLUTION - half

			var v0 := Vector3(x0, _h(noise, x0, z0), z0)
			var v1 := Vector3(x1, _h(noise, x1, z0), z0)
			var v2 := Vector3(x1, _h(noise, x1, z1), z1)
			var v3 := Vector3(x0, _h(noise, x0, z1), z1)

			st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
			st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v3)

	st.generate_normals()
	var mesh := st.commit()

	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://scenes/world/"))

	var err := ResourceSaver.save(mesh, SAVE_PATH)
	if err == OK:
		print("✓ Terrain mesh saved to: ", SAVE_PATH)
		print("  Vertices : %d  (%d×%d grid)" % [
			(steps + 1) * (steps + 1), steps + 1, steps + 1])
		print("  Triangles: %d" % [steps * steps * 2])
		print("")
		print("Next: open level_01.tscn — it already references this mesh.")
	else:
		push_error("✗ Failed to save mesh. Error code: %d" % err)


func _h(noise: FastNoiseLite, x: float, z: float) -> float:
	return snapped(noise.get_noise_2d(x, z) * HEIGHT_SCALE, QUANTIZATION)
