extends CharacterBody3D

signal player_died
signal player_took_damage(amount)
signal player_healed(amount)
signal score_changed(new_score)
signal gas_changed(new_amount)
signal ammo_changed(current_mag, reserve)

# Core Player Variables
@export var god_mode : bool = false # God Mode toggle in Inspector
@export var mouse_sensitivity : float = 0.002
@export var max_health : float = 100.0
var current_health : float = max_health

# Score and kills tracking
var score : int = 0
var kills : int = 0

# Child component references - using @onready for proper initialization
@onready var movement = $MovementComponent
@onready var weapons = $WeaponsComponent
@onready var health_system = $HealthComponent
@onready var pickup_handler = $PickupComponent

# UI references
var health_bar = null
var ammo_label = null
var gas_bar = null
var heal_border = null

# Spawn effect properties
@export var explosion_scene : String = "res://scenes/Explosion.tscn"
@export var enable_spawn_effect : bool = true  # Can be toggled in the Inspector
@export var play_spawn_sounds : bool = false   # Set to false to disable all spawn sounds

# Debug flag
var debug_player = false

func _ready():
    print("Player Controller: Ready called")
    
    # Set up player state
    current_health = max_health
    
    # Connect to UI elements - added null checks
    update_ui_references()
    
    # Set up collision properly
    collision_layer = 1     # Player layer
    collision_mask = 1 | 2  # Floor/Environment and enemy layers
    
    print("Player Controller: Collision layers set to ", collision_layer, " mask: ", collision_mask)
    
    # Play spawn effect - with a slight delay to ensure everything is loaded
    if enable_spawn_effect:
        get_tree().create_timer(0.1).timeout.connect(play_spawn_effect)
    
    # Capture mouse
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    
    # Join player group for easier reference
    add_to_group("player")
    
    # Initialize components after a short delay to ensure everything is ready
    get_tree().create_timer(0.1).timeout.connect(initialize_components)

func play_spawn_effect():
    # Only play this if enabled
    if not enable_spawn_effect:
        return
        
    # Create a spawn-in explosion effect
    var object_pool = get_node_or_null("/root/ObjectPool")
    if object_pool and is_instance_valid(self):
        var explosion = object_pool.get_object(explosion_scene)
        if explosion:
            # Position at player's feet for better effect
            explosion.global_transform.origin = global_transform.origin - Vector3(0, 0.5, 0)
            
            # Mute sounds if needed
            if not play_spawn_sounds:
                for child in explosion.get_children():
                    if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
                        child.volume_db = -80  # Effectively muted
            
            print("Player Controller: Played spawn effect")

func initialize_components():
    print("Player Controller: Initializing components")
    # Set up references and data for child components
    if movement:
        movement.player = self
        # Connect gas signal
        if not gas_changed.is_connected(movement.add_gas):
            connect("gas_changed", movement.add_gas)
        print("Player Controller: Movement component initialized")
    else:
        print("Player Controller: ERROR - Movement component not found!")
        
    if weapons:
        weapons.player = self
        if not ammo_changed.is_connected(weapons._on_ammo_changed):
            connect("ammo_changed", weapons._on_ammo_changed)
        print("Player Controller: Weapons component initialized")
    else:
        print("Player Controller: ERROR - Weapons component not found!")
        
    if health_system:
        health_system.player = self
        if not player_took_damage.is_connected(health_system._on_player_took_damage):
            connect("player_took_damage", health_system._on_player_took_damage)
        if not player_healed.is_connected(health_system._on_player_healed):
            connect("player_healed", health_system._on_player_healed)
        print("Player Controller: Health component initialized")
    else:
        print("Player Controller: ERROR - Health component not found!")
        
    if pickup_handler:
        pickup_handler.player = self
        print("Player Controller: Pickup component initialized")
    else:
        print("Player Controller: ERROR - Pickup component not found!")
        
    # Verify all UI connections
    update_ui_references()

