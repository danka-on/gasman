extends CharacterBody3D

# Movement variables



var gravity = 9.8
var mouse_sensitivity = 0.002
var jump_velocity = 7.0
var max_jumps = 2
var jumps_left = max_jumps
var was_in_air = false
var knockback_velocity : Vector3 = Vector3.ZERO
var knockback_duration : float = 0.0 # Time left for knockback
var knockback_timer : float = 0.0

@export var walk_speed : float = 5.0
@export var sprint_speed : float = 10.0
@onready var gas_bar = $"../HUD/GasBar"
var max_gas : float = 100.0
var current_gas : float = max_gas
var gas_consumption_rate : float = 20.0 # Gas per second while sprinting
var input_dir : Vector3 = Vector3.ZERO # Added declaration

var target_velocity : Vector3 = Vector3.ZERO
@onready var sprint_sound = $SprintSound


# Shooting variables
var bullet_scene = preload("res://bullet.tscn")
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
@onready var enemy = get_node("res://enemy.tscn") # May not be needed with spawner
@onready var pickup_area = $PickupArea
@onready var hit_sound = $HitSound
@onready var damage_sound = $DamageSound
@onready var heal_border = get_node("/root/Main/HUD/HealBorder")


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
    gas_bar.max_value = max_gas
    gas_bar.value = current_gas

    update_ammo_display()
    if pickup_area:
        pickup_area.connect("body_entered", _on_pickup_area_body_entered)
    else:
        print("Error: PickupArea missing!")
    if enemy:
        enemy.player = self

func _input(event):
    if event is InputEventMouseMotion:
        $Head.rotate_y(-event.relative.x * mouse_sensitivity)
        $Head/Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
        $Head/Camera3D.rotation.x = clamp($Head/Camera3D.rotation.x, -1.5, 1.5)
    
    if event is InputEventKey and event.pressed and event.keycode == KEY_H:
        take_damage(10.0)
    
    if event.is_action_pressed("reload") and can_reload:
        reload()
    
func _physics_process(delta):
    var sprinting = Input.is_key_pressed(KEY_SHIFT) and current_gas > 0
    var move_speed = sprint_speed if sprinting else walk_speed
    input_dir = Vector3.ZERO
    
    if sprinting:
        current_gas -= gas_consumption_rate * delta
        current_gas = clamp(current_gas, 0, max_gas)
        if gas_bar:
            gas_bar.value = current_gas
        else:
            print("GasBar missing during sprint!")
        if not sprint_sound.playing:
            sprint_sound.play()
    else:
        if sprint_sound.playing:
            sprint_sound.stop()
    
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
    
    # Movement input
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
            $FootstepPlayer.pitch_scale = sprint_pitch if sprinting else base_walk_pitch
            $FootstepPlayer.play()
            $FootstepTimer.start()
    else:
        velocity.x = move_toward(velocity.x, 0, move_speed)
        velocity.z = move_toward(velocity.z, 0, move_speed)
        if $FootstepPlayer.playing:
            $FootstepPlayer.stop()
    
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot and current_magazine > 0 and not is_reloading:
        shoot()
    
    # Apply knockback only when grounded
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
    current_magazine -= 1
    update_ammo_display()
    var bullet = bullet_scene.instantiate()
    get_parent().add_child(bullet)
    # Spawn at GunTip's global position
    bullet.global_transform.origin = $Head/Camera3D/Gun/GunTip.global_transform.origin
    # Set velocity along camera's forward direction
    bullet.velocity = -$Head/Camera3D.global_transform.basis.z * bullet_speed
    
    $Head/Camera3D/Gun/MuzzleFlash.visible = true
    $Head/Camera3D/Gun/GunshotPlayer.play()
    await get_tree().create_timer(muzzle_flash_duration).timeout
    $Head/Camera3D/Gun/MuzzleFlash.visible = false
    
    await get_tree().create_timer(shoot_cooldown - muzzle_flash_duration).timeout
    can_shoot = true

func take_damage(amount: float):
    current_health -= amount
    current_health = clamp(current_health, 0, max_health)
    if amount > 0: # Only play damage sound for harm
        damage_sound.play()
    elif amount < 0: # Play heal sound for healing
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
    var game_over = preload("res://GameOver.tscn").instantiate()
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
        
