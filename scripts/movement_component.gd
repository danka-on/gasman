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

func _ready():
    current_gas = max_gas
    
    # Initialize timer
    if player and not player.has_node("FootstepTimer"):
        var timer = Timer.new()
        timer.name = "FootstepTimer"
        timer.wait_time = footstep_delay
        timer.one_shot = true
        player.add_child(timer)
        timer.timeout.connect(_on_footstep_timer_timeout)
    
    # Update UI
    var gas_bar = get_node_or_null("/root/Main/HUD/GasBar")
    if gas_bar:
        gas_bar.max_value = max_gas
        gas_bar.value = current_gas
    else:
        print("Error: GasBar not found!")

func _input(event):
    # Double-tap Shift detection
    if event is InputEventKey and event.keycode == KEY_SHIFT:
        if event.pressed:
            # Only process a new press if Shift was released since the last one
            if was_shift_released:
                var current_time = Time.get_ticks_msec() / 1000.0
                # Check if this press is within the double-tap window of the last press
                if current_time - last_shift_press_time <= double_tap_window and last_shift_press_time > 0:
                    gas_sprint_enabled = true
                    print("Gas sprint enabled via double-tap!")
                # Update the last press time and mark Shift as pressed
                last_shift_press_time = current_time
                was_shift_released = false
        else:  # Shift was released
            was_shift_released = true
            gas_sprint_enabled = false
            print("Shift released - gas sprint disabled")

func _physics_process(delta):
    if not player:
        return
        
    var sprinting = Input.is_key_pressed(KEY_SHIFT)
    var move_speed = walk_speed  # Default to walking speed
    input_dir = Vector3.ZERO
    
    # Boosting: double jump + holding Spacebar with delay
    var current_time = Time.get_ticks_msec() / 1000.0
    is_boosting = jumps_left == 0 and Input.is_action_pressed("ui_accept") and (current_gas > 0 || player.god_mode) and (current_time - last_jump_time > gas_jump_delay)
    
    # Gas-powered sprint: double-tap Shift + hold
    if gas_sprint_enabled and sprinting and (current_gas > 0 || player.god_mode):
        move_speed = gas_sprint_speed
        if not player.god_mode:
            current_gas -= gas_sprint_consumption_rate * delta
            current_gas = clamp(current_gas, 0, max_gas)
            update_gas_ui()
    # Regular sprint: single hold Shift
    elif sprinting:
        move_speed = sprint_speed  # No gas consumption
    
    # Handle boosting
    if is_boosting:
        player.velocity.y += boost_thrust * delta  # Boost when holding Spacebar after delay
        if not player.god_mode:
            current_gas -= gas_jump_consumption_rate * delta
            current_gas = clamp(current_gas, 0, max_gas)
            update_gas_ui()
    
    # Sound logic
    if (gas_sprint_enabled and sprinting and (current_gas > 0 || player.god_mode)) or is_boosting:
        if not player.get_node_or_null("SprintSound").playing:
            player.get_node_or_null("SprintSound").play()
    elif sprinting and not player.get_node_or_null("FootstepPlayer").playing:
        player.get_node_or_null("FootstepPlayer").pitch_scale = regular_sprint_pitch
        player.get_node_or_null("FootstepPlayer").play()
    else:
        if player.get_node_or_null("SprintSound").playing and not (gas_sprint_enabled or is_boosting):
            player.get_node_or_null("SprintSound").stop()
        if player.get_node_or_null("FootstepPlayer").playing and not (sprinting or player.is_on_floor()):
            player.get_node_or_null("FootstepPlayer").play()
            player.get_node_or_null("FootstepTimer").start()
    else:
        player.velocity.x = move_toward(player.velocity.x, 0, move_speed)
        player.velocity.z = move_toward(player.velocity.z, 0, move_speed)
        if player.get_node_or_null("FootstepPlayer").playing:
            player.get_node_or_null("FootstepPlayer").stop()
    
    # Handle knockback
    if knockback_timer > 0 and player.is_on_floor():
        player.velocity += knockback_velocity
        knockback_timer -= delta
        if knockback_timer <= 0:
            knockback_velocity = Vector3.ZERO

func _on_footstep_timer_timeout():
    if not player:
        return
        
    input_dir = Vector3.ZERO # Reset here
    if Input.is_key_pressed(KEY_A): input_dir.x = -1
    elif Input.is_key_pressed(KEY_D): input_dir.x = 1
    if Input.is_key_pressed(KEY_W): input_dir.z = -1
    elif Input.is_key_pressed(KEY_S): input_dir.z = 1
    
    if input_dir and player.is_on_floor() and not player.get_node_or_null("FootstepPlayer").playing:
        player.get_node_or_null("FootstepPlayer").volume_db = footstep_volume
        player.get_node_or_null("FootstepPlayer").pitch_scale = sprint_pitch if Input.is_key_pressed(KEY_SHIFT) and current_gas > 0 else base_walk_pitch
        player.get_node_or_null("FootstepPlayer").play()
        player.get_node_or_null("FootstepTimer").start()

func apply_knockback(direction: Vector3, force: float):
    if player.is_on_floor(): # Only apply if grounded
        knockback_velocity = direction * force
        knockback_timer = 0.15 # 0.15s duration

func add_gas(amount: float):
    current_gas += amount
    current_gas = clamp(current_gas, 0, max_gas)
    update_gas_ui()
    
func update_gas_ui():
    var gas_bar = get_node_or_null("/root/Main/HUD/GasBar")
    if gas_bar:
        gas_bar.value = current_gasstop()
    
    # Apply gravity and handle jumps
    if not player.is_on_floor():
        player.velocity.y -= gravity * delta
        was_in_air = true
        if player.get_node_or_null("FootstepPlayer").playing:
            player.get_node_or_null("FootstepPlayer").stop()
    else:
        if was_in_air:
            player.get_node_or_null("ThudPlayer").play()
            was_in_air = false
        jumps_left = max_jumps
    
    if Input.is_action_just_pressed("ui_accept") and jumps_left > 0:
        player.velocity.y = jump_velocity
        if jumps_left == max_jumps:
            player.get_node_or_null("GruntPlayer").play()
        else:
            player.get_node_or_null("AirJumpPlayer").play()
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
        var direction = (player.get_node("Head").transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
        player.velocity.x = direction.x * move_speed
        player.velocity.z = direction.z * move_speed
        
        if player.is_on_floor() and player.get_node_or_null("FootstepTimer").is_stopped() and not player.get_node_or_null("FootstepPlayer").playing:
            player.get_node_or_null("FootstepPlayer").volume_db = footstep_volume
            player.get_node_or_null("FootstepPlayer").pitch_scale = regular_sprint_pitch if sprinting and not gas_sprint_enabled else base_walk_pitch
            player.get_node_or_null("FootstepPlayer").
