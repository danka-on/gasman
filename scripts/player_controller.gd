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

# Child component references
@onready var movement = $MovementComponent
@onready var weapons = $WeaponsComponent
@onready var health_system = $HealthComponent
@onready var pickup_handler = $PickupComponent

# UI references (will be set up by main scene)
var health_bar = null
var ammo_label = null
var gas_bar = null
var heal_border = null

func _ready():
    # Connect to UI elements
    health_bar = get_node_or_null("/root/Main/HUD/HealthBarContainer/HealthBar")
    ammo_label = get_node_or_null("/root/Main/HUD/HealthBarContainer/AmmoLabel")
    gas_bar = get_node_or_null("/root/Main/HUD/GasBar")
    heal_border = get_node_or_null("/root/Main/HUD/HealBorder")
    
    # Set up player state
    current_health = max_health
    
    # Prepare components
    initialize_components()
    
    # Set up collision
    collision_layer = 1
    collision_mask = 1 | 8 | 16
    
    # Capture mouse
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    
    # Join player group for easier reference
    add_to_group("player")

func initialize_components():
    # Set up references and data for child components
    if movement:
        movement.player = self
        
    if weapons:
        weapons.player = self
        connect("ammo_changed", weapons._on_ammo_changed)
        
    if health_system:
        health_system.player = self
        connect("player_took_damage", health_system._on_player_took_damage)
        connect("player_healed", health_system._on_player_healed)
        
    if pickup_handler:
        pickup_handler.player = self

func _input(event):
    # Handle mouse movement for camera
    if event is InputEventMouseMotion:
        $Head.rotate_y(-event.relative.x * mouse_sensitivity)
        $Head/Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
        $Head/Camera3D.rotation.x = clamp($Head/Camera3D.rotation.x, -1.5, 1.5)
    
    # Debug key to take damage
    if event is InputEventKey and event.pressed and event.keycode == KEY_H:
        take_damage(10.0)

func take_damage(amount: float):
    if god_mode and amount > 0:
        return
        
    current_health -= amount
    current_health = clamp(current_health, 0, max_health)
    
    if amount > 0:
        emit_signal("player_took_damage", amount)
    elif amount < 0:
        emit_signal("player_healed", -amount)
    
    # Update UI
    if health_bar:
        health_bar.value = current_health
    
    # Check for death
    if current_health <= 0:
        die()

func add_gas(amount: float):
    emit_signal("gas_changed", amount)
    
func add_ammo(amount: int):
    emit_signal("ammo_changed", amount, 0)

func add_score(points: int):
    score += points
    kills += 1
    emit_signal("score_changed", score)

func die():
    emit_signal("player_died")
    hide()
    set_physics_process(false)
    
    # Transition to game over
    var game_over = load("res://scenes/GameOver.tscn").instantiate()
    game_over.set_score_and_kills(score, kills)
    get_tree().root.add_child(game_over)
    get_tree().current_scene.queue_free()
    get_tree().current_scene = game_over

func play_hit_sound():
    if $HitSound:
        $HitSound.play()

func apply_knockback(direction: Vector3, force: float):
    if movement:
        movement.apply_knockback(direction, force)
