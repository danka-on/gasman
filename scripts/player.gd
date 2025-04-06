extends CharacterBody3D

# Movement variables

@export var god_mode : bool = false # God Mode toggle in Inspector

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
var acceleration = 70.0        # Base acceleration factor (units/second²)
var friction = 15.0            # Base friction factor when stopping
var air_control = 0.3          # Multiplier for reduced control while airborne (0-1)
var sprint_acceleration = 50.0 # Acceleration for regular sprint
var gas_sprint_acceleration = 120.0 # Acceleration for gas-powered sprint

var is_boosting : bool = false # Track boost state
var boost_thrust : float = 10.0 # Upward force per second
var boost_gas_rate : float = 30.0 # Gas drain per second for boost

# New export variables for gas consumption
@export var gas_sprint_consumption_rate : float = 20.0  # Gas per second for gas sprint
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
@onready var gas_bar = $"../HUD/GasBar"
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
@onready var reload_bar = $"../HUD/HealthBarContainer/ReloadBar"
var is_reloading : bool = false
var reload_progress : float = 0.0



# Audio variables
@export var base_walk_pitch : float = 1.2
@export var sprint_pitch : float = 1.5
@export var footstep_delay : float = 0.3
@export var footstep_volume : float = 0.0
@export var regular_sprint_pitch : float = 1.4  # Adjustable in Inspector for regular sprint


@onready var ammo_sound = $AmmoSound
@onready var heal_sound = $HealSound

# Health variables
@export var max_health : float = 100.0
var current_health : float = max_health

# Score and kills
var score : int = 0
var kills : int = 0

# UI references
@onready var health_bar = get_node("/root/Main/HUD/HealthBarContainer/HealthBar")
@onready var ammo_label = get_node("/root/Main/HUD/HealthBarContainer/AmmoLabel")
@onready var enemy = get_node("res://scenes/enemy.tscn") # May not be needed with spawner
@onready var pickup_area = $PickupArea
@onready var hit_sound = $HitSound
@onready var damage_sound = $DamageSound
@onready var heal_border = get_node("/root/Main/HUD/HealBorder")
@onready var speedometer_label = get_node("/root/Main/HUD/HealthBarContainer/SpeedometerLabel")

# Gas cloud variables
@export_group("Gas Cloud")
@export var gas_cloud_spawn_interval_sprint: float = 0.5  # Interval for gas sprint clouds
@export var gas_cloud_spawn_interval_jump: float = 0.3    # Interval for gas jump clouds (faster due to higher velocity)
@export var gas_cloud_offset: Vector3 = Vector3(0, 0.5, 0)
@export var gas_cloud_damage: float = 5.0
@export var gas_cloud_damage_interval: float = 0.5
@export var gas_cloud_lifetime: float = 3.0


@export var gas_cloud_particle_amount: int = 50
@export var gas_cloud_particle_scale_min: float = 2.0
@export var gas_cloud_particle_scale_max: float = 3.0

@export var max_gas_clouds: int = 30  # Maximum number of gas clouds allowed at once
var gas_cloud_scene = preload("res://scenes/gas_cloud.tscn")
var gas_cloud_timer: float = 0.0
var was_gas_sprinting: bool = false
var was_gas_boosting: bool = false

# Speedometer variables
var units_to_mph_factor = 2.237  # Conversion factor (assuming 1 unit = 1 m/s)

func _ready():
    print("on ready")
    
    var main = get_tree().current_scene
    var main_tree = main.get_children()
    for child in main_tree:
        print(child.name)
    collision_layer = 1
    collision_mask = 1 | 8 | 16
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    if not $FootstepTimer:
        print("Error: FootstepTimer missing!")
        return
    $FootstepTimer.wait_time = footstep_delay
    $FootstepPlayer.volume_db = footstep_volume
    health_bar.max_value = max_health
    health_bar.value = current_health
    if gas_bar:
        gas_bar.max_value = max_gas
        gas_bar.value = current_gas
        print("GasBar found!")
    else:
        print("Error: GasBar not found at /root/Main/HUD/HealthBarContainer/GasBar!")
    update_ammo_display()
    if pickup_area:
        pickup_area.connect("body_entered", _on_pickup_area_body_entered)
    else:
        print("Error: PickupArea missing!")
    if enemy:
        enemy.player = self
    if god_mode:
        current_health = max_health
        current_gas = max_gas
        current_magazine = max_magazine
        current_reserve = total_reserve_ammo
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
                    print("Gas sprint enabled via double-tap!")
                # Update the last press time and mark Shift as pressed
                last_shift_press_time = current_time
                was_shift_released = false
        else:  # Shift was released
            was_shift_released = true
            gas_sprint_enabled = false
            print("Shift released - gas sprint disabled")
        
        
        
        
         
