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

# Gas cloud variables
@export_group("Gas Cloud")
@export var gas_cloud_spawn_interval: float = 0.5
@export var gas_cloud_offset: Vector3 = Vector3(0, 0.5, 0)
@export var gas_cloud_damage: float = 5.0
@export var gas_cloud_damage_interval: float = 0.5
@export var gas_cloud_lifetime: float = 3.0
@export var gas_cloud_size: float = 2.0
@export var gas_cloud_color: Color = Color(0.0, 0.8, 0.0, 0.3)
var gas_cloud_scene = preload("res://scenes/gas_cloud.tscn")
var gas_cloud_timer: float = 0.0
var was_gas_sprinting: bool = false
var was_gas_boosting: bool = false

func _ready():
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
    
    # Log conditions if debug is needed
    # print("Double jumped: ", double_jumped, " | Holding space: ", holding_space, 
    #      " | Has gas: ", has_gas, " | After delay: ", after_delay, 
    #      " | Gas level: ", current_gas)
        
    is_boosting = double_jumped and holding_space and has_gas and after_delay and is_on_air()
    
    # If boost just started, log it
    if !old_boosting and is_boosting:
        print("Boost started! Gas: ", current_gas)
    elif old_boosting and !is_boosting:
        print("Boost stopped! Gas: ", current_gas)
    
    # Gas-powered sprint: double-tap Shift + hold
    var is_gas_sprinting = gas_sprint_enabled and sprinting and (current_gas > 0 || god_mode)
    
    # Gas cloud spawning for both sprint and boost
    if (is_gas_sprinting or is_boosting) and (current_gas > 0 or god_mode):
        gas_cloud_timer += delta
        if gas_cloud_timer >= gas_cloud_spawn_interval:
            spawn_gas_cloud()
            gas_cloud_timer = 0.0
    
    # Update tracking variables after checking current state
    was_gas_sprinting = is_gas_sprinting
    was_gas_boosting = is_boosting
    
    if is_gas_sprinting:
        move_speed = gas_sprint_speed
        if not god_mode:
            current_gas -= gas_sprint_consumption_rate * delta
            current_gas = clamp(current_gas, 0, max_gas)
            if gas_bar:
                gas_bar.value = current_gas
            else:
                print("GasBar missing during gas sprint!")
    
    # Regular sprint: single hold Shift
    elif sprinting:
        move_speed = sprint_speed  # No gas consumption
    
    # Handle boosting
    if is_boosting:
        velocity.y += boost_thrust * delta  # Boost when holding Spacebar after delay
        if not god_mode:
            current_gas -= gas_jump_consumption_rate * delta
            current_gas = clamp(current_gas, 0, max_gas)
            if gas_bar:
                gas_bar.value = current_gas
            else:
                print("GasBar missing during boost!")
    
    # Sound logic
    if (is_gas_sprinting or is_boosting) and not sprint_sound.playing:
        sprint_sound.play()
        print("Playing SprintSound for gas sprint/boost")
    elif sprinting and not $FootstepPlayer.playing:
        $FootstepPlayer.pitch_scale = regular_sprint_pitch  # Regular sprint sound
        $FootstepPlayer.play()
        print("Playing FootstepPlayer for regular sprint")
    else:
        if sprint_sound.playing and not (is_gas_sprinting or is_boosting):
            sprint_sound.stop()
        if $FootstepPlayer.playing and not (sprinting or is_on_floor()):
            $FootstepPlayer.stop()
    
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
    
    if Input.is_action_just_pressed("ui_accept") and jumps_left > 0:
        velocity.y = jump_velocity
        if jumps_left == max_jumps:
            $GruntPlayer.play()
        else:
            $AirJumpPlayer.play()
        jumps_left -= 1
        last_jump_time = Time.get_ticks_msec() / 1000.0  # Record jump time
    
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
        var direction = ($Head.transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
        
        if is_on_floor() and $FootstepTimer.is_stopped() and not $FootstepPlayer.playing:
            $FootstepPlayer.volume_db = footstep_volume
            $FootstepPlayer.pitch_scale = sprint_pitch if Input.is_key_pressed(KEY_SHIFT) and current_gas > 0 else base_walk_pitch
            $FootstepPlayer.play()
            $FootstepTimer.start()
    else:
        velocity.x = move_toward(velocity.x, 0, move_speed)
        velocity.z = move_toward(velocity.z, 0, move_speed)
        if $FootstepPlayer.playing:
            $FootstepPlayer.stop()
    
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot and (current_magazine > 0 || god_mode) and not is_reloading:
        shoot()
    
    if knockback_timer > 0 and is_on_floor():
        velocity += knockback_velocity
        knockback_timer -= delta
        if knockback_timer <= 0:
            knockback_velocity = Vector3.ZERO
    
    move_and_slide()
    
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
    input_dir = Vector3.ZERO # Reset here
    if Input.is_key_pressed(KEY_A): input_dir.x = -1
    elif Input.is_key_pressed(KEY_D): input_dir.x = 1
    if Input.is_key_pressed(KEY_W): input_dir.z = -1
    elif Input.is_key_pressed(KEY_S): input_dir.z = 1
    
    if input_dir and is_on_floor() and not $FootstepPlayer.playing:
        $FootstepPlayer.volume_db = footstep_volume
        $FootstepPlayer.pitch_scale = sprint_pitch if Input.is_key_pressed(KEY_SHIFT) and current_gas > 0 else base_walk_pitch
        $FootstepPlayer.play()
        $FootstepTimer.start()
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
    
func die():
    # Pass score and kills to Game Over scene
    var game_over = preload("res://scenes/GameOver.tscn").instantiate()
    game_over.set_score_and_kills(score, kills)
    get_tree().root.add_child(game_over)
    get_tree().current_scene.queue_free() # Remove Main scene
    get_tree().current_scene = game_over
    
func add_score(points: int):
    score += points
    kills += 1 # Increment kills with each score addition
    
    
    
func _on_pickup_area_body_entered(body):
    if body.is_in_group("health_pack"):
        take_damage(-body.health_amount)
        for child in heal_border.get_children():
            child.visible = true
            child.color = Color(0, 1, 0, 1)
        await get_tree().create_timer(0.5).timeout
        for child in heal_border.get_children():
            child.visible = false
            child.color = Color(0, 1, 0, 0)
        body.queue_free()
    elif body.is_in_group("ammo_pack"):
        add_ammo(body.ammo_amount)
        body.queue_free()
    elif body.is_in_group("gas_pack"):
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
    var cloud = gas_cloud_scene.instantiate()
    # Add the cloud to the level node for better organization
    var level_node = get_node_or_null("/root/Main/Level")
    if level_node:
        level_node.add_child(cloud)
    else:
        get_parent().add_child(cloud)
    
    # Add a small random offset to position
    var random_offset = Vector3(
        randf_range(-0.5, 0.5),
        randf_range(-0.1, 0.3),
        randf_range(-0.5, 0.5)
    )
    
    cloud.global_transform.origin = global_transform.origin + gas_cloud_offset + random_offset
    
    # Ensure the cloud has the correct collision settings
    cloud.collision_layer = 8
    cloud.collision_mask = 1
    
    # Apply custom properties for gameplay (but not visuals)
    cloud.damage_per_tick = gas_cloud_damage
    cloud.damage_interval = gas_cloud_damage_interval
    cloud.lifetime = gas_cloud_lifetime * randf_range(0.9, 1.1)
    cloud.cloud_size = gas_cloud_size
    
    # Don't override visual settings from the scene editor
    cloud.preserve_scene_visuals = true
    
    print("Gas cloud spawned. Damage per tick:", gas_cloud_damage)

# Add this helper function to check if player is in the air
func is_on_air() -> bool:
    return !is_on_floor()
