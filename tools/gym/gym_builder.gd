extends Node3D

## Movement Gym Generator
## Procedurally builds a comprehensive test environment for movement mechanics.

# Grid material colors
var grid_dark := Color8(51, 158, 59)
var grid_line := Color8(25, 75, 30)
var grid_accent := Color(0.9, 0.3, 0.1, 1.0)
var wall_color := Color(0.15, 0.15, 0.18, 1.0)
var ramp_color := Color(0.1, 0.2, 0.35, 1.0)
var tower_color := Color(0.2, 0.12, 0.2, 1.0)

func _ready():
	build_gym()

func build_gym():
	# Zone 1: Spawn Platform (center)
	_build_spawn_zone()
	# Zone 2: Jump Metric Steps (east)
	_build_jump_zone()
	# Zone 3: Gap Jumps (far east)
	_build_gap_zone()
	# Zone 4: Slope Testing (west)
	_build_slope_zone()
	# Zone 4b: Room Complex (northwest)
	_build_room_zone()
	# Zone 5: Wall Run Corridors (south)
	_build_wall_run_zone()
	# Zone 6: Vertical Tower (north)
	_build_tower_zone()
	# Zone 7: Tight Spaces (far south)
	_build_tight_zone()
	# Zone 8: Large Arena + Flow Course
	_build_arena_zone()
	# Kill floor
	_build_kill_floor()
	# Safety floor
	_build_safety_floor()
	# Enemies & Lights globally
	_build_enemies_and_lights()

# ============================================================
# ZONE BUILDERS
# ============================================================

func _build_spawn_zone():
	# Large central platform
	_make_block(Vector3(0, -0.5, 0), Vector3(40, 1, 40), grid_dark, "SpawnFloor")
	
	# Direction markers - colored strips
	_make_block(Vector3(18, 0.01, 0), Vector3(4, 0.05, 1), grid_line, "MarkerEast")
	_make_block(Vector3(-18, 0.01, 0), Vector3(4, 0.05, 1), grid_accent, "MarkerWest")
	_make_block(Vector3(0, 0.01, -18), Vector3(1, 0.05, 4), grid_line, "MarkerSouth")
	_make_block(Vector3(0, 0.01, 18), Vector3(1, 0.05, 4), grid_accent, "MarkerNorth")

func _build_jump_zone():
	var base_x = 30.0
	var base_z = 0.0
	
	# Connector bridge from spawn
	_make_block(Vector3(22, -0.5, 0), Vector3(4, 1, 6), grid_dark, "JumpBridge")
	
	# Floor
	_make_block(Vector3(base_x + 10, -0.5, base_z), Vector3(30, 1, 30), grid_dark, "JumpFloor")
	
	# Ascending step platforms - 1m, 2m, 3m, 4m, 5m
	var heights = [1.0, 2.0, 3.0, 4.0, 5.0]
	for i in heights.size():
		var h = heights[i]
		_make_block(
			Vector3(base_x + 4 + i * 5, h / 2.0, base_z),
			Vector3(4, h, 4),
			wall_color.lerp(grid_line, float(i) / heights.size()),
			"JumpStep_" + str(i)
		)
	
	# Double jump test pillar (8m)
	_make_block(Vector3(base_x + 30, 4.0, base_z), Vector3(4, 8, 4), grid_accent, "DoubleJumpPillar")
	
	# Air dash platform (high and far)
	_make_block(Vector3(base_x + 38, 6.0, base_z), Vector3(4, 1, 4), grid_line, "AirDashTarget")

func _build_gap_zone():
	var base_x = 30.0
	var base_z = -25.0
	
	# Starting platform
	_make_block(Vector3(base_x, -0.5, base_z), Vector3(6, 1, 6), grid_dark, "GapStart")
	
	# Gaps: 3m, 5m, 8m, 12m, 16m
	var gaps = [3.0, 5.0, 8.0, 12.0, 16.0]
	var current_x = base_x + 3.0  # edge of start platform
	
	for i in gaps.size():
		current_x += gaps[i]  # cross the gap
		_make_block(
			Vector3(current_x + 2, -0.5, base_z),
			Vector3(4, 1, 6),
			grid_dark.lerp(grid_accent, float(i) / gaps.size()),
			"GapPlat_" + str(i)
		)
		current_x += 2  # half-width of landing platform

