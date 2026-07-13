extends State
class_name AxoSleep

var enemy: Node3D

func enter(_msg := {}) -> void:
	enemy = state_machine.get_parent()
	enemy.charge_timer = 0.0
	enemy.fireball_charged = false
	if enemy.mouth_fireball: 
		# We'll let the process loop lerp it down, or just snap it.
		pass
	if enemy.flamethrower_area: enemy.flamethrower_area.monitoring = false
	if enemy.flamethrower_mesh: enemy.flamethrower_mesh.visible = false

func update(delta: float) -> void:
	var dist = enemy.global_position.distance_to(enemy.player.global_position)
	
	if dist <= enemy.melee_radius:
		state_machine.transition_to("AxoAttack")
	elif dist <= enemy.threat_radius:
		state_machine.transition_to("AxoCharge")
		
	# Lerp fireball down
	if enemy.mouth_fireball:
		enemy.mouth_fireball.scale = enemy.mouth_fireball.scale.lerp(Vector3.ZERO, delta * 5.0)
