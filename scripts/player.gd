extends CharacterBody3D

# Movement variables

@export var god_mode : bool = false # God Mode toggle in Inspector
@export var gas_sprint_w_multiplier : float = 1.5 # Speed multiplier when holding W during gas sprint
@export var debug_mode: bool = false
@export var sword_immune_timer = 0.5
var immunity = false


var gravity = 9.8
var mouse_sensitivity = 0.002
var jump_velocity = 7.0
var max_jumps = 2
var jumps_left = max_jumps
var was_in_air = false
var knockback_velocity : Vector3 = Vector3.ZERO
var knockback_duration : float = 0.0 # Time left for knockback
var knockback_timer : float = 0.0 #

# Momentum system variables
var acceleration = 70.0        # Will be calculated based on ramp time
var friction = 15.0            # Base friction factor when stopping
var air_control = 0.3          # Multiplier for reduced control while airborne (0-1)
var sprint_acceleration = 50.0 # Will be calculated based on ramp time
var gas_sprint_acceleration = 120.0 # Will be calculated based on ramp time



# Speed ramp-up times (seconds to reach max speed)
var walk_ramp_time = 0.001
var sprint_ramp_time = 0.001
var gas_sprint_ramp_time = 0.2


var is_boosting : bool = false # Track boost state
var boost_thrust : float = 10.0 # Upward force per second
var boost_gas_rate : float = 30.0 # Gas drain per second for boost

# New export variables for gas consumption
@export var gas_sprint_consumption_rate : float = 20.0  # Gas per second for gas sprint
@export var gas_sprint_w_consumption_rate : float = 25.0  # Gas per second for gas sprint with W
@export var gas_sprint_s_consumption_rate : float = 15.0  # Gas per second for gas sprint with S
@export var gas_jump_consumption_rate : float = 30.0   # Gas per second for gas jump

@export var gas_sprint_speed : float = 30  # Faster speed for gas-powered sprint
var last_shift_press_time : float = 0.0      # Time of the last Shift press
var double_tap_window : float = 0.3          # Time window for double-tap (in seconds)
var gas_sprint_enabled : bool = false        # Flag for gas-powered sprint
var was_shift_released : bool = true

var last_jump_time : float = 0.0      # Time of the last jump
var gas_jump_delay : float = 0.2

@export var walk_speed : float = 5.0
@export var sprint_speed : float = 10.0
@onready var gas_bar = $HUD/HealthBarContainer/GasBar
var max_gas : float = 300.0
var current_gas : float = max_gas
var gas_consumption_rate : float = 20.0 # Gas per second while sprinting
var input_dir : Vector3 = Vector3.ZERO # Added declaration

var target_velocity : Vector3 = Vector3.ZERO
@onready var sprint_sound = $SprintSound


# Shooting variables
var bullet_scene = preload("res://scenes/bullet.tscn")
var can_shoot = true
var shoot_cooldown = 0.2
var muzzle_flash_duration = 0.1
@export var bullet_speed : float = 20.0
@export var max_magazine : int = 30
var current_magazine : int = max_magazine
@export var total_reserve_ammo : int = 90
var current_reserve : int = total_reserve_ammo
var can_reload = true
@export var reload_time : float = 2.0
@onready var reload_bar = $HUD/HealthBarContainer/ReloadBar
var is_reloading : bool = false
var reload_progress : float = 0.0



# Audio variables
@export var base_walk_pitch : float = 1.2
@export var sprint_pitch : float = 1.5
@export var footstep_delay : float = 0.3
@export var footstep_volume : float = 0.0
@export var regular_sprint_pitch : float = 1.4  # Adjustable in Inspector for regular sprint
@export var gas_friction : float = 0.5

@onready var ammo_sound = $AmmoSound
@onready var heal_sound = $HealSound

# Health variables
@export var max_health : float = 100.0
var current_health : float = max_health

# Timer variables
var game_time: float = 0.0
var is_game_active: bool = true

# Fall damage variables
@export var fall_damage_threshold : float = 15.0  # Minimum velocity to take fall damage
@export var fall_damage_multiplier : float = 0.5  # Damage multiplier based on fall velocity
var last_vertical_velocity : float = 0.0  # Track vertical velocity for fall damage

# Score and kills
var score : int = 0
var kills : int = 0

# UI references
@onready var health_bar = $HUD/HealthBarContainer/HealthBar
@onready var ammo_label = $HUD/HealthBarContainer/AmmoLabel
@onready var crosshair = $HUD/Crosshair
@onready var heal_border = $HUD/HealBorder


@onready var pickup_area = $PickupArea
@onready var hit_sound = $HitSound
@onready var damage_sound = $DamageSound





# Gas cloud variables
@export_group("Gas Cloud")
@export var gas_cloud_spawn_interval_sprint: float = 0.5  # Interval for gas sprint clouds
@export var gas_cloud_spawn_interval_w: float = 0.3  # Interval for gas sprint clouds with W
@export var gas_cloud_spawn_interval_s: float = 0.7  # Interval for gas sprint clouds with S
@export var gas_cloud_spawn_interval_jump: float = 0.3    # Interval for gas jump clouds (faster due to higher velocity)
@export var gas_cloud_offset: Vector3 = Vector3(0, 0.5, 0)
@export var gas_cloud_damage: float = 5.0
@export var gas_cloud_damage_interval: float = 0.5
@export var gas_cloud_lifetime: float = 3.0
@export var max_gas_clouds: int = 30  # Maximum number of gas clouds allowed at once
var gas_cloud_timer: float = 0.0

@export var gas_cloud_particle_amount: int = 50
@export var gas_cloud_particle_scale_min: float = 2.0
@export var gas_cloud_particle_scale_max: float = 3.0
@export var gas_cloud_color: Color = Color(0.0, 0.8, 0.0, 0.3)
@export var gas_cloud_emission_strength: float = 0.5