func _build_slope_zone():
	var base_x = -35.0
	var base_z = 0.0
	
	# Connector bridge from spawn (wider)
	_make_block(Vector3(-22, -0.5, 0), Vector3(8, 1, 10), grid_dark, "SlopeBridge")
	
	# Large floor area for the expanded slope zone
	_make_block(Vector3(base_x - 20, -0.5, base_z), Vector3(60, 1, 80), grid_dark, "SlopeFloor")
	
	# ---- MAIN RAMP GALLERY (wider and longer ramps at 6 angles) ----
	var angles = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0]
	for i in angles.size():
		var angle = angles[i]
		var z_offset = base_z - 25 + i * 10
		# Each ramp is 8m wide and 20m long (much bigger than before)
		_make_ramp(
			Vector3(base_x - 5, 0, z_offset),
			Vector3(8, 1, 20),
			angle,
			ramp_color.lerp(grid_line, float(i) / angles.size()),
			"Ramp_" + str(int(angle)) + "deg"
		)
		# Landing platform at the top of each ramp
		var rise = sin(deg_to_rad(angle)) * 10.0
		_make_block(
			Vector3(base_x - 5, rise + 0.25, z_offset - 11),
			Vector3(8, 0.5, 3),
			grid_dark.lerp(grid_accent, float(i) / angles.size()),
			"RampLanding_" + str(int(angle))
		)
	
	# ---- LONG DOWNHILL RUN ----
	# A wide, gentle slope running the full length of the zone
	_make_ramp(
		Vector3(base_x - 30, 0, base_z),
		Vector3(12, 1, 40),
		-15.0,
		ramp_color.lerp(Color(0.15, 0.35, 0.2, 1.0), 0.5),
		"DownhillRun"
	)
	# Flat runoff at the bottom
	_make_block(Vector3(base_x - 30, -3.0, base_z + 25), Vector3(12, 1, 10), grid_dark, "DownhillRunoff")
	
	# ---- VALLEY BOWL (concave dip for speed runs) ----
	var bowl_x = base_x - 15
	var bowl_z = base_z + 25
	# Down-slope into the bowl
	_make_ramp(Vector3(bowl_x, 0, bowl_z - 8), Vector3(14, 1, 16), 25.0, ramp_color, "BowlDown")
	# Flat valley floor
	_make_block(Vector3(bowl_x, -3.5, bowl_z), Vector3(14, 1, 6), grid_dark, "BowlFloor")
	# Up-slope out of the bowl
	_make_ramp(Vector3(bowl_x, 0, bowl_z + 8), Vector3(14, 1, 16), -25.0, ramp_color, "BowlUp")
	
	# ---- RIDGE WALKWAYS (narrow elevated slopes) ----
	var ridge_z = base_z - 32
	_make_ramp(Vector3(base_x - 8, 2, ridge_z), Vector3(3, 0.5, 24), 20.0, grid_accent, "Ridge1")
	_make_ramp(Vector3(base_x - 14, 2, ridge_z), Vector3(3, 0.5, 24), -20.0, grid_accent, "Ridge2")
	# Connecting platform between ridges at top
	_make_block(Vector3(base_x - 11, 6.5, ridge_z - 13), Vector3(10, 0.5, 4), grid_line, "RidgeConnect")
	
	# ---- UPGRADED HALF-PIPE (wider and deeper) ----
	var hp_x = base_x - 40
	var hp_z = base_z - 10
	# Flat bottom
	_make_block(Vector3(hp_x, -2.0, hp_z), Vector3(12, 1, 10), grid_dark, "HalfPipeFloor")
	# Up-ramp side A (30 degrees, long)
	_make_ramp(Vector3(hp_x, -1.5, hp_z + 10), Vector3(12, 1, 14), -30.0, ramp_color, "HalfPipeUp")
	# Up-ramp side B (30 degrees, long, opposite)
	_make_ramp(Vector3(hp_x, -1.5, hp_z - 10), Vector3(12, 1, 14), 30.0, ramp_color, "HalfPipeDown")
	# Side walls for the half-pipe
	_make_block(Vector3(hp_x - 6.25, 2, hp_z), Vector3(0.5, 8, 30), wall_color, "HalfPipeWallL")
	_make_block(Vector3(hp_x + 6.25, 2, hp_z), Vector3(0.5, 8, 30), wall_color, "HalfPipeWallR")
	
	# ---- STAIRCASE SLOPES (alternating short ramps like terrain) ----
	var stair_x = base_x - 25
	var stair_z = base_z - 25
	for i in 5:
		var up = (i % 2 == 0)
		var ang = 35.0 if up else -35.0
		_make_ramp(
			Vector3(stair_x, float(i) * 1.5, stair_z + i * 6),
			Vector3(8, 0.6, 6),
			ang,
			ramp_color.lerp(tower_color, float(i) / 5.0),
			"StairSlope_" + str(i)
		)

