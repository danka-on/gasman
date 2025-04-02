extends Node
class_name StateMachine

# Signal emitted when transitioning to a new state
signal transitioned(state_name)

# Current active state
var current_state = null
var states = {}

# The owner node that this state machine controls
@export var owner_node : Node

func _ready():
    # Connect to ready of all state nodes
    for child in get_children():
        if child.has_method("enter") and child.has_method("exit") and child.has_method("update"):
            states[child.name.to_lower()] = child
            child.state_machine = self
            if owner_node:
                child.owner_node = owner_node

# Initialize with a default state
func initialize(initial_state):
    if states.has(initial_state.to_lower()):
        current_state = states[initial_state.to_lower()]
        current_state.enter()
    else:
        printerr("Invalid initial state: ", initial_state)

# Update the current state
func process_state(delta):
    if current_state:
        current_state.update(delta)
        
func physics_process_state(delta):
    if current_state:
        current_state.physics_update(delta)

# Handle input in the current state
func handle_input(event):
    if current_state:
        current_state.handle_input(event)

# Transition to a new state
func transition_to(new_state, msg = {}):
    if not states.has(new_state.to_lower()):
        printerr("Trying to transition to non-existent state: ", new_state)
        return
        
    if current_state:
        current_state.exit()
        
    var prev_state = current_state.name if current_state else "none"
    current_state = states[new_state.to_lower()]
    current_state.enter(msg)
    
    emit_signal("transitioned", current_state.name)
    print("Transitioned from ", prev_state, " to ", current_state.name)

# Returns the name of the current state
func get_current_state():
    return current_state.name if current_state else "none"