#gasboost variables

var was_gas_sprinting: bool = false
var was_gas_boosting: bool = false

#movement statemachine variables

var current_movement_state = MovementState.IDLE
var previous_movement_state = MovementState.IDLE

#sword style variables

@onready var sword = $Head/Camera3D/Sword

@onready var pause_menu = preload("res://scenes/pause_menu.tscn").instantiate()



# Initialize gas cloud scene with poolable version
var gas_cloud_scene = preload("res://scenes/PoolableGasCloud.tscn")
var _gas_cloud_initialized = false

func _ready():
   
    
    DebugSettings.debug_print("player", "Player initialization started")
    
    # Initialize physics variables
    initialize_physics_variables()
    
    # Setup collision layers
    setup_collision_layers()
    
    # Initialize UI components
    initialize_ui_components()
    
    # Initialize audio components
    initialize_audio()
    
    # Apply god mode if enabled
    apply_god_mode_if_enabled()
    
    # Initialize crosshair
    var crosshair_scene = preload("res://scenes/crosshair.tscn")
    crosshair = crosshair_scene.instantiate()
    $HUD.add_child(crosshair)
    
    # Add pause menu
    add_child(pause_menu)
    
    # Initialize gas cloud scene with fallback only if necessary
    if !_gas_cloud_initialized:
        if Engine.has_singleton("PoolSystem") and PoolSystem.has_pool("gas_clouds"):
            DebugSettings.debug_print("player", "Using gas clouds from PoolSystem")
            _gas_cloud_initialized = true
        else:
            var file = FileAccess.file_exists("res://scenes/PoolableGasCloud.tscn")
            if !file:
                DebugSettings.debug_print("player", "Poolable gas cloud scene not found, falling back to regular gas cloud", DebugSettings.LogLevel.WARNING)
                gas_cloud_scene = preload("res://scenes/gas_cloud.tscn")
            _gas_cloud_initialized = true
    
    DebugSettings.debug_print("player", "Player initialization complete")


func _physics_process(delta):
    # Update game timer if game is active
    if is_game_active:
        game_time += delta
        update_timer_display()
    
    if sword.can_swing:
        immunity = false
    elif !sword.can_swing:
        immunity = true
    
       
    


    
    # Get input state
    var sprinting = Input.is_key_pressed(KEY_SHIFT)
    var move_speed = walk_speed  # Default to walking speed
    input_dir = Vector3.ZERO
    
    # Gather input
    gather_input()
    
    # Boosting: double jump + holding Spacebar with delay
    var current_time = Time.get_ticks_msec() / 1000.0
    var old_boosting = is_boosting
    var has_gas = current_gas > 0 || god_mode
    var after_delay = current_time - last_jump_time > gas_jump_delay
    var holding_space = Input.is_action_pressed("ui_accept")
    var double_jumped = jumps_left == 0
    
    # Gas-powered sprint: double-tap Shift + hold
    var is_gas_sprinting = gas_sprint_enabled and sprinting and (current_gas > 0 || god_mode)
    
    # Determine current movement speed based on state
    if is_gas_sprinting:
        move_speed = gas_sprint_speed
        if !was_gas_sprinting:  # Only print when state changes
            DebugSettings.debug_print("player", "Gas sprint active - Speed: %s" % str(gas_sprint_speed))
    elif sprinting:
        move_speed = sprint_speed
    
    # Handle boosting logic
    is_boosting = double_jumped and holding_space and has_gas and after_delay and is_on_air()
    
    # Update movement state using the state machine
    update_movement_state(
        is_on_floor(),
        is_gas_sprinting,
        is_boosting,
        sprinting and !is_gas_sprinting,
        input_dir != Vector3.ZERO
    )
    
    # Apply appropriate physics based on movement state
    apply_movement_physics(delta, move_speed, is_gas_sprinting)
    
    # Handle gas consumption
    handle_gas_consumption(delta, is_gas_sprinting, is_boosting)
    
    # Handle gas cloud spawning
    handle_gas_cloud_spawning(delta, is_gas_sprinting, is_boosting)
    
    # Handle sounds based on current state
    handle_movement_sounds()
    
    # Handle jumping input
    handle_jumping(delta)
    
    # Handle shooting input
    handle_shooting()
    
    # Handle reloading
    handle_reloading(delta)
    
    # Track vertical velocity for fall damage
    if !is_on_floor():
        last_vertical_velocity = velocity.y
    elif last_vertical_velocity < -fall_damage_threshold:
        # Calculate and apply fall damage
        var fall_damage = abs(last_vertical_velocity) * fall_damage_multiplier
        if !god_mode:
            take_damage(fall_damage)
            # Play damage sound for fall damage
            if damage_sound:
                damage_sound.play()
            # Show damage indicator
            if heal_border:
                heal_border.modulate = Color(1, 0, 0, 0.5)  # Red flash
                var tween = create_tween()
                tween.tween_property(heal_border, "modulate", Color(1, 1, 1, 0), 0.3)
    
    # Reset vertical velocity tracking
    if is_on_floor():
        last_vertical_velocity = 0.0
    
    # Apply final movement
    move_and_slide()
    
    # Update tracking variables after checking current state
    was_gas_sprinting = is_gas_sprinting
    was_gas_boosting = is_boosting

    #sword attacks
  
  
    if Input.is_action_pressed('right_click'):
        sword.sword_swing()
        


    


# Add these helper functions to simplify the momentum physics code

# Calculate how much the direction is changing (returns a value from -1 to 1)
func calculate_direction_change(current_dir, target_dir):
    if current_dir.length() > 0.1 and target_dir.length() > 0.1:
        return current_dir.dot(target_dir)
    return 1.0  # Default to no change if either direction is too small

