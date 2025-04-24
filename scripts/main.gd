extends Node3D

@export var enemy_scene : PackedScene = preload("res://scenes/PoolableEnemy.tscn")
@export var spawn_radius : float = 10.0
@onready var player = $Player
@onready var spawn_timer = $EnemySpawnTimer
@onready var stats_timer = $StatsTimer
var enemy_count = 0

func _ready():
    # Set global debug based on player's debug_mode
    if has_node("/root/DebugSettings"):
        DebugSettings.toggle_debug("all", player.debug_mode)
    # Enable enemy debugging only if player has debugging mode enabled
    if has_node("/root/DebugSettings") and player and player.debug_mode:
        DebugSettings.toggle_debug("enemies", true)
        DebugSettings.toggle_debug("main_debug", true)
        DebugSettings.debug_print("enemies", "Main scene initialized enemy spawning")
    
    spawn_timer.wait_time = 0.10
    spawn_timer.connect("timeout", _on_spawn_timer_timeout)
    spawn_timer.start()
    
    # Initialize stats collection timer
    if has_node("StatsTimer"):
        stats_timer.wait_time = 10.0 # Collect stats every 10 seconds
        stats_timer.connect("timeout", _on_stats_timer_timeout)
        stats_timer.start()
        DebugSettings.debug_print("main_debug", "Stats timer started with interval: %s" % str(stats_timer.wait_time))
    else:
        DebugSettings.debug_print("main_debug", "No StatsTimer found, stats collection disabled")
    
    # Log initial setup
    DebugSettings.debug_print("main_debug", "Spawn timer started with interval: %s" % str(spawn_timer.wait_time))
    DebugSettings.debug_print("main_debug", "Spawn radius: %s" % str(spawn_radius))

func _on_spawn_timer_timeout():
    if enemy_count < 250:
        spawn_enemy()
        
func update_enemy_count():
    if player and player.get_node("HUD/HealthBarContainer/EnemyCountLabel"):
        player.get_node("HUD/HealthBarContainer/EnemyCountLabel").text = "Enemies: " + str(enemy_count)

func _on_enemy_died(enemy = null):
    enemy_count -= 1
    update_enemy_count()
    
    # Check if enemy is passed and is PoolableEnemy
    if enemy and enemy is PoolableEnemy:
        DebugSettings.debug_print("main_debug", "PoolableEnemy died, will be prepared for pool automatically")
        
        # Log to DebugSettings if available
        if has_node("/root/DebugSettings"):
            DebugSettings.debug_print("enemies", "Enemy ID:%d died (poolable)" % enemy.get_instance_id())
    else:
        DebugSettings.debug_print("main_debug", "Enemy died. Enemy count: %d" % enemy_count)
        
        # Log to DebugSettings if available
        if has_node("/root/DebugSettings"):
            if enemy:
                DebugSettings.debug_print("enemies", "Enemy ID:%d died (non-poolable)" % enemy.get_instance_id())
            else:
                DebugSettings.debug_print("enemies", "Unknown enemy died")

