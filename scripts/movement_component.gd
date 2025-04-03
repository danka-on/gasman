extends Node

var player = null  # Will reference the parent player node

# Movement variables
var gravity = 9.8
var jump_velocity = 7.0
var max_jumps = 2
var jumps_left = max_jumps
var was_in_air = false
var knockback_velocity : Vector3 = Vector3.ZERO
var knockback_duration : float = 0.0
var knockback_timer : float = 0.0

# Boost variables
var is_boosting : bool = false
var boost_thrust : float = 10.0
var boost_gas_rate : float = 30.0

# Gas variables
@export var max_gas : float = 300.0
var current_gas : float = max_gas
@export var gas_sprint_consumption_rate : float = 20.0
@export var gas_jump_consumption_rate : float = 30.0
@export var gas_sprint_speed : float = 30.0

# Sprint variables
var last_shift_press_time : float = 0.0
var double_tap_window : float = 0.3
var gas_sprint_enabled : bool = false
var was_shift_released : bool = true

# Jump variables
var last_jump_time : float = 0.0
var gas_jump_delay : float = 0.2

# Speed variables
@export var walk_speed : float = 5.0
@export var sprint_speed : float = 10.0
var input_dir : Vector3 = Vector3.ZERO

# Audio variables
@export var base_walk_pitch : float = 1.2
@export var sprint_pitch : float = 1.5
@export var footstep_delay : float = 0.3
@export var footstep_volume : float = 0.0
@export var regular_sprint_pitch : float = 1.4

# UI reference stored locally and accessed safely
var gas_bar = null

# Add debug flag for logging
var debug_movement = false

func _ready():
    current_gas = max_gas
    
    print("Movement Component: Ready called")
    
    # Initialize timer
    if player and not player.has_node("FootstepTimer"):
        var timer = Timer.new()
        timer.name = "FootstepTimer"
        timer.wait_time = footstep_delay
        timer.one_shot = true
        player.add_child(timer)
        timer.timeout.connect(_on_footstep_timer_timeout)
        print("Movement Component: Created footstep timer")
    else:
        print("Movement Component: Player reference missing or footstep timer already exists")
    
    # Update UI - safe reference acquisition
    update_gas_ui_reference()
    update_gas_ui()

func update_gas_ui_reference():
    # Only get reference if we don't have it yet
    if not gas_bar:
        gas_bar = get_node_or_null("/root/Main/HUD/GasBar")
        if gas_bar:
            gas_bar.max_value = max_gas
            print("Movement Component: Found gas bar UI")
        else:
            # Try again later if not found
            print("Movement Component: Gas bar not found, deferring")
            call_deferred("update_gas_ui_reference")

func update_gas_ui():
    # Safe update of UI
    if not gas_bar:
        update_gas_ui_reference()
    
    if gas_bar:
        gas_bar.value = current_gas

# Added method to receive signal from player
func add_gas(amount: float):
    current_gas += amount
    current_gas = clamp(current_gas, 0, max_gas)
    update_gas_ui()
    print("Movement Component: Added gas: ", amount, " current: ", current_gas)

func _input(event):
    if not is_instance_valid(player):
        if debug_movement:
            print("Movement Component: Player not valid in _input")
        return
        
    # Debug key for movement
    if event is InputEventKey and event.pressed:
        if debug_movement:
            print("Movement Component: Key pressed: ", event.keycode)
        
    # Double-tap Shift detection
    if event is InputEventKey and event.keycode == KEY_SHIFT:
        if event.pressed:
            # Only process a new press if Shift was released since the last one
            if was_shift_released:
                var current_time = Time.get_ticks_msec() / 1000.0
                # Check if this press is within the double-tap window of the last press
                if current_time - last_shift_press_time <= double_tap_window and last_shift_press_time > 0:
                    gas_sprint_enabled = true
                    print("Movement Component: Gas sprint enabled via double-tap")
                # Update the last press time and mark Shift as pressed
                last_shift_press_time = current_time
                was_shift_released = false
        else:  # Shift was released
            was_shift_released = true
            gas_sprint_enabled = false
            if debug_movement:
                print("Movement Component: Shift released")