func _build_room_zone():
	# Room complex zone — located northwest, connected from slope zone
	var base_x = -70.0
	var base_z = -35.0
	var room_color := Color(0.18, 0.16, 0.2, 1.0)
	var frame_color := Color(0.25, 0.22, 0.3, 1.0)
	var window_color := Color(0.08, 0.15, 0.25, 1.0)
	
	# Connector hallway from slope zone
	_make_block(Vector3(-55, -0.5, -20), Vector3(12, 1, 6), grid_dark, "RoomConnector")
	_make_block(Vector3(-62, -0.5, -27), Vector3(6, 1, 12), grid_dark, "RoomConnector2")
	
	# ============ ROOM 1: Standard Room (tall narrow windows, standard door) ============
	var r1x = base_x
	var r1z = base_z
	var r1w = 14.0
	var r1d = 14.0
	var r1h = 8.0
	
	# Floor & Ceiling
	_make_block(Vector3(r1x, -0.5, r1z), Vector3(r1w, 1, r1d), grid_dark, "Room1Floor")
	_make_block(Vector3(r1x, r1h, r1z), Vector3(r1w, 0.5, r1d), room_color, "Room1Ceiling")
	
	# North wall (solid)
	_make_block(Vector3(r1x, r1h/2, r1z + r1d/2), Vector3(r1w, r1h, 0.5), room_color, "Room1WallN")
	# South wall with standard door frame (3m wide, 4m tall opening, centered)
	_make_block(Vector3(r1x - 4.25, r1h/2, r1z - r1d/2), Vector3(5.5, r1h, 0.5), room_color, "Room1WallS_L")
	_make_block(Vector3(r1x + 4.25, r1h/2, r1z - r1d/2), Vector3(5.5, r1h, 0.5), room_color, "Room1WallS_R")
	_make_block(Vector3(r1x, r1h - 1.5, r1z - r1d/2), Vector3(3, r1h - 4, 0.5), room_color, "Room1WallS_Top")
	# Door frame trim
	_make_block(Vector3(r1x - 1.6, 2.0, r1z - r1d/2), Vector3(0.2, 4, 0.7), frame_color, "Room1DoorFrameL")
	_make_block(Vector3(r1x + 1.6, 2.0, r1z - r1d/2), Vector3(0.2, 4, 0.7), frame_color, "Room1DoorFrameR")
	_make_block(Vector3(r1x, 4.1, r1z - r1d/2), Vector3(3.4, 0.2, 0.7), frame_color, "Room1DoorFrameTop")
	# East wall with 2 tall narrow windows (1m wide, 4m tall, spaced apart)
	_make_block(Vector3(r1x + r1w/2, r1h/2, r1z - 3), Vector3(0.5, r1h, 3), room_color, "Room1WallE_1")
	_make_block(Vector3(r1x + r1w/2, r1h/2, r1z + 3), Vector3(0.5, r1h, 3), room_color, "Room1WallE_3")
	_make_block(Vector3(r1x + r1w/2, r1h/2, r1z), Vector3(0.5, 1.5, 2), room_color, "Room1WallE_2bot")
	_make_block(Vector3(r1x + r1w/2, r1h - 0.5, r1z), Vector3(0.5, 1.0, 2), room_color, "Room1WallE_2top")
	# Window frame trim for tall narrow windows
	_make_block(Vector3(r1x + r1w/2, 3.5, r1z - 0.9), Vector3(0.7, 5, 0.15), frame_color, "Room1WinFrameL1")
	_make_block(Vector3(r1x + r1w/2, 3.5, r1z + 0.9), Vector3(0.7, 5, 0.15), frame_color, "Room1WinFrameR1")
	# West wall (solid)
	_make_block(Vector3(r1x - r1w/2, r1h/2, r1z), Vector3(0.5, r1h, r1d), room_color, "Room1WallW")
	
	# ============ ROOM 2: Wide Room (wide short windows, arched doorway) ============
	var r2x = base_x + 18.0
	var r2z = base_z
	var r2w = 16.0
	var r2d = 12.0
	var r2h = 7.0
	
	_make_block(Vector3(r2x, -0.5, r2z), Vector3(r2w, 1, r2d), grid_dark, "Room2Floor")
	_make_block(Vector3(r2x, r2h, r2z), Vector3(r2w, 0.5, r2d), room_color, "Room2Ceiling")
	
	# North wall (solid)
	_make_block(Vector3(r2x, r2h/2, r2z + r2d/2), Vector3(r2w, r2h, 0.5), room_color, "Room2WallN")
	# South wall with arched doorway (wider opening with arch block on top)
	_make_block(Vector3(r2x - 5.5, r2h/2, r2z - r2d/2), Vector3(5, r2h, 0.5), room_color, "Room2WallS_L")
	_make_block(Vector3(r2x + 5.5, r2h/2, r2z - r2d/2), Vector3(5, r2h, 0.5), room_color, "Room2WallS_R")
	_make_block(Vector3(r2x, r2h - 1.0, r2z - r2d/2), Vector3(6, r2h - 5, 0.5), room_color, "Room2WallS_Top")
	# Arch keystone block (decorative)
	_make_block(Vector3(r2x, 5.2, r2z - r2d/2), Vector3(1.0, 0.6, 0.7), frame_color, "Room2ArchKeystone")
	# Arch frame pillars
	_make_block(Vector3(r2x - 3.1, 2.5, r2z - r2d/2), Vector3(0.3, 5, 0.7), frame_color, "Room2ArchPillarL")
	_make_block(Vector3(r2x + 3.1, 2.5, r2z - r2d/2), Vector3(0.3, 5, 0.7), frame_color, "Room2ArchPillarR")
	# East wall with 3 wide short windows (3m wide, 1.5m tall)
	_make_block(Vector3(r2x + r2w/2, r2h/2, r2z - 4), Vector3(0.5, r2h, 1.5), room_color, "Room2WallE_1")
	_make_block(Vector3(r2x + r2w/2, r2h/2, r2z), Vector3(0.5, r2h, 1), room_color, "Room2WallE_2")
	_make_block(Vector3(r2x + r2w/2, r2h/2, r2z + 4), Vector3(0.5, r2h, 1.5), room_color, "Room2WallE_3")
	# Window pane fill (lower and upper for each gap)
	_make_block(Vector3(r2x + r2w/2, 1.0, r2z - 2), Vector3(0.5, 2, 2.5), room_color, "Room2WinBot1")
	_make_block(Vector3(r2x + r2w/2, r2h - 1.0, r2z - 2), Vector3(0.5, 2, 2.5), room_color, "Room2WinTop1")
	_make_block(Vector3(r2x + r2w/2, 1.0, r2z + 2), Vector3(0.5, 2, 2.5), room_color, "Room2WinBot2")
	_make_block(Vector3(r2x + r2w/2, r2h - 1.0, r2z + 2), Vector3(0.5, 2, 2.5), room_color, "Room2WinTop2")
	# Window sills
	_make_block(Vector3(r2x + r2w/2, 2.0, r2z - 2), Vector3(0.8, 0.15, 2.5), frame_color, "Room2Sill1")
	_make_block(Vector3(r2x + r2w/2, 2.0, r2z + 2), Vector3(0.8, 0.15, 2.5), frame_color, "Room2Sill2")
	# West wall (solid, shared with connector to room 1)
	_make_block(Vector3(r2x - r2w/2, r2h/2, r2z), Vector3(0.5, r2h, r2d), room_color, "Room2WallW")
	
	# ============ ROOM 3: Tall Room (circular-ish window cutouts, double-wide door) ============
	var r3x = base_x
	var r3z = base_z - 18.0
	var r3w = 14.0
	var r3d = 14.0
	var r3h = 12.0
	
	_make_block(Vector3(r3x, -0.5, r3z), Vector3(r3w, 1, r3d), grid_dark, "Room3Floor")
	_make_block(Vector3(r3x, r3h, r3z), Vector3(r3w, 0.5, r3d), room_color, "Room3Ceiling")
	
	# North wall with double-wide door (6m opening)
	_make_block(Vector3(r3x - 5.5, r3h/2, r3z + r3d/2), Vector3(3, r3h, 0.5), room_color, "Room3WallN_L")
	_make_block(Vector3(r3x + 5.5, r3h/2, r3z + r3d/2), Vector3(3, r3h, 0.5), room_color, "Room3WallN_R")
	_make_block(Vector3(r3x, r3h - 1.5, r3z + r3d/2), Vector3(6, r3h - 5, 0.5), room_color, "Room3WallN_Top")
	# Double door frame
	_make_block(Vector3(r3x - 3.1, 2.5, r3z + r3d/2), Vector3(0.2, 5, 0.8), frame_color, "Room3DoorFrameL")
	_make_block(Vector3(r3x + 3.1, 2.5, r3z + r3d/2), Vector3(0.2, 5, 0.8), frame_color, "Room3DoorFrameR")
	_make_block(Vector3(r3x, 5.1, r3z + r3d/2), Vector3(6.4, 0.2, 0.8), frame_color, "Room3DoorFrameTop")
	# Center divider post
	_make_block(Vector3(r3x, 2.5, r3z + r3d/2), Vector3(0.15, 5, 0.6), frame_color, "Room3DoorDivider")
	# South wall (solid)
	_make_block(Vector3(r3x, r3h/2, r3z - r3d/2), Vector3(r3w, r3h, 0.5), room_color, "Room3WallS")
	# East wall with circular-ish window (diamond of 4 blocks surrounding a gap)
	_make_block(Vector3(r3x + r3w/2, r3h/2, r3z - 5), Vector3(0.5, r3h, 3), room_color, "Room3WallE_Bot")
	_make_block(Vector3(r3x + r3w/2, r3h/2, r3z + 5), Vector3(0.5, r3h, 3), room_color, "Room3WallE_Top")
	_make_block(Vector3(r3x + r3w/2, 1.5, r3z), Vector3(0.5, 3, 7), room_color, "Room3WallE_Low")
	_make_block(Vector3(r3x + r3w/2, r3h - 1.5, r3z), Vector3(0.5, 3, 7), room_color, "Room3WallE_High")
	# Circular frame ring (4 pieces)
	_make_block(Vector3(r3x + r3w/2, 5.0, r3z - 2.5), Vector3(0.7, 0.3, 0.3), frame_color, "Room3CircFrameBot")
	_make_block(Vector3(r3x + r3w/2, 5.0, r3z + 2.5), Vector3(0.7, 0.3, 0.3), frame_color, "Room3CircFrameTop")
	_make_block(Vector3(r3x + r3w/2, 3.0, r3z), Vector3(0.7, 0.3, 0.3), frame_color, "Room3CircFrameL")
	_make_block(Vector3(r3x + r3w/2, 7.0, r3z), Vector3(0.7, 0.3, 0.3), frame_color, "Room3CircFrameR")
	# West wall (solid)
	_make_block(Vector3(r3x - r3w/2, r3h/2, r3z), Vector3(0.5, r3h, r3d), room_color, "Room3WallW")
	
	# ============ ROOM 4: Bunker Room (arrow slit windows, narrow reinforced door) ============
	var r4x = base_x + 18.0
	var r4z = base_z - 18.0
	var r4w = 14.0
	var r4d = 12.0
	var r4h = 6.0
	
	_make_block(Vector3(r4x, -0.5, r4z), Vector3(r4w, 1, r4d), grid_dark, "Room4Floor")
	_make_block(Vector3(r4x, r4h, r4z), Vector3(r4w, 0.5, r4d), room_color, "Room4Ceiling")
	
	# North wall with narrow reinforced door (1.5m wide, 3.5m tall)
	_make_block(Vector3(r4x - 4.5, r4h/2, r4z + r4d/2), Vector3(5, r4h, 0.5), room_color, "Room4WallN_L")
	_make_block(Vector3(r4x + 4.5, r4h/2, r4z + r4d/2), Vector3(5, r4h, 0.5), room_color, "Room4WallN_R")
	_make_block(Vector3(r4x, r4h - 0.75, r4z + r4d/2), Vector3(2, r4h - 3.5, 0.5), room_color, "Room4WallN_Top")
	# Heavy door frame (thick)
	_make_block(Vector3(r4x - 0.85, 1.75, r4z + r4d/2), Vector3(0.3, 3.5, 0.9), frame_color, "Room4DoorFrameL")
	_make_block(Vector3(r4x + 0.85, 1.75, r4z + r4d/2), Vector3(0.3, 3.5, 0.9), frame_color, "Room4DoorFrameR")
	_make_block(Vector3(r4x, 3.6, r4z + r4d/2), Vector3(2.0, 0.3, 0.9), frame_color, "Room4DoorFrameTop")
	# Threshold step
	_make_block(Vector3(r4x, 0.15, r4z + r4d/2), Vector3(1.7, 0.3, 1.0), frame_color, "Room4Threshold")
	# South wall (solid)
	_make_block(Vector3(r4x, r4h/2, r4z - r4d/2), Vector3(r4w, r4h, 0.5), room_color, "Room4WallS")
	# West wall with 4 arrow slit windows (0.3m wide, 2m tall, evenly spaced)
	var slit_positions = [-4.0, -1.5, 1.5, 4.0]
	for i in slit_positions.size():
		var sz = r4z + slit_positions[i]
		# Wall segments between slits
		if i == 0:
			_make_block(Vector3(r4x - r4w/2, r4h/2, r4z - r4d/2 + 1), Vector3(0.5, r4h, 2), room_color, "Room4WallW_seg0")
		_make_block(Vector3(r4x - r4w/2, 1.0, sz), Vector3(0.5, 2, 0.8), room_color, "Room4SlitBot_" + str(i))
		_make_block(Vector3(r4x - r4w/2, r4h - 1.0, sz), Vector3(0.5, 2, 0.8), room_color, "Room4SlitTop_" + str(i))
		# Slit frame
		_make_block(Vector3(r4x - r4w/2, 3.0, sz - 0.2), Vector3(0.7, 2.5, 0.1), frame_color, "Room4SlitFrameL_" + str(i))
		_make_block(Vector3(r4x - r4w/2, 3.0, sz + 0.2), Vector3(0.7, 2.5, 0.1), frame_color, "Room4SlitFrameR_" + str(i))
	# Fill remaining west wall
	_make_block(Vector3(r4x - r4w/2, r4h/2, r4z + r4d/2 - 1), Vector3(0.5, r4h, 2), room_color, "Room4WallW_end")
	# East wall (solid)
	_make_block(Vector3(r4x + r4w/2, r4h/2, r4z), Vector3(0.5, r4h, r4d), room_color, "Room4WallE")
	
	# ============ ROOM 5: Open Gallery (floor-to-ceiling windows, no door — open arch) ============
	var r5x = base_x + 9.0
	var r5z = base_z - 36.0
	var r5w = 20.0
	var r5d = 10.0
	var r5h = 10.0
	
	_make_block(Vector3(r5x, -0.5, r5z), Vector3(r5w, 1, r5d), grid_dark, "Room5Floor")
	_make_block(Vector3(r5x, r5h, r5z), Vector3(r5w, 0.5, r5d), room_color, "Room5Ceiling")
	# North wall (connects to rooms 3 & 4)
	_make_block(Vector3(r5x - 7, r5h/2, r5z + r5d/2), Vector3(6, r5h, 0.5), room_color, "Room5WallN_L")
	_make_block(Vector3(r5x + 7, r5h/2, r5z + r5d/2), Vector3(6, r5h, 0.5), room_color, "Room5WallN_R")
	_make_block(Vector3(r5x, r5h - 1, r5z + r5d/2), Vector3(8, r5h - 6, 0.5), room_color, "Room5WallN_Top")
	# South wall with floor-to-ceiling window panels (thin pillars between glass-like gaps)
	var pillar_count = 5
	for i in pillar_count:
		var pz_offset = -r5d/2 + 1.0 + i * ((r5d - 2) / float(pillar_count - 1))
		_make_block(Vector3(r5x, r5h/2, r5z - r5d/2), Vector3(r5w, r5h, 0.5), room_color, "Room5WallS")
	# East wall with big open arch (decorative)
	_make_block(Vector3(r5x + r5w/2, r5h/2, r5z - 3), Vector3(0.5, r5h, 4), room_color, "Room5WallE_1")
	_make_block(Vector3(r5x + r5w/2, r5h/2, r5z + 3), Vector3(0.5, r5h, 4), room_color, "Room5WallE_2")
	_make_block(Vector3(r5x + r5w/2, r5h - 1, r5z), Vector3(0.5, 2, 6), room_color, "Room5WallE_Top")
	# West wall (solid)
	_make_block(Vector3(r5x - r5w/2, r5h/2, r5z), Vector3(0.5, r5h, r5d), room_color, "Room5WallW")

