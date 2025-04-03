# state_machine.gd - Improved state machine
extends Node
class_name StateMachine

# Signal emitted when transitioning to a new state
signal transitioned(state_name)

# Current active state
var current_state = null
var states = {}
var is_initialized = false

# The owner node that this state machine controls
@export var owner_node : Node

func _ready():
    # Connect to ready of all state nodes
    for child in get_children():
        if child is State or (child.has_method("enter") and child.has_method("exit") and child.has_method("update")):
            states[child.name.to_lower()] = child
            child.state_machine = self
            if owner_node:
                child.owner_node = owner_node
            else:
                push_warning("StateMachine: No owner node set for state " + child.name)

# Initialize with a default state
func initialize(initial_state):
    if not owner_node:
        push_error("StateMachine: Cannot initialize without owner node")
        return
        
    if states.has(initial_state.to_lower()):
        current_state = states[initial_state.to_lower()]
        current_state.enter()
        is_initialized = true
    else:
        push_error("StateMachine: Invalid initial state: " + initial_state)

# Update the current state
func _process(delta):
    if is_initialized and current_state and current_state.has_method("update"):
        current_state.update(delta)
        
func _physics_process(delta):
    if is_initialized and current_state and current_state.has_method("physics_update"):
        current_state.physics_update(delta)

# Handle input in the current state
func _input(event):
    if is_initialized and current_state and current_state.has_method("handle_input"):
        current_state.handle_input(event)

# Transition to a new state
func transition_to(new_state, msg = {}):
    if not is_initialized:
        push_error("StateMachine: Attempting to transition before initialization")
        return
        
    if not states.has(new_state.to_lower()):
        push_error("StateMachine: Trying to transition to non-existent state: " + new_state)
        return
        
    if current_state:
        current_state.exit()
        
    var prev_state = current_state.name if current_state else "none"
    current_state = states[new_state.to_lower()]
    current_state.enter(msg)
    
    emit_signal("transitioned", current_state.name)
    
    if OS.is_debug_build():
        print("StateMachine: Transitioned from ", prev_state, " to ", current_state.name)

# Returns the name of the current state
func get_current_state():
    return current_state.name if current_state else "none"
