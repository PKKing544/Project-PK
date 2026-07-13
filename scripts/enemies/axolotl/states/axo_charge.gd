extends State
class_name AxoCharge

var enemy: Node3D

func enter(_msg := {}) -> void:
	enemy = state_machine.get_parent()
	if enemy.flamethrower_area: enemy.flamethrower_area.monitoring = false
	if enemy.flamethrower_mesh: enemy.flamethrower_mesh.visible = false

func update(delta: float) -> void:
	var dist = enemy.global_position.distance_to(enemy.player.global_position)
	
	if dist > enemy.threat_radius:
		state_machine.transition_to("AxoSleep")
		return
	elif dist <= enemy.melee_radius:
		state_machine.transition_to("AxoAttack")
		return
		
	if not enemy.fireball_charged:
		enemy.charge_timer += delta
		var scale_val = clamp(enemy.charge_timer / enemy.charge_time, 0.0, 1.0)
		var base_scale = Vector3(-2, 2, -2)
		if enemy.mouth_fireball: enemy.mouth_fireball.scale = base_scale * scale_val
		if enemy.charge_timer >= enemy.charge_time:
			enemy.fireball_charged = true
			if enemy.mouth_fireball: enemy.mouth_fireball.scale = base_scale * 1.5
	else:
		# Hold fire indefinitely until we have a clear shot
		if enemy._has_line_of_sight():
			# Give leeway on the fire radius so it still shoots if the player backed up while it was charging
			if dist <= enemy.fire_radius * 2.0:
				enemy._fire_projectile()
				enemy.fireball_charged = false
				enemy.charge_timer = -enemy.fire_delay
				if enemy.mouth_fireball: enemy.mouth_fireball.scale = Vector3.ZERO
			else:
				# If player ran WAY far away, cancel the charge to prevent holding it forever
				state_machine.transition_to("AxoSleep")
