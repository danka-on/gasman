extends Node

var player = null  # Will reference the parent player node

# Shooting variables
@export var bullet_scene_path : String = "res://scenes/bullet.tscn"
var can_shoot = true
@export var shoot_cooldown : float = 0.2
@export var muzzle_flash_duration : float = 0.1
@export var bullet_speed : float = 20.0

# Ammo variables
@export var max_magazine : int = 30
var current_magazine : int = max_magazine
@export var total_reserve_ammo : int = 90
var current_reserve : int = total_reserve_ammo

# Reload variables
var can_reload = true
@export var reload_time : float = 2.0
var is_reloading : bool = false
var reload_progress : float = 0.0

# Object pooling reference
var object_pool = null
# UI reference
var ammo_label = null
var reload_bar = null

func _ready():
    current_magazine = max_magazine
    current_reserve = total_reserve_ammo
    
    # Get UI references
    update_ui_references()
    update_ammo_display()
    
    # Get object pool reference
    object_pool = get_node_or_null("/root/ObjectPool")
    if not object_pool:
        push_warning("WARNING: ObjectPool not found, will instantiate objects directly")

func update_ui_references():
    # Get UI references safely
    if not ammo_label:
        ammo_label = get_node_or_null("/root/Main/HUD/HealthBarContainer/AmmoLabel")
    
    if not reload_bar:
        reload_bar = get_node_or_null("/root/Main/HUD/HealthBarContainer/ReloadBar")

func _input(event):
    if not player or not is_instance_valid(player):
        return
        
    if event.is_action_pressed("reload") and can_reload and not is_reloading and current_magazine < max_magazine and current_reserve > 0:
        reload()

func _process(delta):
    if not player or not is_instance_valid(player):
        return
        
    # Handle shooting
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot and (current_magazine > 0 || player.god_mode) and not is_reloading:
        shoot()
    
    # Handle reload progress
    if is_reloading:
        reload_progress += delta
        
        if reload_bar:
            reload_bar.value = reload_progress
            
        if reload_progress >= reload_time:
            var ammo_needed = max_magazine - current_magazine
            var ammo_to_load = min(ammo_needed, current_reserve)
            current_magazine += ammo_to_load
            current_reserve -= ammo_to_load
            update_ammo_display()
            is_reloading = false
            can_reload = true
            
            if reload_bar:
                reload_bar.value = 0.0
                reload_bar.hide()

func shoot():
    if not is_instance_valid(player):
        return
        
    can_shoot = false
    if not player.god_mode:
        current_magazine -= 1
    update_ammo_display()
    
    # Get bullet from object pool if available, otherwise instantiate
    var bullet = null
    if object_pool:
        bullet = object_pool.get_object(bullet_scene_path)
    else:
        var bullet_scene = load(bullet_scene_path)
        if bullet_scene:
            bullet = bullet_scene.instantiate()
            player.get_parent().add_child(bullet)
        else:
            push_error("Failed to load bullet scene from: " + bullet_scene_path)
            can_shoot = true
            return
    
    if not bullet:
        push_error("Failed to get bullet instance")
        can_shoot = true
        return
        
    var gun_tip = player.get_node_or_null("Head/Camera3D/Gun/GunTip")
    if not gun_tip:
        push_error("Gun tip node not found")
        can_shoot = true
        return
        
    # Set bullet position and velocity
    bullet.global_transform.origin = gun_tip.global_transform.origin
    bullet.velocity = -player.get_node("Head/Camera3D").global_transform.basis.z * bullet_speed
    
    # Show muzzle flash
    var muzzle_flash = player.get_node_or_null("Head/Camera3D/Gun/MuzzleFlash")
    if muzzle_flash:
        muzzle_flash.visible = true
        
    var gunshot_player = player.get_node_or_null("Head/Camera3D/Gun/GunshotPlayer")
    if gunshot_player:
        gunshot_player.play()
    
    # Hide muzzle flash after duration
    if muzzle_flash:
        get_tree().create_timer(muzzle_flash_duration).timeout.connect(func():
            if is_instance_valid(muzzle_flash):
                muzzle_flash.visible = false
        )
    
    # Reset can_shoot after cooldown
    get_tree().create_timer(shoot_cooldown).timeout.connect(func():
        can_shoot = true
    )

func reload():
    if current_reserve <= 0 or current_magazine >= max_magazine or is_reloading or not is_instance_valid(player):
        return
        
    is_reloading = true
    can_reload = false
    reload_progress = 0.0
    
    if reload_bar:
        reload_bar.value = 0.0
        reload_bar.show()
    
    var reload_player = player.get_node_or_null("Head/Camera3D/Gun/ReloadPlayer")
    if reload_player:
        reload_player.play()

func _on_ammo_changed(amount, _reserve):
    current_reserve += amount
    current_reserve = clamp(current_reserve, 0, total_reserve_ammo)
    update_ammo_display()
    
    if ammo_label:
        ammo_label.add_theme_color_override("font_color", Color(0, 0, 1)) # Blue
        
        var ammo_sound = player.get_node_or_null("AmmoSound")
        if ammo_sound:
            ammo_sound.play()
        
        get_tree().create_timer(1.0).timeout.connect(func():
            if is_instance_valid(ammo_label):
                ammo_label.remove_theme_color_override("font_color") # Back to default
        )

func update_ammo_display():
    if not ammo_label:
        update_ui_references()
        
    if ammo_label:
        ammo_label.text = str(current_magazine) + "/" + str(current_reserve)