func _build_wall_run_zone():
	var base_x = 0.0
	var base_z = -30.0
	
	# Connector bridge from spawn
	_make_block(Vector3(0, -0.5, -22), Vector3(6, 1, 4), grid_dark, "WallRunBridge")
	
	# Floor
	_make_block(Vector3(base_x, -0.5, base_z - 15), Vector3(40, 1, 30), grid_dark, "WallRunFloor")
	
	# Wall run corridors - 3 pairs at different widths
	var widths = [3.0, 5.0, 7.0]
	for i in widths.size():
		var w = widths[i]
		var x_offset = base_x - 12 + i * 12
		
		# Left wall
		_make_block(
			Vector3(x_offset - w/2.0, 5, base_z - 15),
			Vector3(0.5, 10, 20),
			wall_color, "WallRunL_" + str(i)
		)
		# Right wall
		_make_block(
			Vector3(x_offset + w/2.0, 5, base_z - 15),
			Vector3(0.5, 10, 20),
			wall_color, "WallRunR_" + str(i)
		)
	
	# Wall jump chimney (narrow, tall)
	_make_block(Vector3(base_x + 16, 10, base_z - 20), Vector3(0.5, 20, 6), wall_color, "ChimneyL")
	_make_block(Vector3(base_x + 19, 10, base_z - 20), Vector3(0.5, 20, 6), wall_color, "ChimneyR")
	# Reward platform at top
	_make_block(Vector3(base_x + 17.5, 20, base_z - 20), Vector3(5, 1, 6), grid_accent, "ChimneyTop")