func _physics_process(delta):
    if not is_instance_valid(player):
        if debug_movement:
            print("Movement Component: Player not valid in _physics_process")
        return
        
    if debug_movement:
        # Print key states occasionally
        if Engine.get_frames_drawn() % 30 == 0:  # Log every 30 frames to reduce spam
            print("Movement keys: W:", Input.is_key_pressed(KEY_W), 
                  " A:", Input.is_key_pressed(KEY_A),
                  " S:", Input.is_key_pressed(KEY_S),
                  " D:", Input.is_key_pressed(KEY_D))
    
    var sprinting = Input.is_key_pressed(KEY_SHIFT)
    var move_speed = walk_speed  # Default to walking speed
    input_dir = Vector3.ZERO
    
    # Boosting: double jump + holding Spacebar with delay
    var current_time = Time.get_ticks_msec() / 1000.0
    is_boosting = jumps_left == 0 and Input.is_action_pressed("ui_accept") and (current_gas > 0 || player.god_mode) and (current_time - last_jump_time > gas_jump_delay)
    
    # Gas-powered sprint: double-tap Shift + hold
    if gas_sprint_enabled and sprinting and (current_gas > 0 || player.god_mode):
        move_speed = gas_sprint_speed
        if debug_movement:
            print("Movement Component: Using gas sprint speed: ", move_speed)
        if not player.god_mode:
            current_gas -= gas_sprint_consumption_rate * delta
            current_gas = clamp(current_gas, 0, max_gas)
            update_gas_ui()
    # Regular sprint: single hold Shift
    elif sprinting:
        move_speed = sprint_speed  # No gas consumption
        if debug_movement:
            print("Movement Component: Using regular sprint speed: ", move_speed)
    
    # Handle boosting
    if is_boosting:
        player.velocity.y += boost_thrust * delta  # Boost when holding Spacebar after delay
        if not player.god_mode:
            current_gas -= gas_jump_consumption_rate * delta
            current_gas = clamp(current_gas, 0, max_gas)
            update_gas_ui()
    
    # Sound logic
    var sprint_sound = player.get_node_or_null("SprintSound")
    var footstep_player = player.get_node_or_null("FootstepPlayer")
    
    if (gas_sprint_enabled and sprinting and (current_gas > 0 || player.god_mode)) or is_boosting:
        if sprint_sound and not sprint_sound.playing:
            sprint_sound.play()
    elif sprinting and footstep_player and not footstep_player.playing and player.is_on_floor():
        footstep_player.pitch_scale = regular_sprint_pitch
        footstep_player.play()
    else:
        if sprint_sound and sprint_sound.playing and not (gas_sprint_enabled or is_boosting):
            sprint_sound.stop()
        if footstep_player and footstep_player.playing and not (sprinting or player.is_on_floor()):
            footstep_player.stop()
    
    # Apply gravity and handle jumps
    if not player.is_on_floor():
        player.velocity.y -= gravity * delta
        was_in_air = true
        if footstep_player and footstep_player.playing:
            footstep_player.stop()
    else:
        if was_in_air:
            var thud_player = player.get_node_or_null("ThudPlayer")
            if thud_player:
                thud_player.play()
            was_in_air = false
        jumps_left = max_jumps
    
    if Input.is_action_just_pressed("ui_accept") and jumps_left > 0:
        player.velocity.y = jump_velocity
        if debug_movement:
            print("Movement Component: Jumping, velocity.y set to ", jump_velocity)
        if jumps_left == max_jumps:
            var grunt_player = player.get_node_or_null("GruntPlayer")
            if grunt_player:
                grunt_player.play()
        else:
            var air_jump_player = player.get_node_or_null("AirJumpPlayer")
            if air_jump_player:
                air_jump_player.play()
        jumps_left -= 1
        last_jump_time = Time.get_ticks_msec() / 1000.0
    
    # Handle movement input
    if Input.is_key_pressed(KEY_A):
        input_dir.x = -1
    elif Input.is_key_pressed(KEY_D):
        input_dir.x = 1
        
    if Input.is_key_pressed(KEY_W):
        input_dir.z = -1
    elif Input.is_key_pressed(KEY_S):
        input_dir.z = 1
    
    if input_dir:
        input_dir = input_dir.normalized()
        var head = player.get_node_or_null("Head")
        if head:
            var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
            player.velocity.x = direction.x * move_speed
            player.velocity.z = direction.z * move_speed
            
            if debug_movement:
                print("Movement Component: Moving, velocity: ", player.velocity)
            
            var footstep_timer = player.get_node_or_null("FootstepTimer")
            if player.is_on_floor() and footstep_timer and footstep_timer.is_stopped() and footstep_player and not footstep_player.playing:
                footstep_player.volume_db = footstep_volume
                footstep_player.pitch_scale = regular_sprint_pitch if sprinting and not gas_sprint_enabled else base_walk_pitch
                footstep_player.play()
                footstep_timer.start()
    else:
        player.velocity.x = move_toward(player.velocity.x, 0, move_speed)
        player.velocity.z = move_toward(player.velocity.z, 0, move_speed)
        if footstep_player and footstep_player.playing:
            footstep_player.stop()
    
    # Handle knockback
    if knockback_timer > 0 and player.is_on_floor():
        player.velocity += knockback_velocity
        knockback_timer -= delta
        if knockback_timer <= 0:
            knockback_velocity = Vector3.ZERO

func _on_footstep_timer_timeout():
    if not is_instance_valid(player):
        return
        
    input_dir = Vector3.ZERO # Reset here
    if Input.is_key_pressed(KEY_A): input_dir.x = -1
    elif Input.is_key_pressed(KEY_D): input_dir.x = 1
    if Input.is_key_pressed(KEY_W): input_dir.z = -1
    elif Input.is_key_pressed(KEY_S): input_dir.z = 1
    
    var footstep_player = player.get_node_or_null("FootstepPlayer")
    var footstep_timer = player.get_node_or_null("FootstepTimer")
    
    if input_dir and player.is_on_floor() and footstep_player and not footstep_player.playing:
        footstep_player.volume_db = footstep_volume
        footstep_player.pitch_scale = sprint_pitch if Input.is_key_pressed(KEY_SHIFT) and current_gas > 0 else base_walk_pitch
        footstep_player.play()
        if footstep_timer:
            footstep_timer.start()

func apply_knockback(direction: Vector3, force: float):
    if player and player.is_on_floor(): # Only apply if grounded
        knockback_velocity = direction * force
        knockback_timer = 0.15 # 0.15s duration
