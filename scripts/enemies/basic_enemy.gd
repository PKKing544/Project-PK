@tool
extends BaseEnemy

func _ready():
	super._ready()
	# Basic enemy specific weight if needed, otherwise it uses BaseEnemy default
	if knockback_comp:
		knockback_comp.weight = 800.0 * scale.x
		knockback_comp.wall_bounce_multiplier = 0.2

func _update_debug_label():
	if knockback_comp:
		var kb = knockback_comp
		var txt = "[ %s | HP: %d ]\n" % [name, int(hp)]
		if is_dead: txt = "[ K.O. ]\n"
		if kb.last_raw_force > 0:
			txt += "Force: %.1f x%.2f (LowHP)\n" % [kb.last_raw_force, kb.last_health_mult]
			txt += "-> Accel: %.1f (M/%.1f)\n" % [kb.last_accel, kb.weight * 0.1]
			txt += "Stun: %.2fs" % kb.hitstun_timer
		debug_label.text = txt
