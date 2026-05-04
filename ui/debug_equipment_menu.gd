extends Control

var player: Node3D

@onready var panel = $Panel
@onready var hand_opt = $Panel/VBox/HandOpt
@onready var attachment_opt = $Panel/VBox/AttachmentOpt
@onready var ability_opt = $Panel/VBox/AbilityOpt
@onready var dash_opt = $Panel/VBox/DashOpt
@onready var heavy_opt = $Panel/VBox/HeavyOpt

var paths = {
	"hands": "res://scripts/weapons/data/instances/hands/",
	"attachments": "res://scripts/weapons/data/instances/attachments/",
	"abilities": "res://scripts/weapons/data/instances/abilities/",
	"dashes": "res://scripts/weapons/data/instances/dashes/",
	"heavy_attacks": "res://scripts/weapons/data/instances/heavy_attacks/"
}

var loaded_resources = {
	"hands": [],
	"attachments": [],
	"abilities": [],
	"dashes": [],
	"heavy_attacks": []
}

func _ready():
	visible = false
	_populate_dropdown("hands", hand_opt)
	_populate_dropdown("attachments", attachment_opt)
	_populate_dropdown("abilities", ability_opt)
	_populate_dropdown("dashes", dash_opt)
	_populate_dropdown("heavy_attacks", heavy_opt)
	
	hand_opt.item_selected.connect(func(idx): _on_item_selected("hands", idx))
	attachment_opt.item_selected.connect(func(idx): _on_item_selected("attachments", idx))
	ability_opt.item_selected.connect(func(idx): _on_item_selected("abilities", idx))
	dash_opt.item_selected.connect(func(idx): _on_item_selected("dashes", idx))
	heavy_opt.item_selected.connect(func(idx): _on_item_selected("heavy_attacks", idx))
	
func _input(event):
	if event is InputEventKey and event.keycode == KEY_C and event.pressed:
		visible = not visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			# Resync selection in case it was changed elsewhere
			_sync_selection("hands", hand_opt)
			_sync_selection("attachments", attachment_opt)
			_sync_selection("abilities", ability_opt)
			_sync_selection("dashes", dash_opt)
			_sync_selection("heavy_attacks", heavy_opt)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _populate_dropdown(category: String, opt_button: OptionButton):
	opt_button.clear()
	loaded_resources[category].clear()
	
	var dir_path = paths[category]
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(dir_path + file_name)
				if res:
					loaded_resources[category].append(res)
					opt_button.add_item(file_name.replace(".tres", ""))
			file_name = dir.get_next()
	
	_sync_selection(category, opt_button)

func _sync_selection(category: String, opt_button: OptionButton):
	if not player: return
	var current_res = null
	match category:
		"hands": current_res = player.equipped_hand
		"attachments": current_res = player.equipped_attachment
		"abilities": current_res = player.equipped_ability
		"dashes": current_res = player.equipped_dash
		"heavy_attacks": current_res = player.equipped_heavy_attack
		
	if current_res:
		for i in range(loaded_resources[category].size()):
			if loaded_resources[category][i] == current_res:
				opt_button.select(i)
				break

func _on_item_selected(category: String, idx: int):
	if not player: return
	var res = loaded_resources[category][idx]
	match category:
		"hands": player.equipped_hand = res
		"attachments": player.equipped_attachment = res
		"abilities": player.equipped_ability = res
		"dashes": player.equipped_dash = res
		"heavy_attacks": player.equipped_heavy_attack = res
	
	player.update_equipment()
