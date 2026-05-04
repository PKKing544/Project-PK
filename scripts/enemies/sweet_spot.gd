extends AnimatableBody3D

@export var damage_multiplier: float = 2.0

func _ready():
	add_to_group("enemy_hurtbox")

func get_enemy_body() -> Node:
	if owner and owner.has_method("take_damage"): return owner
	if get_parent() and get_parent().get_parent() and get_parent().get_parent().has_method("take_damage"):
		return get_parent().get_parent()
	return null

func preview_damage(amount: float):
	var body = get_enemy_body()
	if body and body.has_method("preview_damage"):
		body.preview_damage(amount * damage_multiplier)

func heal(amount: float):
	var body = get_enemy_body()
	if body and body.has_method("heal"):
		body.heal(amount * damage_multiplier)

func take_damage(amount: float):
	var body = get_enemy_body()
	if body:
		if body.has_method("head_hit"):
			body.head_hit(amount * damage_multiplier)
		elif body.has_method("take_damage"):
			body.take_damage(amount * damage_multiplier)

func get_knockback_component() -> Node:
	var body = get_enemy_body()
	if body:
		for child in body.get_children():
			if child is KnockbackComponent:
				return child
	return null
