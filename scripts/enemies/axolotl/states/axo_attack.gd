extends State
class_name AxoAttack

var enemy: Node3D

func enter(_msg := {}) -> void:
	enemy = state_machine.get_parent()

func update(delta: float) -> void:
	var dist = enemy.global_position.distance_to(enemy.player.global_position)
	
	if dist > enemy.melee_radius:
		state_machine.transition_to("AxoCharge")
		return
		
	var can_see = enemy._has_line_of_sight()
	if enemy.flamethrower_area:
		enemy.flamethrower_area.monitoring = can_see
		if enemy.flamethrower_mesh: enemy.flamethrower_mesh.visible = can_see
		if can_see:
			enemy._tick_flamethrower_damage(delta)
			
	if enemy.mouth_fireball: 
		enemy.mouth_fireball.scale = enemy.mouth_fireball.scale.lerp(Vector3.ZERO, delta * 40.0)