func spawn_enemy():
    var spawn_start_time = Time.get_ticks_msec()
    
    # Try to get an enemy from the pool first
    var enemy = null
    var from_pool = false
    var enemy_id = -1
    
    # Check if our scene reference is a PoolableEnemy
    var is_poolable_scene = enemy_scene.resource_path.find("Poolable") >= 0
    
    if is_poolable_scene and PoolSystem.has_pool("enemies"):
        DebugSettings.debug_print("main_debug", "Using poolable enemy system")
        DebugSettings.debug_print("main_debug", "Enemies pool exists, attempting to get object")
        
        # Debug print pool info
        var pool = PoolSystem.get_pool("enemies")
        if pool:
            DebugSettings.debug_print("main_debug", "Enemy pool stats - Available: %d, Active: %d, Total: %d" % [
                pool._available_objects.size(),
                pool._active_objects.size(),
                pool._available_objects.size() + pool._active_objects.size()
            ])
        
        enemy = PoolSystem.get_object(PoolSystem.PoolType.POOLABLE_ENEMY)
        if enemy:
            enemy_id = enemy.get_instance_id()
            from_pool = true
            DebugSettings.debug_print("main_debug", "Got enemy ID:%d from pool" % enemy_id)
            
            # Log to DebugSettings if available
            if has_node("/root/DebugSettings"):
                DebugSettings.debug_print("pools", "Main successfully got enemy ID:%d from pool" % enemy_id)
        else:
            DebugSettings.debug_print("main_debug", "Failed to get enemy from pool (returned null)")
            
            # Log to DebugSettings if available
            if has_node("/root/DebugSettings"):
                DebugSettings.debug_print("pools", "Main failed to get enemy from pool", DebugSettings.LogLevel.WARNING)
    elif is_poolable_scene:
        DebugSettings.debug_print("main_debug", "Using poolable scene but enemies pool does not exist!")
        
        # Log to DebugSettings if available
        if has_node("/root/DebugSettings"):
            DebugSettings.debug_print("pools", "Main found no enemies pool", DebugSettings.LogLevel.ERROR)
    else:
        DebugSettings.debug_print("main_debug", "Using regular (non-poolable) enemy scene")
    
    # If no pooled enemy is available, instantiate one
    if enemy == null:
        DebugSettings.debug_print("main_debug", "Creating new enemy (from scene: %s)" % enemy_scene.resource_path)
        enemy = enemy_scene.instantiate()
        enemy_id = enemy.get_instance_id()
        
        # Log stats to DebugSettings
        if has_node("/root/DebugSettings"):
            if is_poolable_scene:
                DebugSettings.debug_print("pools", "Main created new enemy ID:%d (pool bypass)" % 
                    enemy_id, DebugSettings.LogLevel.WARNING)
            else:
                DebugSettings.debug_print("pools", "Main created regular enemy ID:%d" % enemy_id)
    
    # At this point, we should have an enemy (pooled or new)
    if enemy:
        add_child(enemy)
        
        # Calculate spawn position
        var random_angle = randf() * 2 * PI
        var random_distance = randf_range(spawn_radius * 0.5, spawn_radius)
        var spawn_x = cos(random_angle) * random_distance
        var spawn_z = sin(random_angle) * random_distance
        
        # Set position and player reference
        enemy.global_transform.origin = Vector3(spawn_x, 1.5, spawn_z)
        enemy.player = player
        
        # Connect signals based on enemy type
        if enemy.has_signal("died") and not enemy.is_connected("died", _on_enemy_died):
            DebugSettings.debug_print("main_debug", "Connecting to died signal (poolable enemy)")
            enemy.connect("died", _on_enemy_died)
        elif not from_pool and not enemy.is_connected("tree_exited", _on_enemy_died):
            # Fallback for non-poolable enemy
            DebugSettings.debug_print("main_debug", "Connecting to tree_exited signal (regular enemy)")
            enemy.connect("tree_exited", _on_enemy_died)
            
        # Update counter    
        enemy_count += 1
        update_enemy_count()
        
        # Debug time
        var spawn_duration = Time.get_ticks_msec() - spawn_start_time
        DebugSettings.debug_print("main_debug", "Enemy spawned at position: %s" % str(Vector3(spawn_x, 1.5, spawn_z)))
        DebugSettings.debug_print("main_debug", "Spawn process took: %d ms" % spawn_duration)
        DebugSettings.debug_print("main_debug", "Current enemy count: %d" % enemy_count)
        
        # Log to DebugSettings if available
        if has_node("/root/DebugSettings"):
            DebugSettings.debug_print("enemies", "Spawned enemy ID:%d at %s (from_pool: %s)" % 
                [enemy_id, str(Vector3(spawn_x, 1.5, spawn_z)), str(from_pool)])
    else:
        DebugSettings.debug_print("main_debug", "ERROR: Failed to create enemy!")
        
        # Log error to DebugSettings
        if has_node("/root/DebugSettings"):
            DebugSettings.debug_print("enemies", "Failed to create enemy!", DebugSettings.LogLevel.ERROR)

func _on_stats_timer_timeout():
    # Collect and report enemy stats
    if has_node("/root/DebugSettings"):
        DebugSettings.debug_print("main_debug", "Collecting enemy pool statistics...")
        
        # Find all active enemies in the scene
        var enemies = []
        var children = get_children()
        for child in children:
            if child is PoolableEnemy:
                enemies.append(child)
                
        # Log statistics
        if enemies.size() > 0:
            DebugSettings.debug_print("main_debug", "Found %d active poolable enemies" % enemies.size())
            DebugSettings.log_enemy_stats(enemies)
            
            # Also print pool stats from the pool system
            if PoolSystem:
                PoolSystem.print_all_pool_stats()
        else:
            DebugSettings.debug_print("main_debug", "No active poolable enemies found")
            
  
