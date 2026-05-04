extends Area3D

var speed: float = 20.0
var damage: float = 20.0
var direction: Vector3 = Vector3.FORWARD
var life_time: float = 4.0

func _ready():
	body_entered.connect(_on_body_entered)
	
func _physics_process(delta: float):
	global_position += direction * speed * delta
	
	life_time -= delta
	if life_time <= 0:
		queue_free()

func _on_body_entered(body: Node3D):
	if body.is_in_group("enemy") or body.is_in_group("enemy_hurtbox"):
		return
		
	if body.has_method("take_damage"):
		var push_dir = direction
		push_dir.y += 0.2
		body.take_damage(damage, push_dir.normalized(), 400.0, 0.4, 0.1)
		
	queue_free()
