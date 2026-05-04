extends BaseProjectile

func _ready():
	super._ready()
	# Nodes are now handled in the .tscn file

func _physics_process(delta: float):
	super._physics_process(delta)
