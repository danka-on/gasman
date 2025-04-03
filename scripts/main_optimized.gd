extends Node3D

@export var enemy_scene : PackedScene = preload("res://scenes/enemy.tscn")
@export var spawn_radius : float = 10.0
@onready var player = $Player
@onready var spawn_timer = $EnemySpawnTimer
@onready var enemy_count_label = $HUD/HealthBarContainer/EnemyCountLabel
var enemy_count = 0

# Scenes to initialize in the object pool
@export var bullet_scene : String = "res://scenes/bullet.tscn"
@export var hit_effect_scene : String = "res://scenes/hit_effect.tscn"
@export var explosion_scene : String = "res://scenes/Explosion.tscn"
@export var health_pack_scene : String = "res://scenes/health_pack.tscn"
@export var ammo_pack_scene : String = "res://scenes/ammo_pack.tscn"
@export var gas_pack_scene : String = "res://scenes/gas_pack.tscn"

# Object pool parameters
@export var bullet_pool_size : int = 30
@export var effect_pool_size : int = 10
@export var pickup_pool_size : int = 5

# Spatial partitioning for better performance
var active_cells = {}
var cell_size = 10.0  # Size of each spatial partition cell

func _ready():
    # Create ObjectPool if it doesn't exist
    if not has_node("/root/ObjectPool"):
        push_warning("ObjectPool autoload not found, creating manually...")
        var object_pool_script = load("res://scripts/object_pool.gd")
        var object_pool = object_pool_script.new()
        object_pool.name = "ObjectPool"
        get_node("/root").add_child(object_pool)
    
    # Initialize object pool
    var object_pool = get_node_or_null("/root/ObjectPool")
    if object_pool:
        # Initialize pools for commonly used objects
        object_pool.initialize_pool(bullet_scene, bullet_pool_size)
        object_pool.initialize_pool(hit_effect_scene, effect_pool_size)
        object_pool.initialize_pool(explosion_scene, effect_pool_size)
        object_pool.initialize_pool(health_pack_scene, pickup_pool_size)
        object_pool.initialize_pool(ammo_pack_scene, pickup_pool_size)
        object_pool.initialize_pool(gas_pack_scene, pickup_pool_size)
    else:
        push_error("Failed to get or create ObjectPool!")
    
    # Set up enemy spawning
    spawn_timer.wait_time = 1.0
    if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
        spawn_timer.timeout.connect(_on_spawn_timer_timeout)
    spawn_timer.start()
    
    # Connect to player signals
    if player and player.has_signal("player_died") and not player.player_died.is_connected(_on_player_died):
        player.connect("player_died", _on_player_died)

func _physics_process(_delta):
    # Spatial partitioning update
    update_spatial_partitioning()
    
    # Optimize enemy processing based on distance to player
    optimize_enemy_processing()

func _on_spawn_timer_timeout():
    if enemy_count < 50:
        spawn_enemy()
        
func update_enemy_count():
    if enemy_count_label:
        enemy_count_label.text = "Enemies: " + str(enemy_count)

func _on_enemy_died():
    enemy_count -= 1
    update_enemy_count()

func spawn_enemy():
    if not is_instance_valid(player):
        return
        
    var enemy = enemy_scene.instantiate()
    if not enemy:
        push_error("Failed to instantiate enemy scene!")
        return
        
    add_child(enemy)
    
    # Find a valid spawn position that's not too close to the player
    var valid_position = false
    var spawn_pos = Vector3.ZERO
    var min_player_distance = spawn_radius * 0.25  # Don't spawn too close to player
    var max_attempts = 10
    var attempts = 0
    
    while not valid_position and attempts < max_attempts:
        var random_angle = randf() * 2 * PI
        var random_distance = randf_range(spawn_radius * 0.5, spawn_radius)
        var spawn_x = cos(random_angle) * random_distance
        var spawn_z = sin(random_angle) * random_distance
        
        spawn_pos = Vector3(spawn_x, 1.5, spawn_z)
        var distance_to_player = spawn_pos.distance_to(player.global_transform.origin)
        
        if distance_to_player >= min_player_distance:
            valid_position = true
        
        attempts += 1
    
    enemy.global_transform.origin = spawn_pos
    enemy.player = player
    enemy_count += 1
    
    # Connect to enemy signals with error handling
    if enemy.has_signal("tree_exited") and not enemy.tree_exited.is_connected(_on_enemy_died):
        enemy.tree_exited.connect(_on_enemy_died)
        
    if enemy.has_signal("enemy_died") and not enemy.enemy_died.is_connected(_on_enemy_died):
        enemy.enemy_died.connect(_on_enemy_died)
    
    update_enemy_count()
    
    # Register enemy in spatial partitioning
    var cell_coords = get_cell_coordinates(enemy.global_transform.origin)
    add_to_cell(cell_coords, enemy)

func _on_player_died():
    # Cleanup or pause game logic as needed
    spawn_timer.stop()

func update_spatial_partitioning():
    if not is_instance_valid(player):
        return
        
    # Clear the active cells data structure before the update
    active_cells.clear()
    
    # Re-register all enemies in their current cells
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(enemy) and enemy.visible:
            var cell_coords = get_cell_coordinates(enemy.global_transform.origin)
            add_to_cell(cell_coords, enemy)

func get_cell_coordinates(position: Vector3) -> Vector3:
    # Convert world position to cell coordinates
    var x = floor(position.x / cell_size)
    var y = floor(position.y / cell_size)
    var z = floor(position.z / cell_size)
    return Vector3(x, y, z)

func add_to_cell(cell_coords: Vector3, object):
    # Add an object to a specific cell
    if not active_cells.has(cell_coords):
        active_cells[cell_coords] = []
    active_cells[cell_coords].append(object)

func optimize_enemy_processing():
    if not is_instance_valid(player):
        return
        
    var player_cell = get_cell_coordinates(player.global_transform.origin)
    
    # Process enemies based on distance to player
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(enemy) or not enemy.visible:
            continue
            
        var enemy_cell = get_cell_coordinates(enemy.global_transform.origin)
        var cell_distance = (enemy_cell - player_cell).length()
        
        # Only let enemies in nearby cells actively chase
        if cell_distance <= 2:  # Active range in cells
            enemy.set_physics_process(true)
        else:
            # Distant enemies process less frequently
            enemy.set_physics_process(enemy.update_tick == 0)
