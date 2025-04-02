extends Node

var player = null  # Will reference the parent player node

# Shooting variables
@export var bullet_scene_path : String = "res://bullet.tscn"
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

func _ready():
    current_magazine = max_magazine
    current_reserve = total_reserve_ammo
    
    update_ammo_display()
    
    # Get object pool reference
    object_pool = get_node_or_null("/root/ObjectPool")
    if not object_pool:
        print("WARNING: ObjectPool not found, will instantiate objects directly")

func _input(event):
    if not player:
        return
        
    if event.is_action_pressed("reload") and can_reload:
        reload()

func _process(delta):
    if not player:
        return
        
    # Handle shooting
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot and (current_magazine > 0 || player.god_mode) and not is_reloading:
        shoot()
    
    # Handle reload progress
    if is_reloading:
        reload_progress += delta
        
        var reload_bar = get_node_or_null("/root/Main/HUD/HealthBarContainer/ReloadBar")
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
        bullet = bullet_scene.instantiate()
        player.get_parent().add_child(bullet)
    
    bullet.global_transform.origin = player.get_node("Head/Camera3D/Gun/GunTip").global_transform.origin
    bullet.velocity = -player.get_node("Head/Camera3D").global_transform.basis.z * bullet_speed
    
    # Show muzzle flash
    player.get_node("Head/Camera3D/Gun/MuzzleFlash").visible = true
    player.get_node("Head/Camera3D/Gun/GunshotPlayer").play()
    
    # Hide muzzle flash after duration
    get_tree().create_timer(muzzle_flash_duration).timeout.connect(func():
        player.get_node("Head/Camera3D/Gun/MuzzleFlash").visible = false
    )
    
    # Reset can_shoot after cooldown
    get_tree().create_timer(shoot_cooldown).timeout.connect(func():
        can_shoot = true
    )

func reload():
    if current_reserve <= 0 or current_magazine >= max_magazine or is_reloading:
        return
        
    is_reloading = true
    can_reload = false
    reload_progress = 0.0
    
    var reload_bar = get_node_or_null("/root/Main/HUD/HealthBarContainer/ReloadBar")
    if reload_bar:
        reload_bar.value = 0.0
        reload_bar.show()
    
    player.get_node("Head/Camera3D/Gun/ReloadPlayer").play()

func _on_ammo_changed(amount, _reserve):
    current_reserve += amount
    current_reserve = clamp(current_reserve, 0, total_reserve_ammo)
    update_ammo_display()
    
    var ammo_label = get_node_or_null("/root/Main/HUD/HealthBarContainer/AmmoLabel")
    if ammo_label:
        ammo_label.add_theme_color_override("font_color", Color(0, 0, 1)) # Blue
        player.get_node("AmmoSound").play()
        
        get_tree().create_timer(1.0).timeout.connect(func():
            ammo_label.remove_theme_color_override("font_color") # Back to default
        )

func update_ammo_display():
    var ammo_label = get_node_or_null("/root/Main/HUD/HealthBarContainer/AmmoLabel")
    if ammo_label:
        ammo_label.text = str(current_magazine) + "/" + str(current_reserve)