# Calculate acceleration modifier based on direction change
func get_turn_acceleration_modifier(direction_difference):
    if direction_difference < 0:
        return 0.7  # Reduce acceleration when turning more than 90 degrees
    elif direction_difference < 0.5:
        return 0.85  # Slight reduction for turns between 60-90 degrees
    return 1.0  # No reduction for minor direction changes

# Apply momentum-based movement with direction consideration
func apply_gas_movement(direction, move_speed, current_acceleration, delta, input_dir_z):
    var current_direction = Vector2(velocity.x, velocity.z).normalized()
    var target_direction = Vector2(direction.x, direction.z).normalized()
    var current_speed = Vector2(velocity.x, velocity.z).length()
    
    # Calculate how much we're changing direction
    var direction_difference = calculate_direction_change(current_direction, target_direction)
    
    # Modify acceleration based on turning
    current_acceleration *= get_turn_acceleration_modifier(direction_difference)
    
    # Handle different input cases with momentum preservation
    if direction_difference > 0.7 and current_speed > move_speed * 0.8:
        if input_dir_z < 0:  # W key - maintain momentum instead of slowing down
            # Only accelerate if we're below top speed
            if current_speed < move_speed:
                velocity.x = move_toward(velocity.x, direction.x * move_speed, current_acceleration * delta)
                velocity.z = move_toward(velocity.z, direction.z * move_speed, current_acceleration * delta)
        elif input_dir_z > 0:  # S key - apply gentle braking, don't cancel momentum completely
            # Calculate a braking force that's proportional to speed but doesn't kill momentum
            var braking_strength = min(current_acceleration * 0.6, current_speed * 0.8) * delta
            velocity.x = move_toward(velocity.x, 0, braking_strength)
            velocity.z = move_toward(velocity.z, 0, braking_strength)
        else:  # Other keys - use normal acceleration with momentum preservation
            velocity.x = move_toward(velocity.x, direction.x * move_speed, current_acceleration * delta)
            velocity.z = move_toward(velocity.z, direction.z * move_speed, current_acceleration * delta)
    else:  # Normal acceleration for other cases
        velocity.x = move_toward(velocity.x, direction.x * move_speed, current_acceleration * delta)
        velocity.z = move_toward(velocity.z, direction.z * move_speed, current_acceleration * delta)

# Helper functions for movement
func is_on_air() -> bool:
    return !is_on_floor()


# Define movement states as enum for clearer state management
enum MovementState {
    IDLE,
    WALKING,
    SPRINTING,
    GAS_SPRINTING,
    BOOSTING,
    AIR_CONTROL
}



# Update movement state based on current conditions
func update_movement_state(is_on_ground: bool, is_gas_sprint: bool, is_boost: bool, is_sprint: bool, has_input: bool):
    previous_movement_state = current_movement_state
    
    if !is_on_ground:
        current_movement_state = MovementState.AIR_CONTROL
    elif is_boost:
        current_movement_state = MovementState.BOOSTING
    elif is_gas_sprint:
        current_movement_state = MovementState.GAS_SPRINTING
    elif is_sprint:
        current_movement_state = MovementState.SPRINTING
    elif has_input:
        current_movement_state = MovementState.WALKING
    else:
        current_movement_state = MovementState.IDLE
    
    # Log state transitions for debugging
    if current_movement_state != previous_movement_state:
         # Handle state transition effects
        handle_state_transition(previous_movement_state, current_movement_state)
        
        if debug_mode:
            DebugSettings.debug_print("player", "Movement state changed")
        
        

# Convert movement state to string for debugging
func movement_state_to_string(state):
    match state:
        MovementState.IDLE: return "IDLE"
        MovementState.WALKING: return "WALKING"
        MovementState.SPRINTING: return "SPRINTING"
        MovementState.GAS_SPRINTING: return "GAS_SPRINTING"
        MovementState.BOOSTING: return "BOOSTING"
        MovementState.AIR_CONTROL: return "AIR_CONTROL"
        _: return "UNKNOWN"

# Handle effects that should happen on state transitions
func handle_state_transition(from_state, to_state):
    # Start appropriate effects based on new state
    match to_state:
        MovementState.GAS_SPRINTING:
            if sprint_sound and !sprint_sound.playing:
                sprint_sound.play()
        MovementState.IDLE:
            stop_movement_sounds()
        MovementState.AIR_CONTROL:
            if $FootstepPlayer.playing:
                $FootstepPlayer.stop()



func initialize_physics_variables():
    # Calculate acceleration values based on desired ramp-up times
    # Add safety checks to prevent division by zero
    if walk_ramp_time > 0:
        acceleration = walk_speed / walk_ramp_time
    else:
        acceleration = 16.7 # Fallback value (5.0/0.3)
        
    if sprint_ramp_time > 0:
        sprint_acceleration = sprint_speed / sprint_ramp_time
    else:
        sprint_acceleration = 25.0 # Fallback value (10.0/0.4)
        
    if gas_sprint_ramp_time > 0:
        gas_sprint_acceleration = gas_sprint_speed / gas_sprint_ramp_time
    else:
        gas_sprint_acceleration = 150.0 # Fallback value (30.0/0.2)
        
    DebugSettings.debug_print("player", "Calculated acceleration values:")
    DebugSettings.debug_print("player", "- Walk acceleration: %s" % str(acceleration))
    DebugSettings.debug_print("player", "- Sprint acceleration: %s" % str(sprint_acceleration))
    DebugSettings.debug_print("player", "- Gas sprint acceleration: %s" % str(gas_sprint_acceleration))
    
    # Reset state tracking variables
    was_in_air = false
    was_gas_sprinting = false
    was_gas_boosting = false
    jumps_left = max_jumps
    
    # Initialize gameplay state
    can_shoot = true
    is_reloading = false
    reload_progress = 0.0
    current_health = max_health
    current_gas = max_gas
    current_magazine = max_magazine
    current_reserve = total_reserve_ammo
    
    # Initialize input tracking
    was_shift_released = true
    gas_sprint_enabled = false

