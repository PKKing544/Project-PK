extends BaseProjectile

func _ready():
	super._ready() 
	# Collision and Mesh are now handled by the .tscn nodes 
	# so you can see and edit them in the Godot Editor!

func _physics_process(delta: float):
	super._physics_process(delta)
