@tool
extends EditorPlugin

const Panel = preload("res://addons/terrain_painter/terrain_painter_panel.gd")

var _panel: Panel
var _current: TerrainPainter = null
var _is_painting: bool = false

var brush_radius:   float = 10.0
var brush_strength: float = 2.0
var brush_mode:     int   = 0   # 0 raise  1 lower  2 flatten  3 smooth

var _preview: MeshInstance3D = null


func _enter_tree() -> void:
	_panel = Panel.new()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _panel)
	_panel.connect("bake_pressed",             _on_bake)
	_panel.connect("build_collision_pressed",  _on_build_collision)
	_panel.connect("brush_radius_changed",     func(v): brush_radius   = v; _resize_preview())
	_panel.connect("brush_strength_changed",   func(v): brush_strength = v)
	_panel.connect("brush_mode_changed",       func(v): brush_mode     = v)


func _exit_tree() -> void:
	_destroy_preview()
	if _panel:
		remove_control_from_docks(_panel)
		_panel.queue_free()


# ── Selection handling ───────────────────────────────────────

func _handles(obj: Object) -> bool:
	return obj is TerrainPainter

func _edit(obj: Object) -> void:
	_current = obj as TerrainPainter
	_panel.set_status(_current.name if _current else "")

func _make_visible(visible: bool) -> void:
	if _panel:
		_panel.visible = visible
	if not visible:
		_destroy_preview()


# ── 3D viewport input ────────────────────────────────────────

func _forward_3d_gui_input(cam: Camera3D, event: InputEvent) -> int:
	if not _current:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_painting = event.pressed
		if event.pressed:
			_paint(cam, event.position)
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event is InputEventMouseMotion:
		_move_preview(cam, event.position)
		if _is_painting:
			_paint(cam, event.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS


# ── Core actions ─────────────────────────────────────────────

func _paint(cam: Camera3D, mpos: Vector2) -> void:
	var hit := _raycast(cam, mpos)
	if hit == Vector3.INF:
		return

	var mode := brush_mode
	if Input.is_key_pressed(KEY_SHIFT) and mode == 0:
		mode = 1
	elif Input.is_key_pressed(KEY_CTRL):
		mode = 3

	_current.paint_at(hit, brush_radius, brush_strength, mode)


func _raycast(cam: Camera3D, mpos: Vector2) -> Vector3:
	var from := cam.project_ray_origin(mpos)
	var dir  := cam.project_ray_normal(mpos)
	if abs(dir.y) < 0.001:
		return Vector3.INF
	# Intersect with a plane at the terrain's approximate center height
	var sample_h := 0.0
	if _current and _current.height_data.size() > 0:
		sample_h = _current.get_height_at_world(
			_current.global_position.x,
			_current.global_position.z)
	var t := (sample_h - from.y) / dir.y
	if t < 0.0:
		return Vector3.INF
	return from + dir * t


# ── Brush preview (torus ring) ───────────────────────────────

func _move_preview(cam: Camera3D, mpos: Vector2) -> void:
	var hit := _raycast(cam, mpos)
	if hit == Vector3.INF:
		_destroy_preview()
		return
	_ensure_preview()
	_preview.global_position = hit


func _ensure_preview() -> void:
	if _preview and is_instance_valid(_preview):
		return
	_preview = MeshInstance3D.new()
	var torus         := TorusMesh.new()
	torus.inner_radius = 0.01
	torus.outer_radius = 1.0
	_preview.mesh      = torus

	var mat                  := StandardMaterial3D.new()
	mat.albedo_color          = Color(0.2, 1.0, 0.5, 0.85)
	mat.flags_transparent     = true
	mat.shading_mode          = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test         = true
	_preview.material_override = mat

	get_editor_interface().get_edited_scene_root().add_child(_preview)
	_resize_preview()


func _resize_preview() -> void:
	if _preview and is_instance_valid(_preview):
		var s := brush_radius
		_preview.scale = Vector3(s, s * 0.05, s)


func _destroy_preview() -> void:
	if _preview and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null


# ── Button callbacks ─────────────────────────────────────────

func _on_bake() -> void:
	if _current:
		_current.bake_from_noise()

func _on_build_collision() -> void:
	if _current:
		_current.build_collision()