func setup_collision_layers():
    collision_layer = 1
    collision_mask = 1 | 8 | 16
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func initialize_ui_components():
    # Verify and initialize UI components with error handling
    if health_bar:
        health_bar.max_value = max_health
        health_bar.value = current_health
    else:
        push_error("Health bar not found!")
        
    if gas_bar:
        gas_bar.max_value = max_gas
        gas_bar.value = current_gas
        DebugSettings.debug_print("player", "GasBar initialized with max value: %s and current value: %s" % [str(max_gas), str(current_gas)])
    else:
        push_error("GasBar not found!")
        
    if reload_bar:
        reload_bar.value = 0.0
        reload_bar.hide()  # Ensure hidden at start
    else:
        push_error("Reload bar not found!")
    
    update_ammo_display()

func initialize_audio():
    if not $FootstepTimer:
        push_error("FootstepTimer missing!")
    else:
        $FootstepTimer.wait_time = footstep_delay
        
    if $FootstepPlayer:
        $FootstepPlayer.volume_db = footstep_volume
    else:
        push_error("FootstepPlayer missing!")
        
    # Initialize other audio players if needed

func apply_god_mode_if_enabled():
    if god_mode:
        current_health = max_health
        current_gas = max_gas
        current_magazine = max_magazine
        current_reserve = total_reserve_ammo
        DebugSettings.debug_print("player", "God mode enabled")
        
func initialize_pickups():
    if pickup_area:
        if not pickup_area.is_connected("body_entered", _on_pickup_area_body_entered):
            pickup_area.connect("body_entered", _on_pickup_area_body_entered)
    else:
        push_error("PickupArea missing!")

func _input(event):
    
    
    if event is InputEventMouseMotion:
        $Head.rotate_y(-event.relative.x * mouse_sensitivity)
        $Head/Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
        $Head/Camera3D.rotation.x = clamp($Head/Camera3D.rotation.x, -1.5, 1.5)
    
    if event is InputEventKey and event.pressed and event.keycode == KEY_H:
        take_damage(10.0)
    
    if event.is_action_pressed("reload") and can_reload:
        reload()
    
    # Double-tap Shift detection
    if event is InputEventKey and event.keycode == KEY_SHIFT:
        if event.pressed:
            # Only process a new press if Shift was released since the last one
            if was_shift_released:
                var current_time = Time.get_ticks_msec() / 1000.0  # Current time in seconds
                # Check if this press is within the double-tap window of the last press
                if current_time - last_shift_press_time <= double_tap_window and last_shift_press_time > 0:
                    gas_sprint_enabled = true
                    DebugSettings.debug_print("player", "Gas sprint enabled via double-tap!")
                # Update the last press time and mark Shift as pressed
                last_shift_press_time = current_time
                was_shift_released = false
        else:  # Shift was released
            was_shift_released = true
            gas_sprint_enabled = false
            DebugSettings.debug_print("player", "Shift released - gas sprint disabled")
        
    

# Helper function to gather player input
func gather_input():
    if Input.is_key_pressed(KEY_A):
        input_dir.x = -1
    elif Input.is_key_pressed(KEY_D):
        input_dir.x = 1
    if Input.is_key_pressed(KEY_W):
        input_dir.z = -1
    elif Input.is_key_pressed(KEY_S):
        input_dir.z = 1
    
    # Only set automatic forward movement if we have gas or are in god mode
    if gas_sprint_enabled and Input.is_key_pressed(KEY_SHIFT) and (current_gas > 0 || god_mode):
        input_dir.z = -1

