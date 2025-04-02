extends Node
class_name State

# Reference to the state machine this state belongs to
var state_machine = null

# Reference to the node that the state machine controls
var owner_node = null

# Virtual function called when entering this state
func enter(msg = {}):
    pass

# Virtual function called when exiting this state
func exit():
    pass

# Virtual function called during _process
func update(delta):
    pass

# Virtual function called during _physics_process
func physics_update(delta):
    pass

# Virtual function to handle input
func handle_input(event):
    pass