func _build_tower_zone():
	var base_x = 0.0
	var base_z = 35.0
	
	# Connector bridge from spawn
	_make_block(Vector3(0, -0.5, 22), Vector3(6, 1, 4), grid_dark, "TowerBridge")
	
	# Tower base floor
	_make_block(Vector3(base_x, -0.5, base_z), Vector3(16, 1, 16), grid_dark, "TowerBase")
	
	# Tower walls (4 sides, with gaps for entry)
	var tower_h = 35.0
	var tower_w = 16.0
	var half = tower_w / 2.0
	
	# North wall (solid)
	_make_block(Vector3(base_x, tower_h/2, base_z + half), Vector3(tower_w, tower_h, 0.5), tower_color, "TowerWallN")
	# South wall (gap at bottom for entry)
	_make_block(Vector3(base_x - 4, tower_h/2, base_z - half), Vector3(tower_w/2 - 2, tower_h, 0.5), tower_color, "TowerWallS_L")
	_make_block(Vector3(base_x + 4, tower_h/2, base_z - half), Vector3(tower_w/2 - 2, tower_h, 0.5), tower_color, "TowerWallS_R")
	# East wall
	_make_block(Vector3(base_x + half, tower_h/2, base_z), Vector3(0.5, tower_h, tower_w), tower_color, "TowerWallE")
	# West wall
	_make_block(Vector3(base_x - half, tower_h/2, base_z), Vector3(0.5, tower_h, tower_w), tower_color, "TowerWallW")
	
	# Interior stepping platforms (spiral upward)
	var platform_count = 8
	for i in platform_count:
		var angle_rad = (float(i) / platform_count) * TAU
		var radius = 4.5
		var px = base_x + cos(angle_rad) * radius
		var pz = base_z + sin(angle_rad) * radius
		var py = 3.0 + i * 4.0
		_make_block(
			Vector3(px, py, pz),
			Vector3(3, 0.5, 3),
			grid_dark.lerp(grid_accent, float(i) / platform_count),
			"TowerPlat_" + str(i)
		)
	
	# Crown platform at top
	_make_block(Vector3(base_x, tower_h + 1, base_z), Vector3(12, 1, 12), grid_accent, "TowerCrown")

