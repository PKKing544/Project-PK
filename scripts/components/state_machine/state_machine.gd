class_name StateMachine extends Node

@export var initial_state: State

var state: State

func _ready() -> void:
	for child in get_children():
		if child is State:
			child.state_machine = self
	
	if initial_state:
		state = initial_state
		state.enter()

func _unhandled_input(event: InputEvent) -> void:
	if state and state.has_method("handle_input"):
		state.handle_input(event)

func _process(delta: float) -> void:
	if state:
		state.update(delta)

func _physics_process(delta: float) -> void:
	if state:
		state.physics_update(delta)

func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	if not has_node(target_state_name):
		return
		
	var target_state = get_node(target_state_name)
	if not target_state is State:
		return
		
	if state:
		state.exit()
		
	state = target_state
	state.enter(msg)
