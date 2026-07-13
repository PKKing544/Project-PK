extends SceneTree

func _init():
	var fireball_scene = load("res://scenes/enemies/fireball.tscn")
	var proj = fireball_scene.instantiate()
	root.add_child(proj)
	
	print("--- FIREBALL TEST START ---")
	print("Initial global_position: ", proj.global_position)
	print("Initial direction: ", proj.direction)
	print("Initial start_speed: ", proj.start_speed)
	print("Initial sprite scale: ", proj.sprite.scale if proj.sprite else "NO SPRITE")
	
	proj.global_position = Vector3(10, 5, 10)
	proj.direction = Vector3(1, 0, 0)
	proj.player = Node3D.new() # Fake player
	proj.player.global_position = Vector3(20, 5, 10)
	
	for i in range(10):
		proj._physics_process(0.016)
		print("Frame ", i, " - Pos: ", proj.global_position, " | Dir: ", proj.direction, " | Exploding: ", proj.exploding)
	
	print("--- TEST COMPLETE ---")
	quit()