func _build_tight_zone():
	var base_x = 0.0
	var base_z = -60.0
	
	# Connector from wall run zone
	_make_block(Vector3(0, -0.5, -47), Vector3(6, 1, 6), grid_dark, "TightBridge")
	
	# Floor
	_make_block(Vector3(base_x, -0.5, base_z), Vector3(30, 1, 16), grid_dark, "TightFloor")
	
	# Corridor 1: 3m wide
	_make_block(Vector3(base_x - 8, 2.5, base_z), Vector3(0.3, 5, 14), wall_color, "TightWall1L")
	_make_block(Vector3(base_x - 5, 2.5, base_z), Vector3(0.3, 5, 14), wall_color, "TightWall1R")
	_make_block(Vector3(base_x - 6.5, 5, base_z), Vector3(3.3, 0.3, 14), wall_color, "TightCeiling1")
	
	# Corridor 2: 2m wide
	_make_block(Vector3(base_x - 1, 2.5, base_z), Vector3(0.3, 5, 14), wall_color, "TightWall2L")
	_make_block(Vector3(base_x + 1, 2.5, base_z), Vector3(0.3, 5, 14), wall_color, "TightWall2R")
	_make_block(Vector3(base_x, 4, base_z), Vector3(2.3, 0.3, 14), wall_color, "TightCeiling2")
	
	# Corridor 3: 1.5m wide, low ceiling
	_make_block(Vector3(base_x + 4, 2.5, base_z), Vector3(0.3, 5, 14), wall_color, "TightWall3L")
	_make_block(Vector3(base_x + 5.5, 2.5, base_z), Vector3(0.3, 5, 14), wall_color, "TightWall3R")
	_make_block(Vector3(base_x + 4.75, 3, base_z), Vector3(1.8, 0.3, 14), wall_color, "TightCeiling3")
	
	# L-shaped corridor for camera stress
	_make_block(Vector3(base_x + 9, 2.5, base_z - 3), Vector3(0.3, 5, 8), wall_color, "LCornerW1")
	_make_block(Vector3(base_x + 12, 2.5, base_z - 3), Vector3(0.3, 5, 8), wall_color, "LCornerW2")
	_make_block(Vector3(base_x + 12, 2.5, base_z + 1.5), Vector3(8, 5, 0.3), wall_color, "LCornerW3")
	_make_block(Vector3(base_x + 12, 2.5, base_z - 1.5), Vector3(8, 5, 0.3), wall_color, "LCornerW4")

