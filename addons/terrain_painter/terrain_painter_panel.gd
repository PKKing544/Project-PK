@tool
extends Control

signal bake_pressed
signal build_collision_pressed
signal brush_radius_changed(value: float)
signal brush_strength_changed(value: float)
signal brush_mode_changed(value: int)

var _status_label: Label
var _mode_buttons: Array[Button] = []
var _shared_group: ButtonGroup

func _init():
	custom_minimum_size = Vector2(200, 0)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# ── Header ──────────────────────────────────────
	var title := Label.new()
	title.text = "⛰  Terrain Painter"
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.text = "Select a TerrainPainter node"
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_label)
	vbox.add_child(HSeparator.new())

	# ── Bake button ─────────────────────────────────
	var bake_btn := Button.new()
	bake_btn.text = "🎲  Bake from Noise"
	bake_btn.tooltip_text = "Sample noise using TerrainSettings and fill height_data"
	bake_btn.connect("pressed", func(): emit_signal("bake_pressed"))
	vbox.add_child(bake_btn)
	vbox.add_child(HSeparator.new())

	# ── Brush mode ───────────────────────────────────
	var ml := Label.new(); ml.text = "Brush Mode"
	vbox.add_child(ml)

	_shared_group = ButtonGroup.new()
	var grid := GridContainer.new()
	grid.columns = 2
	vbox.add_child(grid)

	var modes := ["⬆  Raise", "⬇  Lower", "⬜  Flatten", "〰  Smooth"]
	for i in modes.size():
		var b := Button.new()
		b.text = modes[i]
		b.toggle_mode = true
		b.button_group = _shared_group
		if i == 0:
			b.button_pressed = true
		var idx := i
		b.connect("pressed", func(): emit_signal("brush_mode_changed", idx))
		grid.add_child(b)
		_mode_buttons.append(b)

	vbox.add_child(HSeparator.new())

	# ── Radius slider ────────────────────────────────
	var rl := Label.new(); rl.name = "RadiusLabel"; rl.text = "Brush Radius: 10.0"
	vbox.add_child(rl)
	var rs := HSlider.new()
	rs.min_value = 1.0; rs.max_value = 60.0; rs.value = 10.0; rs.step = 0.5
	rs.connect("value_changed", func(v: float):
		rl.text = "Brush Radius: %.1f" % v
		emit_signal("brush_radius_changed", v))
	vbox.add_child(rs)

	# ── Strength slider ──────────────────────────────
	var sl := Label.new(); sl.name = "StrengthLabel"; sl.text = "Brush Strength: 2.0"
	vbox.add_child(sl)
	var ss := HSlider.new()
	ss.min_value = 0.1; ss.max_value = 25.0; ss.value = 2.0; ss.step = 0.1
	ss.connect("value_changed", func(v: float):
		sl.text = "Brush Strength: %.1f" % v
		emit_signal("brush_strength_changed", v))
	vbox.add_child(ss)

	vbox.add_child(HSeparator.new())

	# ── Collision button ─────────────────────────────
	var col_btn := Button.new()
	col_btn.text = "🔧  Build Collision"
	col_btn.tooltip_text = "Rebuild trimesh collision after painting"
	col_btn.connect("pressed", func(): emit_signal("build_collision_pressed"))
	vbox.add_child(col_btn)

	# ── Tips ─────────────────────────────────────────
	vbox.add_child(HSeparator.new())
	var tips := Label.new()
	tips.text = "Hold LMB to paint\nShift  →  Lower\nCtrl   →  Smooth"
	tips.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	vbox.add_child(tips)


func set_status(terrain_name: String) -> void:
	if terrain_name.is_empty():
		_status_label.text = "Select a TerrainPainter node"
		_status_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		_status_label.text = "Editing: " + terrain_name
		_status_label.add_theme_color_override("font_color", Color.GREEN)
