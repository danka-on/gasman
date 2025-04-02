# This file contains example state implementations for the player state machine
# Create individual script files for each state and place them as children of a StateMachine node

# STATE: Idle
extends State
class_name IdleState

func enter(_msg = {}):
    # Reset player velocity
    owner_node.velocity.x = 0
    owner_node.velocity.z = 0

func physics_update(delta):
    # Apply gravity
    if not owner_node.is_on_floor():
        owner_node.velocity.y -= owner_node.gravity * delta
    
    # Check for movement input to transition to walking
    var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if input_dir != Vector2.ZERO:
        state_machine.transition_to("Walk")
    
    # Check for jump input
    if Input.is_action_just_pressed("ui_accept") and owner_node.is_on_floor():
        state_machine.transition_to("Jump")
    
    # Apply movement
    owner_node.move_and_slide()

func handle_input(event):
    # Check for sprint input
    if event.is_action_pressed("sprint"):
        state_machine.transition_to("Sprint")

#----------------------------------------------------------------------------#

# STATE: Walk
extends State
class_name WalkState

var input_dir = Vector2.ZERO

func enter(_msg = {}):
    # Get walk animation if you have one
    pass

func physics_update(delta):
    # Get input direction
    input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    
    # Check if we should go back to idle
    if input_dir == Vector2.ZERO:
        state_machine.transition_to("Idle")
        return
    
    # Apply gravity
    if not owner_node.is_on_floor():
        owner_node.velocity.y -= owner_node.gravity * delta
    
    # Convert input to 3D movement vector
    var movement_dir = (owner_node.get_node("Head").transform.basis * 
        Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    # Apply walking movement
    owner_node.velocity.x = movement_dir.x * owner_node.walk_speed
    owner_node.velocity.z = movement_dir.z * owner_node.walk_speed
    
    # Play footstep sounds
    if owner_node.is_on_floor() and owner_node.get_node("FootstepTimer").is_stopped():
        owner_node.get_node("FootstepPlayer").pitch_scale = owner_node.base_walk_pitch
        owner_node.get_node("FootstepPlayer").play()
        owner_node.get_node("FootstepTimer").start()
    
    # Check for jump input
    if Input.is_action_just_pressed("ui_accept") and owner_node.is_on_floor():
        state_machine.transition_to("Jump")
    
    # Apply movement
    owner_node.move_and_slide()

func handle_input(event):
    # Check for sprint input
    if event.is_action_pressed("sprint"):
        state_machine.transition_to("Sprint")

#----------------------------------------------------------------------------#

# STATE: Sprint
extends State
class_name SprintState

var input_dir = Vector2.ZERO
var gas_sprint = false  # Whether using gas-powered sprint

func enter(msg = {}):
    # Get sprint parameters
    gas_sprint = msg.get("gas_sprint", false)

func physics_update(delta):
    # Get input direction
    input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    
    # Check if we should go back to walk/idle
    if input_dir == Vector2.ZERO:
        state_machine.transition_to("Idle")
        return
    
    if not Input.is_action_pressed("sprint"):
        state_machine.transition_to("Walk")
        return
    
    # Apply gravity
    if not owner_node.is_on_floor():
        owner_node.velocity.y -= owner_node.gravity * delta
    
    # Convert input to 3D movement vector
    var movement_dir = (owner_node.get_node("Head").transform.basis * 
        Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    # Apply sprint movement
    var speed = owner_node.gas_sprint_speed if gas_sprint else owner_node.sprint_speed
    owner_node.velocity.x = movement_dir.x * speed
    owner_node.velocity.z = movement_dir.z * speed
    
            # Consume gas if using gas sprint
    if gas_sprint and not owner_node.god_mode:
        owner_node.current_gas -= owner_node.gas_sprint_consumption_rate * delta
        owner_node.current_gas = clamp(owner_node.current_gas, 0, owner_node.max_gas)
        
        # Update gas UI
        var gas_bar = get_node_or_null("/root/Main/HUD/GasBar")
        if gas_bar:
            gas_bar.value = owner_node.current_gas
        
        # Check if we've run out of gas
        if owner_node.current_gas <= 0:
            state_machine.transition_to("Sprint", {"gas_sprint": false})
    
    # Play appropriate sounds
    if gas_sprint:
        if not owner_node.get_node("SprintSound").playing:
            owner_node.get_node("SprintSound").play()
    else:
        if not owner_node.get_node("FootstepPlayer").playing:
            owner_node.get_node("FootstepPlayer").pitch_scale = owner_node.regular_sprint_pitch
            owner_node.get_node("FootstepPlayer").play()
    
    # Check for jump input
    if Input.is_action_just_pressed("ui_accept") and owner_node.is_on_floor():
        state_machine.transition_to("Jump")
    
    # Apply movement
    owner_node.move_and_slide()

func exit():
    # Stop appropriate sounds
    if gas_sprint and owner_node.get_node("SprintSound").playing:
        owner_node.get_node("SprintSound").stop()

func handle_input(event):
    # Check for double-tap sprint (gas sprint)
    if event is InputEventKey and event.keycode == KEY_SHIFT:
        if event.pressed and owner_node.was_shift_released:
            var current_time = Time.get_ticks_msec() / 1000.0
            if current_time - owner_node.last_shift_press_time <= owner_node.double_tap_window:
                state_machine.transition_to("Sprint", {"gas_sprint": true})
            owner_node.last_shift_press_time = current_time
            owner_node.was_shift_released = false
        else:
            owner_node.was_shift_released = true

#----------------------------------------------------------------------------#

# STATE: Jump
extends State
class_name JumpState

var velocity_before_jump = Vector3.ZERO

func enter(_msg = {}):
    # Store horizontal velocity
    velocity_before_jump = Vector3(owner_node.velocity.x, 0, owner_node.velocity.z)
    
    # Apply jump force
    owner_node.velocity.y = owner_node.jump_velocity
    
    # Play jump sound
    if owner_node.jumps_left == owner_node.max_jumps:
        owner_node.get_node("GruntPlayer").play()
    else:
        owner_node.get_node("AirJumpPlayer").play()
    
    # Decrement jump counter
    owner_node.jumps_left -= 1
    
    # Record jump time for gas boost
    owner_node.last_jump_time = Time.get_ticks_msec() / 1000.0

func physics_update(delta):
    # Apply gravity
    owner_node.velocity.y -= owner_node.gravity * delta
    
    # Get input direction for horizontal movement
    var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    
    if input_dir != Vector2.ZERO:
        # Convert input to 3D movement vector
        var movement_dir = (owner_node.get_node("Head").transform.basis * 
            Vector3(input_dir.x, 0, input_dir.y)).normalized()
        
        # Apply horizontal movement
        owner_node.velocity.x = movement_dir.x * owner_node.walk_speed
        owner_node.velocity.z = movement_dir.z * owner_node.walk_speed
    else:
        # Maintain horizontal velocity
        owner_node.velocity.x = velocity_before_jump.x
        owner_node.velocity.z = velocity_before_jump.z
    
    # Check for double jump
    if Input.is_action_just_pressed("ui_accept") and owner_node.jumps_left > 0:
        state_machine.transition_to("Jump")
        return
    
    # Check for boost activation (double jump + holding space after delay)
    var current_time = Time.get_ticks_msec() / 1000.0
    if owner_node.jumps_left == 0 and Input.is_action_pressed("ui_accept") and 
      (owner_node.current_gas > 0 || owner_node.god_mode) and 
      (current_time - owner_node.last_jump_time > owner_node.gas_jump_delay):
        state_machine.transition_to("Boost")
        return
    
    # Check for landing
    if owner_node.is_on_floor():
        owner_node.get_node("ThudPlayer").play()
        owner_node.jumps_left = owner_node.max_jumps
        
        if Input.is_action_pressed("sprint"):
            state_machine.transition_to("Sprint")
        elif input_dir != Vector2.ZERO:
            state_machine.transition_to("Walk")
        else:
            state_machine.transition_to("Idle")
    
    # Apply movement
    owner_node.move_and_slide()

#----------------------------------------------------------------------------#

# STATE: Boost
extends State
class_name BoostState

func enter(_msg = {}):
    # Start boost sound
    if not owner_node.get_node("SprintSound").playing:
        owner_node.get_node("SprintSound").play()

func physics_update(delta):
    # Apply boost thrust
    owner_node.velocity.y += owner_node.boost_thrust * delta
    
    # Consume gas
    if not owner_node.god_mode:
        owner_node.current_gas -= owner_node.gas_jump_consumption_rate * delta
        owner_node.current_gas = clamp(owner_node.current_gas, 0, owner_node.max_gas)
        
        # Update gas UI
        var gas_bar = get_node_or_null("/root/Main/HUD/GasBar")
        if gas_bar:
            gas_bar.value = owner_node.current_gas
    
    # Get input direction for horizontal movement
    var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    
    if input_dir != Vector2.ZERO:
        # Convert input to 3D movement vector
        var movement_dir = (owner_node.get_node("Head").transform.basis * 
            Vector3(input_dir.x, 0, input_dir.y)).normalized()
        
        # Apply horizontal movement
        owner_node.velocity.x = movement_dir.x * owner_node.walk_speed
        owner_node.velocity.z = movement_dir.z * owner_node.walk_speed
    
    # Check if we should exit boost (space released or out of gas)
    if not Input.is_action_pressed("ui_accept") or 
       (owner_node.current_gas <= 0 and not owner_node.god_mode):
        state_machine.transition_to("Jump")
    
    # Check for landing
    if owner_node.is_on_floor():
        owner_node.get_node("ThudPlayer").play()
        owner_node.jumps_left = owner_node.max_jumps
        
        if Input.is_action_pressed("sprint"):
            state_machine.transition_to("Sprint")
        elif input_dir != Vector2.ZERO:
            state_machine.transition_to("Walk")
        else:
            state_machine.transition_to("Idle")
    
    # Apply movement
    owner_node.move_and_slide()

func exit():
    # Stop boost sound
    if owner_node.get_node("SprintSound").playing:
        owner_node.get_node("SprintSound").stop()