func _build_arena_zone():
	var base_x = 0.0
	var base_z = -100.0
	
	# Connector
	_make_block(Vector3(0, -0.5, -70), Vector3(6, 1, 10), grid_dark, "ArenaBridge")
	_make_block(Vector3(0, -0.5, -80), Vector3(6, 1, 10), grid_dark, "ArenaBridge2")
	_make_block(Vector3(0, -0.5, -90), Vector3(6, 1, 10), grid_dark, "ArenaBridge3")
	
	# Massive floor
	_make_block(Vector3(base_x, -0.5, base_z), Vector3(80, 1, 80), grid_dark, "ArenaFloor")
	
	# Scattered cover blocks (various sizes)
	var covers = [
		[Vector3(-20, 1.5, base_z - 10), Vector3(3, 3, 3)],
		[Vector3(-10, 1, base_z + 15), Vector3(5, 2, 2)],
		[Vector3(15, 2, base_z - 20), Vector3(2, 4, 6)],
		[Vector3(25, 1.5, base_z + 5), Vector3(4, 3, 4)],
		[Vector3(-25, 2.5, base_z + 20), Vector3(3, 5, 3)],
		[Vector3(10, 1, base_z + 25), Vector3(8, 2, 2)],
		[Vector3(-15, 3, base_z - 25), Vector3(2, 6, 2)],
		[Vector3(30, 1, base_z - 5), Vector3(2, 2, 10)],
	]
	for i in covers.size():
		_make_block(covers[i][0], covers[i][1], wall_color, "ArenaCover_" + str(i))
	
	# Perimeter flow parkour rail (elevated platforms around edge)
	var rail_h = 4.0
	var half_arena = 38.0
	var plat_count = 12
	for i in plat_count:
		var t = float(i) / plat_count
		var angle = t * TAU
		var px = base_x + cos(angle) * half_arena
		var pz = base_z + sin(angle) * half_arena
		var py = rail_h + sin(angle * 3) * 2.0  # Undulating height
		_make_block(
			Vector3(px, py, pz),
			Vector3(5, 0.5, 5),
			grid_dark.lerp(grid_line, t),
			"FlowPlat_" + str(i)
		)
	
	# Central pillar for pogo testing
	_make_block(Vector3(base_x, 8, base_z), Vector3(3, 16, 3), tower_color, "ArenaPillar")

