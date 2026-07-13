class_name State extends Node

var state_machine = null

# Called when the state is entered
func enter(_msg := {}) -> void:
	pass

# Called when the state is exited
func exit() -> void:
	pass

# Corresponds to the `_process()` callback
func update(_delta: float) -> void:
	pass

# Corresponds to the `_physics_process()` callback
func physics_update(_delta: float) -> void:
	pass