func update_ui_references():
    # Get latest UI references if they were null before
    if not health_bar:
        health_bar = get_node_or_null("/root/Main/HUD/HealthBarContainer/HealthBar")
        if health_bar:
            health_bar.value = current_health
    
    if not gas_bar:
        gas_bar = get_node_or_null("/root/Main/HUD/GasBar")
        
    if not ammo_label:
        ammo_label = get_node_or_null("/root/Main/HUD/HealthBarContainer/AmmoLabel")
        
    if not heal_border:
        heal_border = get_node_or_null("/root/Main/HUD/HealBorder")

func _input(event):
    # Only process if we're valid
    if not is_inside_tree() or not visible:
        return
        
    # Handle mouse movement for camera
    if event is InputEventMouseMotion:
        var head = get_node_or_null("Head")
        var camera = head.get_node_or_null("Camera3D") if head else null
        
        if head and camera:
            head.rotate_y(-event.relative.x * mouse_sensitivity)
            camera.rotate_x(-event.relative.y * mouse_sensitivity)
            camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)
    
    # Debug key to take damage - only in debug builds
    if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_H:
        print("Player Controller: Taking 10 damage from debug key")
        take_damage(10.0)

func _physics_process(delta):
    # Ensure we have components
    if not movement or not weapons or not health_system:
        push_error("Critical component missing on player!")
        return
        
    # Check for player pause/menu input
    if Input.is_action_just_pressed("ui_cancel"):
        if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    
    # IMPORTANT: Make sure we're actually calling move_and_slide()
    move_and_slide()
    
    if debug_player and Engine.get_frames_drawn() % 60 == 0:  # Log every 60 frames to reduce spam
        print("Player Controller: health=", current_health, " position=", global_transform.origin)

func take_damage(amount: float):
    if not is_instance_valid(self):
        return
    
    print("Player Controller: take_damage called with amount: ", amount)
        
    if god_mode and amount > 0:
        print("Player Controller: God mode active, ignoring damage")
        return
        
    current_health -= amount
    current_health = clamp(current_health, 0, max_health)
    
    print("Player Controller: Health after damage: ", current_health)
    
    # Emit appropriate signal based on damage type
    if amount > 0:
        emit_signal("player_took_damage", amount)
    elif amount < 0:
        emit_signal("player_healed", abs(amount))
    
    # Update UI
    if health_bar:
        health_bar.value = current_health
    else:
        print("Player Controller: Health bar not found!")
        update_ui_references()  # Try to get UI references again
    
    # Play damage sound directly to ensure it happens
    if amount > 0:
        var damage_sound = get_node_or_null("DamageSound")
        if damage_sound:
            damage_sound.play()
    
    # Check for death
    if current_health <= 0:
        print("Player Controller: Health <= 0, calling die()")
        die()

func add_gas(amount: float):
    if not is_instance_valid(self):
        return
        
    emit_signal("gas_changed", amount)
    
func add_ammo(amount: int):
    if not is_instance_valid(self):
        return
        
    emit_signal("ammo_changed", amount, 0)

func add_score(points: int):
    if not is_instance_valid(self):
        return
        
    score += points
    kills += 1
    emit_signal("score_changed", score)

func die():
    if not is_instance_valid(self):
        return
    
    print("Player Controller: Player died!")
        
    emit_signal("player_died")
    hide()
    set_physics_process(false)
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    
    # Transition to game over with error handling
    var game_over_scene = load("res://scenes/GameOver.tscn")
    if game_over_scene:
        var game_over = game_over_scene.instantiate()
        if game_over:
            game_over.set_score_and_kills(score, kills)
            get_tree().root.add_child(game_over)
            
            # Only queue free the current scene if we successfully added game over
            if get_tree().current_scene:
                get_tree().current_scene.queue_free()
            get_tree().current_scene = game_over
        else:
            push_error("Failed to instantiate GameOver scene")
    else:
        push_error("Failed to load GameOver scene")

func play_hit_sound():
    if not is_instance_valid(self):
        return
        
    var hit_sound = get_node_or_null("HitSound")
    if hit_sound:
        hit_sound.play()

func apply_knockback(direction: Vector3, force: float):
    if not is_instance_valid(self) or not movement:
        return
        
    movement.apply_knockback(direction, force)