# Apply physics based on current state 
func apply_movement_physics(delta, move_speed, is_gas_sprinting):
    # Determine current acceleration and friction
    var current_acceleration = acceleration
    var current_friction = friction
    
    # Adjust based on movement state
    match current_movement_state:
        MovementState.GAS_SPRINTING:
            current_acceleration = gas_sprint_acceleration
            # Reduce speed by half if holding S during gas sprint
            if Input.is_key_pressed(KEY_S):
                move_speed *= gas_friction
            # Increase speed if holding W during gas sprint
            elif Input.is_key_pressed(KEY_W):
                move_speed *= gas_sprint_w_multiplier
        MovementState.SPRINTING:
            current_acceleration = sprint_acceleration
        MovementState.AIR_CONTROL:
            current_acceleration *= air_control
            current_friction *= air_control
    
    # Calculate direction from input
    var direction = Vector3.ZERO
    if input_dir:
        input_dir = input_dir.normalized()
        direction = ($Head.transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
        
        # Apply appropriate movement physics based on state
        if is_gas_sprinting:
            # For gas sprinting, use momentum-based movement
            apply_gas_movement(direction, move_speed, current_acceleration, delta, input_dir.z)
        else:
            # For regular movement, use direct velocity control
            velocity.x = direction.x * move_speed
            velocity.z = direction.z * move_speed
    else:
        # No input - apply friction
        velocity.x = move_toward(velocity.x, 0, current_friction * delta)
        velocity.z = move_toward(velocity.z, 0, current_friction * delta)
    
    # Apply gravity
    if not is_on_floor():
        velocity.y -= gravity * delta
        was_in_air = true
    else:
        if was_in_air:
            $ThudPlayer.play()
            was_in_air = false
        jumps_left = max_jumps
    
    # Apply knockback if active
    if knockback_timer > 0:
        velocity += knockback_velocity * delta
        knockback_timer -= delta
        if knockback_timer <= 0:
            knockback_velocity = Vector3.ZERO

# Handle movement sound effects based on state
func handle_movement_sounds():
    var current_speed = Vector2(velocity.x, velocity.z).length()
    var speed_ratio = current_speed / (
        gas_sprint_speed if current_movement_state == MovementState.GAS_SPRINTING else 
        sprint_speed if current_movement_state == MovementState.SPRINTING else 
        walk_speed
    )
    
    # Play appropriate movement sounds based on state
    if is_on_floor() and input_dir != Vector3.ZERO:
        match current_movement_state:
            MovementState.GAS_SPRINTING, MovementState.BOOSTING:
                play_movement_sound(true, false, speed_ratio)
            MovementState.SPRINTING:
                play_movement_sound(false, true, speed_ratio)
            MovementState.WALKING:
                play_movement_sound(false, false, speed_ratio)
    else:
        stop_movement_sounds(current_movement_state != MovementState.GAS_SPRINTING, true)

# Function to update gas UI to avoid duplicate code
func update_gas_ui():
    if gas_bar:
        gas_bar.value = current_gas
        DebugSettings.debug_print("player", "GasBar updated to: %s" % str(current_gas))
    else:
        DebugSettings.debug_print("player", "GasBar component missing during gas consumption!", DebugSettings.LogLevel.WARNING)

# Handle gas consumption
func handle_gas_consumption(delta, is_gas_sprinting, is_boosting):
    if is_boosting:
        velocity.y += boost_thrust * delta
        if not god_mode:
            current_gas -= gas_jump_consumption_rate * delta
            current_gas = clamp(current_gas, 0, max_gas)
            update_gas_ui()
    
    if is_gas_sprinting and not god_mode:
        var consumption_rate = gas_sprint_consumption_rate
        if Input.is_key_pressed(KEY_W):
            consumption_rate = gas_sprint_w_consumption_rate
        elif Input.is_key_pressed(KEY_S):
            consumption_rate = gas_sprint_s_consumption_rate
            
        current_gas -= consumption_rate * delta
        current_gas = clamp(current_gas, 0, max_gas)
        update_gas_ui()

# Handle gas cloud spawning
func handle_gas_cloud_spawning(delta, is_gas_sprinting, is_boosting):
    # Only process if we have gas or are in god mode
    if not (current_gas > 0 or god_mode):
        gas_cloud_timer = 0.0  # Reset timer when out of gas
        return
        
    # Determine the appropriate spawn interval based on current state
    var spawn_interval = gas_cloud_spawn_interval_sprint  # Default interval
    
    if is_boosting:
        spawn_interval = gas_cloud_spawn_interval_jump
    elif is_gas_sprinting:
        if Input.is_key_pressed(KEY_W):
            spawn_interval = gas_cloud_spawn_interval_w
        elif Input.is_key_pressed(KEY_S):
            spawn_interval = gas_cloud_spawn_interval_s
    
    # Only increment timer if we're in a valid state
    if is_gas_sprinting or is_boosting:
        gas_cloud_timer += delta
        
        # Spawn cloud if timer exceeds interval
        if gas_cloud_timer >= spawn_interval:
            spawn_gas_cloud()
            gas_cloud_timer = 0.0
    else:
        gas_cloud_timer = 0.0  # Reset timer when not in valid state

# Handle jumping logic
func handle_jumping(delta):
    if Input.is_action_just_pressed("ui_accept") and jumps_left > 0:
        velocity.y = jump_velocity
        if jumps_left == max_jumps:
            $GruntPlayer.play()
        else:
            $AirJumpPlayer.play()
        jumps_left -= 1
        last_jump_time = Time.get_ticks_msec() / 1000.0  # Record jump time

# Handle shooting logic
func handle_shooting():
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot and (current_magazine > 0 || god_mode) and not is_reloading:
        shoot()

# Handle reloading logic
func handle_reloading(delta):
    if is_reloading:
        reload_progress += delta
        reload_bar.value = reload_progress
        if reload_progress >= reload_time:
            var ammo_needed = max_magazine - current_magazine
            var ammo_to_load = min(ammo_needed, current_reserve)
            current_magazine += ammo_to_load
            current_reserve -= ammo_to_load
            update_ammo_display()
            is_reloading = false
            can_reload = true
            reload_bar.value = 0.0
            reload_bar.hide()  # Explicitly hide the reload bar
            DebugSettings.debug_print("player", "Reloading complete - Magazine: %d/%d" % [current_magazine, max_magazine])

func reload():
    if current_reserve > 0 and current_magazine < max_magazine and not is_reloading:
        is_reloading = true
        can_reload = false
        reload_progress = 0.0
        reload_bar.value = 0.0
        reload_bar.show()  # Explicitly show the reload bar
        $Head/Camera3D/Gun/ReloadPlayer.play()
        
        # Log reload start for debugging
        DebugSettings.debug_print("player", "Reloading started - Magazine: %d/%d" % [current_magazine, max_magazine])

func add_ammo(amount: int):
    current_reserve += amount
    current_reserve = clamp(current_reserve, 0, total_reserve_ammo)
    update_ammo_display()
    
    # Show pickup notification
    var pickup_notification = preload("res://scenes/hud_damage_number.tscn").instantiate()
    pickup_notification.damage_text = "+" + str(amount)
    pickup_notification.color = Color(0, 0, 1)  # Blue for ammo
    pickup_notification.text_size = 20  # Slightly smaller than damage numbers
    
    # Position next to ammo label
    if $HUD:
        var ammo_label = $HUD/HealthBarContainer/AmmoLabel
        pickup_notification.position = ammo_label.position + Vector2(ammo_label.size.x + 10, 0)
        $HUD.add_child(pickup_notification)
        
        ammo_label.add_theme_color_override("font_color", Color(0, 0, 1)) # Blue
        ammo_sound.play()
        await get_tree().create_timer(1.0).timeout
        ammo_label.remove_theme_color_override("font_color") # Back to default
    else:
        push_error("HUD node not found for ammo pickup notification!")

func add_gas(amount: float):
    current_gas += amount
    current_gas = clamp(current_gas, 0, max_gas)
    update_gas_ui()
    
    # Show pickup notification
    var pickup_notification = preload("res://scenes/hud_damage_number.tscn").instantiate()
    pickup_notification.damage_text = "+" + str(int(amount))
    pickup_notification.color = Color(0, 1, 0)  # Green for gas
    pickup_notification.text_size = 20  # Slightly smaller than damage numbers
    
    # Position next to gas bar
    if $HUD:
        pickup_notification.position = gas_bar.position + Vector2(gas_bar.size.x + 10, 0)
        $HUD.add_child(pickup_notification)
    else:
        push_error("HUD node not found for gas pickup notification!")

func _on_footstep_timer_timeout():
    # Only play footsteps if we're moving on the ground
    if is_on_floor():
        var current_speed = Vector2(velocity.x, velocity.z).length()
        var is_gas_sprinting = gas_sprint_enabled and Input.is_key_pressed(KEY_SHIFT) and (current_gas > 0 || god_mode)
        var sprinting = Input.is_key_pressed(KEY_SHIFT)
        
        # Adjust footstep sound based on current movement speed
        if current_speed > 0.5:  # Only play steps if moving at least a bit
            $FootstepPlayer.volume_db = footstep_volume
            
            # Adjust pitch based on movement type
            if is_gas_sprinting:
                $FootstepPlayer.pitch_scale = sprint_pitch
            elif sprinting:
                $FootstepPlayer.pitch_scale = regular_sprint_pitch
            else:
                $FootstepPlayer.pitch_scale = base_walk_pitch
                
            # Play the sound and adjust timing based on speed
            var move_speed = gas_sprint_speed if is_gas_sprinting else (sprint_speed if sprinting else walk_speed)
            var speed_ratio = current_speed / move_speed
            $FootstepPlayer.play()
            $FootstepTimer.wait_time = footstep_delay / max(0.5, speed_ratio)
            $FootstepTimer.start()
    # If we stopped moving or left the ground, don't restart the timer

func shoot():
    can_shoot = false
    if not god_mode:
        current_magazine -= 1
    update_ammo_display()
    
    # Get a bullet from the pool instead of instantiating a new one
    var bullet = PoolSystem.get_object(PoolSystem.PoolType.BULLET)
    if not bullet:
        # If we couldn't get a bullet from the pool, log a warning
        push_warning("Could not get bullet from pool")
        return
    
    DebugSettings.debug_print("player", "Shooting bullet: %d" % bullet.get_instance_id())
    
    # Connect to the enemy_hit signal
    if bullet.has_signal("enemy_hit"):
        # First disconnect any previous connections to avoid duplicates
        var connections = bullet.get_signal_connection_list("enemy_hit")
        for connection in connections:
            if connection.callable.get_object() == self:
                bullet.enemy_hit.disconnect(connection.callable)
        
        # Now connect our handler
        bullet.enemy_hit.connect(play_hit_sound)
        DebugSettings.debug_print("player", "Connected bullet signal: %d" % bullet.get_instance_id())
    
    # Set the bullet's position and velocity
    bullet.global_transform.origin = $Head/Camera3D/Gun/GunTip.global_transform.origin
    
    # Calculate and set velocity vector
    var velocity_vector = -$Head/Camera3D.global_transform.basis.z * bullet_speed
    bullet.velocity = velocity_vector
    DebugSettings.debug_print("player", "Set bullet velocity: %s speed: %s" % [str(velocity_vector), str(bullet_speed)])
    
    $Head/Camera3D/Gun/MuzzleFlash.visible = true
    $Head/Camera3D/Gun/GunshotPlayer.play()
    await get_tree().create_timer(muzzle_flash_duration).timeout
    $Head/Camera3D/Gun/MuzzleFlash.visible = false
    
    await get_tree().create_timer(shoot_cooldown - muzzle_flash_duration).timeout
    can_shoot = true

func take_damage(amount: float):
    if not god_mode:
        current_health -= amount
        current_health = clamp(current_health, 0, max_health)
        
        # Spawn 3D damage number using pool if available
        var damage_number = null
        if PoolSystem.has_pool("damage_numbers"):
            damage_number = PoolSystem.get_object(PoolSystem.PoolType.DAMAGE_NUMBER)
            if DebugSettings and DebugSettings.is_debug_enabled("pools"):
                DebugSettings.log_debug("pools", "Player got damage number from pool")
        
        if not damage_number:
            damage_number = preload("res://scenes/damage_number.tscn").instantiate()
            if DebugSettings and DebugSettings.is_debug_enabled("pools"):
                DebugSettings.log_warning("pools", "Player created new damage number (not from pool)")
                
        damage_number.text = str(int(amount))
        damage_number.spawn_height_offset = 3.0
        damage_number.position = global_transform.origin + Vector3(0, damage_number.spawn_height_offset, 0)
        get_parent().add_child(damage_number)
        damage_number.display()  # Call the display method to start the animation
        
        # Spawn HUD damage number using pool if available
        var hud_damage = null
        if PoolSystem.has_pool("hud_damage_numbers"):
            hud_damage = PoolSystem.get_object(PoolSystem.PoolType.HUD_DAMAGE_NUMBER)
            if DebugSettings and DebugSettings.is_debug_enabled("pools"):
                DebugSettings.log_debug("pools", "Player got HUD damage number from pool")
        
        if not hud_damage:
            hud_damage = preload("res://scenes/hud_damage_number.tscn").instantiate()
            if DebugSettings and DebugSettings.is_debug_enabled("pools"):
                DebugSettings.log_warning("pools", "Player created new HUD damage number (not from pool)")
        
        hud_damage.damage_text = str(int(amount))
        
        # Set color based on whether it's damage or healing
        if amount > 0:
            hud_damage.color = Color(1, 0, 0)  # Red for damage
            damage_sound.play()
        else:
            hud_damage.color = Color(0, 1, 0)  # Green for healing
            heal_sound.play()
            
        # Position next to health bar
        if $HUD:
            hud_damage.position = health_bar.position + Vector2(health_bar.size.x + 10, 0)
            $HUD.add_child(hud_damage)
            hud_damage.display()  # Call display to start animation
        else:
            push_error("HUD node not found for damage number!")
        
    if current_health <= 0:
        hide()
        set_physics_process(false)
    health_bar.value = current_health
    if current_health <= 0:
        die()


func update_ammo_display():
    ammo_label.text = str(current_magazine) + "/" + str(current_reserve)

func die():
    is_game_active = false
    var game_over = preload("res://scenes/GameOver.tscn").instantiate()
    get_tree().root.add_child(game_over)
    game_over.set_score_and_kills(score, kills)
    get_tree().current_scene.queue_free()
    
    # Set it as the current scene
    get_tree().current_scene = game_over
    

func add_score(points: int):
    score += points
    kills += 1 # Increment kills with each score addition
    
    
    
func _on_pickup_area_body_entered(body):
    # Immediately check if we're in a valid state
    if not is_instance_valid(self) or not is_inside_tree():
        return
        
    if body.is_in_group("health_pack"):
        take_damage(-body.health_amount)
        
        # Create a safe reference to the heal border
        var heal_border_ref = weakref(heal_border)
        
        # Instead of await, use a Timer node and signal
        var timer = Timer.new()
        timer.wait_time = 0.5
        timer.one_shot = true
        add_child(timer)
        
        # Set border visible
        if heal_border_ref.get_ref():
            for child in heal_border_ref.get_ref().get_children():
                child.visible = true
                child.color = Color(0, 1, 0, 1)
        
        # Connect timer to lambda function that safely resets border
        timer.timeout.connect(func():
            # Check if heal border still exists
            if heal_border_ref.get_ref() and is_instance_valid(self) and not is_queued_for_deletion():
                for child in heal_border_ref.get_ref().get_children():
                    child.visible = false
                    child.color = Color(0, 1, 0, 0)
            # Cleanup the timer
            timer.queue_free()
        )
        
        timer.start()
        
        # Free the health pack immediately
        if is_instance_valid(body):
            body.queue_free()
            
    elif body.is_in_group("ammo_pack"):
        if is_instance_valid(body):
            add_ammo(body.ammo_amount)
            body.queue_free()
            
    elif body.is_in_group("gas_pack"):
        if is_instance_valid(body):
            add_gas(body.gas_amount)
            body.queue_free()
 
        
        
func play_hit_sound(is_headshot: bool = false):
    if hit_sound:
        hit_sound.play()
    if crosshair:
        crosshair.on_hit(is_headshot)  # Pass headshot info
        
        
        
func apply_knockback(direction: Vector3, force: float):
    if is_on_floor(): # Only apply if grounded
        knockback_velocity = direction * force
        knockback_timer = 0.15 # 0.15s duration
        
func spawn_gas_cloud():
    # Safety checks - don't spawn if we're in an invalid state
    if not is_inside_tree() or not is_instance_valid(self) or is_queued_for_deletion():
        return
        
    # Limit the number of active gas clouds to prevent system overload
    var current_clouds = get_tree().get_nodes_in_group("gas_cloud")
    if current_clouds.size() >= max_gas_clouds:
        # Skip creating a new cloud if we're at the limit
        return
    
    # Try to get a gas cloud from the pool first
    var cloud = null
    var from_pool = false
    var cloud_id = -1
    
    if Engine.has_singleton("PoolSystem") and PoolSystem.has_pool("gas_clouds"):
        if DebugSettings and DebugSettings.is_debug_enabled("gas"):
            DebugSettings.log_debug("gas", "Gas cloud pool exists, attempting to get object")
        
        cloud = PoolSystem.get_object(PoolSystem.PoolType.GAS_CLOUD)
        if cloud:
            cloud_id = cloud.get_instance_id()
            from_pool = true
            
            # Log to DebugSettings if available
            if DebugSettings and DebugSettings.is_debug_enabled("gas"):
                DebugSettings.log_debug("gas", "Got gas cloud ID:%d from pool" % cloud_id)
                
            if DebugSettings and DebugSettings.is_debug_enabled("pools"):
                DebugSettings.log_debug("pools", "Player successfully got gas cloud ID:%d from pool" % cloud_id)
    else:
        if DebugSettings and DebugSettings.is_debug_enabled("gas"):
            DebugSettings.log_warning("gas", "Gas cloud pool does not exist or PoolSystem not available")
    
    # If no pooled gas cloud is available, instantiate one
    if cloud == null:
        if DebugSettings and DebugSettings.is_debug_enabled("gas"):
            DebugSettings.log_warning("gas", "No pooled gas cloud available, instantiating new one")
            
        # Ensure we've initialized the gas cloud scene
        _initialize_gas_cloud()
        
        cloud = gas_cloud_scene.instantiate()
        cloud_id = cloud.get_instance_id()
        
        # Log to DebugSettings if available
        if DebugSettings and DebugSettings.is_debug_enabled("pools"):
            DebugSettings.log_warning("pools", "Player CREATED NEW gas cloud ID:%d (pool bypassed)" % cloud_id)
        
        if DebugSettings and DebugSettings.is_debug_enabled("gas"):
            DebugSettings.log_warning("gas", "Created new gas cloud ID:%d (not from pool)" % cloud_id)
    
    # Immediately set preserve_scene_visuals to false if the property exists
    if cloud.get("preserve_scene_visuals") != null:
        cloud.preserve_scene_visuals = false
    
    # Pre-set key properties before adding to scene
    cloud.damage_per_tick = gas_cloud_damage
    cloud.damage_interval = gas_cloud_damage_interval
    
    # Add cloud to group for tracking (poolable version does this in _ready)
    if not from_pool:
        cloud.add_to_group("gas_cloud")
    
    # Try to add to level node for better organization
    var level_node = get_node_or_null("/root/Main/Level")
    if is_instance_valid(level_node):
        level_node.call_deferred("add_child", cloud)
    else:
        # Fallback to parent
        get_parent().call_deferred("add_child", cloud)
    
    # Add a small random offset to position
    var random_offset = Vector3(
        randf_range(-0.5, 0.5),
        randf_range(-0.1, 0.3),
        randf_range(-0.5, 0.5)
    )
    
    # Set position safely using deferred call
    call_deferred("_set_cloud_properties", cloud, random_offset)

# Set cloud properties safely in deferred context
func _set_cloud_properties(cloud, random_offset):
    # Safety check in case the cloud or player was freed between calls
    if not is_instance_valid(cloud) or not is_instance_valid(self):
        if DebugSettings and DebugSettings.is_debug_enabled("gas"):
            DebugSettings.log_error("gas", "Cloud or player no longer valid during property setting")
        return
    
    # Set position
    cloud.global_transform.origin = global_transform.origin + gas_cloud_offset + random_offset
    
    # Ensure the cloud has the correct collision settings
    cloud.collision_layer = 8
    cloud.collision_mask = 1
    
    # Apply custom properties for gameplay AND visuals from player.gd
    cloud.damage_per_tick = gas_cloud_damage
    cloud.damage_interval = gas_cloud_damage_interval
    cloud.lifetime = gas_cloud_lifetime * randf_range(0.9, 1.1)
    
    # Allow our settings to override the scene visuals
    if cloud.get("preserve_scene_visuals") != null:
        cloud.preserve_scene_visuals = false
    
    # Apply visual properties - prefer the new method if available
    if cloud.has_method("set_particle_properties"):
        # Set color properties before calling the method
        cloud.cloud_color = gas_cloud_color
        cloud.particle_amount = gas_cloud_particle_amount
        cloud.particle_scale_min = gas_cloud_particle_scale_min
        cloud.particle_scale_max = gas_cloud_particle_scale_max
        cloud.emission_strength = gas_cloud_emission_strength if self.has_method("get_gas_cloud_emission_strength") else 0.5
        
        # Use the new centralized method to update appearance
        cloud.set_particle_properties()
    elif cloud.get("particle_amount") != null:
        # Fallback for older versions
        cloud.particle_amount = gas_cloud_particle_amount
        cloud.particle_scale_min = gas_cloud_particle_scale_min
        cloud.particle_scale_max = gas_cloud_particle_scale_max
        cloud.cloud_color = gas_cloud_color
    
    if DebugSettings and DebugSettings.is_debug_enabled("gas"):
        DebugSettings.log_debug("gas", "Gas cloud ID:%d properties set, pos:%s, lifetime:%.1f" % 
            [cloud.get_instance_id(), str(cloud.global_transform.origin), cloud.lifetime])

# Sound management functions
func play_movement_sound(is_gas_powered: bool, is_sprinting: bool, speed_ratio: float = 1.0):
    if is_gas_powered:
        if not sprint_sound.playing:
            sprint_sound.play()
    elif is_sprinting:
        if not $FootstepPlayer.playing and $FootstepTimer.is_stopped():
            $FootstepPlayer.pitch_scale = regular_sprint_pitch
            $FootstepPlayer.volume_db = footstep_volume
            $FootstepPlayer.play()
            # Adjust step frequency based on speed
            $FootstepTimer.wait_time = footstep_delay / max(0.5, speed_ratio)
            $FootstepTimer.start()
    else:  # Regular walking
        if not $FootstepPlayer.playing and $FootstepTimer.is_stopped():
            $FootstepPlayer.pitch_scale = base_walk_pitch
            $FootstepPlayer.volume_db = footstep_volume
            $FootstepPlayer.play()
            $FootstepTimer.wait_time = footstep_delay
            $FootstepTimer.start()

func stop_movement_sounds(stop_gas_sounds: bool = true, stop_footsteps: bool = true):
    if stop_gas_sounds and sprint_sound.playing:
        sprint_sound.stop()
    if stop_footsteps and $FootstepPlayer.playing:
        $FootstepPlayer.stop()

func update_timer_display():
    var minutes = int(game_time) / 60
    var seconds = int(game_time) % 60
    $HUD/TimerLabel.text = "%02d:%02d" % [minutes, seconds]

func _initialize_gas_cloud():
    if _gas_cloud_initialized: return
    
    # First try to use the pool system
    if Engine.has_singleton("PoolSystem") and PoolSystem.has_pool("gas_clouds"):
        DebugSettings.debug_print("player", "Using gas clouds from PoolSystem")
        _gas_cloud_initialized = true
        return
        
    # Fall back to direct scene loading
    var file = FileAccess.file_exists("res://scenes/PoolableGasCloud.tscn")
    if !file:
        DebugSettings.debug_print("player", "Poolable gas cloud scene not found, falling back to regular gas cloud", DebugSettings.LogLevel.WARNING)
        gas_cloud_scene = preload("res://scenes/gas_cloud.tscn")
    
    _gas_cloud_initialized = true
    
    if DebugSettings != null and DebugSettings.has_method("is_debug_enabled") and DebugSettings.is_debug_enabled("gas"):
        DebugSettings.debug_print("player", "Gas cloud scene initialized")
