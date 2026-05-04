@tool
extends EditorScript

func _run():
	print("Generating Burst Resources...")
	
	var dir = DirAccess.open("res://scripts/weapons")
	if not dir.dir_exists("data/instances"):
		dir.make_dir_recursive("data/instances")
		
	var splash = SplashDamageEffect.new()
	splash.base_splash_damage = 15.0
	splash.splash_radius_m = 3.0
	
	var kb_primary = KnockbackEffect.new()
	kb_primary.base_knockback_force = 100.0
	
	var kb_secondary = KnockbackEffect.new()
	kb_secondary.base_knockback_force = 500.0
	
	var primary = FireModeData.new()
	primary.mode_name = "Burst Tap"
	primary.fire_type = FireModeData.FireType.HITSCAN
	primary.trigger_type = FireModeData.TriggerType.SEMI_AUTO
	primary.damage = 5.0
	primary.fire_rate_sec = 0.2 
	primary.ink_cost = 0.0 # Primary is free
	primary.spread_deg = 0.3 
	primary.kickback_force = 1.0
	primary.hit_effects.append(kb_primary)
	
	var secondary = FireModeData.new()
	secondary.mode_name = "Burst Charged"
	secondary.fire_type = FireModeData.FireType.PROJECTILE
	secondary.trigger_type = FireModeData.TriggerType.CHARGE
	secondary.damage = 15.0 
	secondary.ink_cost = 1.0
	secondary.min_charge_time_sec = 0.3 
	secondary.max_charge_time_sec = 1.2
	secondary.projectile_speed_m_s = 60.0
	secondary.kickback_force = 15.0
	
	var proj_scene = PackedScene.new()
	var proj_node = Area3D.new()
	proj_node.set_script(load("res://scripts/weapons/logic/impl/burst_projectile.gd")) 
	proj_scene.pack(proj_node)
	ResourceSaver.save(proj_scene, "res://scripts/weapons/logic/impl/burst_projectile.tscn")
	
	secondary.projectile_scene = load("res://scripts/weapons/logic/impl/burst_projectile.tscn")
	secondary.hit_effects.append(splash)
	secondary.hit_effects.append(kb_secondary)
	
	var hand = HandData.new()
	hand.hand_name = "Burst"
	hand.primary_mode = primary
	hand.secondary_mode = secondary
	hand.max_ink = 100.0
	hand.passive_ink_regen_per_sec = 0.666 # 2 ink every 3 seconds
	ResourceSaver.save(hand, "res://scripts/weapons/data/instances/burst_hand.tres")
	
	var heavy = HeavyAttackData.new()
	heavy.attack_name = "Lunge Punch"
	heavy.damage = 100.0
	heavy.knockback_force = 900.0
	heavy.hitstop_duration = 0.05
	heavy.lunge_boost = 45.0
	heavy.lunge_window_ratio = 0.3
	heavy.pogo_bounce = 25.0
	heavy.pogo_upward_bias = 2.0
	heavy.charge_threshold = 0.3
	heavy.swing_duration = 0.25
	heavy.cooldown_duration = 0.8
	heavy.refund_on_hit = true
	ResourceSaver.save(heavy, "res://scripts/weapons/data/instances/default_heavy.tres")
	
	print("Resources Generated Successfully.")