func _physics_process(delta):
    
    var sprinting = Input.is_key_pressed(KEY_SHIFT)  # Check if Shift is held
    var move_speed = walk_speed  # Default to walking speed
    input_dir = Vector3.ZERO
    
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
    elif sprinting:
        move_speed = sprint_speed
    
    # Input gathering
    if Input.is_key_pressed(KEY_A):
        input_dir.x = -1
    elif Input.is_key_pressed(KEY_D):
        input_dir.x = 1
    if Input.is_key_pressed(KEY_W):
        input_dir.z = -1
    elif Input.is_key_pressed(KEY_S):
        input_dir.z = 1
    
    # Determine current acceleration and friction based on movement state
    var current_acceleration = acceleration
    var current_friction = friction
    
    # Adjust based on movement type
    if is_gas_sprinting:
        current_acceleration = gas_sprint_acceleration
    elif sprinting:
        current_acceleration = sprint_acceleration
    
    # Reduce control in air
    if !is_on_floor():
        current_acceleration *= air_control
        current_friction *= air_control
    
    # Calculate direction from input
    var direction = Vector3.ZERO
    if input_dir:
        input_dir = input_dir.normalized()
        direction = ($Head.transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
        
        # Accelerate towards target velocity
        velocity.x = move_toward(velocity.x, direction.x * move_speed, current_acceleration * delta)
        velocity.z = move_toward(velocity.z, direction.z * move_speed, current_acceleration * delta)
    else:
        # Apply friction when no input
        velocity.x = move_toward(velocity.x, 0, current_friction * delta)
        velocity.z = move_toward(velocity.z, 0, current_friction * delta)
    
    # Apply gravity
    if not is_on_floor():
        velocity.y -= gravity * delta
        was_in_air = true
        if $FootstepPlayer.playing:
            $FootstepPlayer.stop()
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
    
    # Handle boosting, jumping, and gas consumption
    is_boosting = double_jumped and holding_space and has_gas and after_delay and is_on_air()
    
    # If boost just started, log it
    if !old_boosting and is_boosting:
        print("Boost started! Gas: ", current_gas)
    elif old_boosting and !is_boosting:
        print("Boost stopped! Gas: ", current_gas)
        
    # Handle gas consumption and boost physics
    if is_boosting:
        velocity.y += boost_thrust * delta  # Boost when holding Spacebar after delay
        if not god_mode:
            current_gas -= gas_jump_consumption_rate * delta
            current_gas = clamp(current_gas, 0, max_gas)
            if gas_bar:
                gas_bar.value = current_gas
            else:
                print("GasBar missing during boost!")
    
    # Handle gas sprint consumption
    if is_gas_sprinting:
        if not god_mode:
            current_gas -= gas_sprint_consumption_rate * delta
            current_gas = clamp(current_gas, 0, max_gas)
            if gas_bar:
                gas_bar.value = current_gas
            else:
                print("GasBar missing during gas sprint!")
    
    # Gas cloud spawning for both sprint and boost
    if (is_gas_sprinting or is_boosting) and (current_gas > 0 or god_mode):
        gas_cloud_timer += delta
        
        # Use the appropriate spawn interval based on movement type
        var spawn_interval = gas_cloud_spawn_interval_sprint if is_gas_sprinting else gas_cloud_spawn_interval_jump
        
        if gas_cloud_timer >= spawn_interval:
            spawn_gas_cloud()
            gas_cloud_timer = 0.0
    
    # Sound logic based on actual movement speed
    if direction != Vector3.ZERO and is_on_floor():
        # Calculate actual movement speed (velocity magnitude on XZ plane)
        var current_speed = Vector2(velocity.x, velocity.z).length()
        var speed_ratio = current_speed / move_speed  # How close to max speed
        
        # Play appropriate sounds based on movement state
        if (is_gas_sprinting or is_boosting) and not sprint_sound.playing:
            sprint_sound.play()
        elif sprinting and current_speed > 0.5 and not $FootstepPlayer.playing and $FootstepTimer.is_stopped():
            $FootstepPlayer.pitch_scale = regular_sprint_pitch
            $FootstepPlayer.volume_db = footstep_volume
            $FootstepPlayer.play()
            # Adjust step frequency based on speed
            $FootstepTimer.wait_time = footstep_delay / max(0.5, speed_ratio)
            $FootstepTimer.start()
        elif current_speed > 0.5 and not sprinting and not $FootstepPlayer.playing and $FootstepTimer.is_stopped():
            $FootstepPlayer.pitch_scale = base_walk_pitch
            $FootstepPlayer.volume_db = footstep_volume
            $FootstepPlayer.play()
            $FootstepTimer.wait_time = footstep_delay
            $FootstepTimer.start()
    else:
        if sprint_sound.playing and not (is_gas_sprinting or is_boosting):
            sprint_sound.stop()
        if $FootstepPlayer.playing and not is_on_floor():
            $FootstepPlayer.stop()
    
    # Handle jumping
    if Input.is_action_just_pressed("ui_accept") and jumps_left > 0:
        velocity.y = jump_velocity
        if jumps_left == max_jumps:
            $GruntPlayer.play()
        else:
            $AirJumpPlayer.play()
        jumps_left -= 1
        last_jump_time = Time.get_ticks_msec() / 1000.0  # Record jump time
    
    # Apply all movement
    move_and_slide()
    
    # Update speedometer
    update_speedometer()
    
    # Update tracking variables after checking current state
    was_gas_sprinting = is_gas_sprinting
    was_gas_boosting = is_boosting
    
    # Handle shooting
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot and (current_magazine > 0 || god_mode) and not is_reloading:
        shoot()
    
    # Handle reloading
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
            reload_bar.hide()
func reload():
    if current_reserve > 0 and current_magazine < max_magazine and not is_reloading:
        is_reloading = true
        can_reload = false
        reload_progress = 0.0
        reload_bar.value = 0.0
        reload_bar.show()
        $Head/Camera3D/Gun/ReloadPlayer.play()
        
func add_gas(amount: float):
    current_gas += amount
    current_gas = clamp(current_gas, 0, max_gas)
    gas_bar.value = current_gas    
        
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
    var bullet = bullet_scene.instantiate()
    get_parent().add_child(bullet)
    bullet.global_transform.origin = $Head/Camera3D/Gun/GunTip.global_transform.origin
    bullet.velocity = -$Head/Camera3D.global_transform.basis.z * bullet_speed
    
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
    if amount > 0:
        damage_sound.play()
    elif amount < 0:
        heal_sound.play()
    if current_health <= 0:
        hide()
        set_physics_process(false)
    health_bar.value = current_health
    if current_health <= 0:
        die()


func add_ammo(amount: int):
    current_reserve += amount
    current_reserve = clamp(current_reserve, 0, total_reserve_ammo)
    update_ammo_display()
    ammo_label.add_theme_color_override("font_color", Color(0, 0, 1)) # Blue
    ammo_sound.play()
    await get_tree().create_timer(1.0).timeout
    ammo_label.remove_theme_color_override("font_color") # Back to default
    
    
func update_ammo_display():
    ammo_label.text = str(current_magazine) + "/" + str(current_reserve)
var count = 0
func die():
    
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
 
        
        
func play_hit_sound():
    if hit_sound:
        hit_sound.play()
        
        
        
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
    
    # Create the gas cloud
    var cloud = gas_cloud_scene.instantiate()
    
    # Immediately set preserve_scene_visuals to false
    cloud.preserve_scene_visuals = false
    
    # Pre-set key properties before adding to scene
    
    cloud.damage_per_tick = gas_cloud_damage
    cloud.damage_interval = gas_cloud_damage_interval
    
    # Add cloud to group for tracking
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
    
    # Log for debugging
    print("Spawning gas cloud:", " damage=", gas_cloud_damage, " interval=", gas_cloud_damage_interval)

# Set cloud properties safely in deferred context
func _set_cloud_properties(cloud, random_offset):
    # Safety check in case the cloud or player was freed between calls
    if not is_instance_valid(cloud) or not is_instance_valid(self):
        print("hey no cloud lol!!")
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
    

    cloud.particle_amount = gas_cloud_particle_amount
    cloud.particle_scale_min = gas_cloud_particle_scale_min
    cloud.particle_scale_max = gas_cloud_particle_scale_max
    
    
    # Allow our settings to override the scene visuals
    cloud.preserve_scene_visuals = false
    
    if OS.is_debug_build():
        print("Gas cloud spawned. ", " Damage per tick:", gas_cloud_damage, " Interval:", gas_cloud_damage_interval)

# Add this helper function to check if player is in the air
func is_on_air() -> bool:
    return !is_on_floor()

# New function to update the speedometer
func update_speedometer():
    if speedometer_label:
        # Calculate speed based on horizontal velocity (x and z)
        var current_speed = Vector2(velocity.x, velocity.z).length()
        
        # Convert to mph
        var speed_mph = current_speed * units_to_mph_factor
        
        # Update label (format to 1 decimal place)
        speedometer_label.text = "%.1f mph" % speed_mph
    else:
        push_error("Speedometer label not found!")