func _build_kill_floor():
	# Invisible kill floor far below - resets player position
	_make_block(Vector3(0, -50, -50), Vector3(500, 1, 500), Color(0.5, 0.05, 0.05, 1.0), "KillFloor")

func _build_safety_floor():
	# Catch players who fall with a massive basement floor
	_make_block(Vector3(0, -10, -15), Vector3(250, 1, 280), grid_dark.lerp(tower_color, 0.3), "SafetyFloor")
	
	# Add some ramps from the safety floor back to spawn so they can walk up
	_make_ramp(Vector3(-10, -4.5, 10), Vector3(10, 1, 15), 35.0, ramp_color, "RecoveryRamp1")
	_make_ramp(Vector3(10, -4.5, -20), Vector3(10, 1, 15), -35.0, ramp_color, "RecoveryRamp2")

func _build_enemies_and_lights():
	# Lights in Room Zone
	var base_x = -70.0
	var base_z = -35.0
	_make_light(Vector3(base_x, 6, base_z), 2.5, 15.0, Color(0.8, 0.9, 1.0), "Room1Light")
	_make_light(Vector3(base_x + 18, 5, base_z), 3.0, 20.0, Color(1.0, 0.8, 0.6), "Room2Light")
	_make_light(Vector3(base_x, 8, base_z - 18), 3.5, 25.0, Color(0.9, 0.7, 1.0), "Room3Light")
	_make_light(Vector3(base_x + 18, 4, base_z - 18), 2.0, 12.0, Color(1.0, 0.5, 0.5), "Room4Light")
	
	# Tight Zone Lights
	_make_light(Vector3(0, 4, -60), 2.0, 30.0, Color(0.6, 1.0, 0.8), "TightZoneLight1")
	
	# Spawn Arena enemies
	_make_enemy(Vector3(0, 3, -100), 3.0, "ArenaSuperBoss")
	_make_enemy(Vector3(-25, 2, -80), 1.8, "ArenaMedEnemy1")
	_make_enemy(Vector3(25, 2, -80), 1.8, "ArenaMedEnemy2")
	for i in range(6):
		_make_enemy(Vector3(-30 + i*12, 1, -120), 1.0, "ArenaBasic_" + str(i))
		
	# High/Far Enemies
	_make_enemy(Vector3(60, 9, 0), 1.5, "DoubleJumpPillarEnemy") # On DoubleJumpPillar
	_make_enemy(Vector3(0, 38, 35), 2.5, "TowerCrownBoss") # Top of Tower
	_make_enemy(Vector3(-46, 8, -45), 1.0, "RidgeEnemy") # Ridge walkway connect
	_make_enemy(Vector3(-61, 2, -71), 1.5, "Room5GalleryEnemy") # Room 5 Open Gallery
	
	_make_enemy(Vector3(-40, 11, 23), 1.3, "RampEnemyHighest")
	_make_enemy(Vector3(-40, 6, 13), 1.3, "RampEnemyMid")

# ============================================================
# GEOMETRY HELPERS
# ============================================================

func _make_light(pos: Vector3, energy: float, range_m: float, color: Color, node_name: String):
	var light = OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_energy = energy
	light.omni_range = range_m
	light.light_color = color
	light.shadow_enabled = true
	add_child(light)

func _make_enemy(pos: Vector3, size_mult: float, node_name: String):
	var EnemyScript = load("res://scripts/enemies/basic_enemy.gd")
	if not EnemyScript:
		print("Error: Could not load basic_enemy.gd")
		return
	var enemy = EnemyScript.new()
	enemy.name = node_name
	enemy.position = pos
	enemy.scale = Vector3.ONE * size_mult
	add_child(enemy)

func _make_block(pos: Vector3, size: Vector3, color: Color, node_name: String):
	var body = StaticBody3D.new()
	body.name = node_name
	body.position = pos
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	
	var mat = _make_grid_material(color, size)
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	
	add_child(body)

func _make_ramp(pos: Vector3, size: Vector3, angle_deg: float, color: Color, node_name: String):
	var body = StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees.x = angle_deg
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	
	var mat = _make_grid_material(color, size)
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	
	add_child(body)

func _make_grid_material(base_color: Color, size: Vector3) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.85
	mat.metallic = 0.05
	# Use UV1 triplanar for consistent grid on all faces
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(1, 1, 1) # 1m grid cells
	
	# Make floors slightly emissive so grid is visible
	if base_color.v < 0.2:
		mat.emission_enabled = true
		mat.emission = grid_line
		mat.emission_energy_multiplier = 0.03
	
	return mat
