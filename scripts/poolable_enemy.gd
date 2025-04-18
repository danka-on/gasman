extends CharacterBody3D

class_name PoolableEnemy

signal died

@export var speed : float = 3.0
@export var max_health : float = 50.0
var current_health : float = max_health
var gravity : float = 9.8
var player = null

@export var damage : float = 10.0
@export var damage_cooldown : float = 1.0
var can_damage = true
var last_damage_time : float = 0.0

# Knockback variables
var knockback_velocity : Vector3 = Vector3.ZERO
var knockback_resistance : float = 0.9  # How quickly knockback wears off (0-1)
var knockback_recovery : float = 5.0    # How fast to recover from knockback

# Headshot variables
@export var headshot_multiplier : float = 2.0  # 200% damage for headshots

@export var gas_pack_scene : PackedScene = preload("res://scenes/gas_pack.tscn")
@export var health_pack_scene : PackedScene = preload("res://scenes/health_pack.tscn")
@export var ammo_pack_scene : PackedScene = preload("res://scenes/ammo_pack.tscn")
@export var explosion_scene : PackedScene = preload("res://scenes/PoolableExplosion.tscn")

@export var explosion_radius : float = 5.0 # Blast radius
@export var explosion_damage : float = 20.0 # Damage to player
@export var explosion_force : float = 10.0 # Knockback strength

@export var drop_chance : float = 0.5 # 50% chance to drop

var _id : int = 0
var _creation_time : float = 0.0
var _is_pooled : bool = false
var _signal_connections_setup : bool = false
var _is_dying : bool = false

# Statistics for pool usage
var _pool_retrieval_count : int = 0
var _last_pool_time : float = 0.0
var _total_active_time : float = 0.0

@onready var enemy_mesh = $EnemyMesh # Reference to mesh
@onready var hitbox = $Hitbox # Add reference
@onready var head_hitbox = $HeadHitbox # Add reference

func _ready():
    _id = get_instance_id()
    _creation_time = Time.get_ticks_msec() / 1000.0
    
    debug_print("Created at time: %.2f" % _creation_time)
    
    # Setup will be called in reset() when retrieved from pool
    # But if this is a direct instantiation, call setup now
    if not _is_pooled:
        reset()

## Reset the enemy for reuse from the pool
func reset():
    var reset_time = Time.get_ticks_msec() / 1000.0
    debug_print("Reset at time: %.2f (alive for %.2f seconds)" % 
        [reset_time, reset_time - _creation_time])
    
    # Track pool statistics
    _pool_retrieval_count += 1
    _last_pool_time = reset_time
    
    if _pool_retrieval_count > 1:
        debug_print("Enemy retrieved from pool %d times" % _pool_retrieval_count, DebugSettings.LogLevel.VERBOSE)
    
    # Reset position and transform
    transform = Transform3D.IDENTITY
    
    # Reset health and state
    current_health = max_health
    can_damage = true
    last_damage_time = 0.0
    knockback_velocity = Vector3.ZERO
    _is_dying = false
    
    # Reset visibility and physics
    visible = true
    set_physics_process(true)
    
    # Re-enable collision
    collision_layer = 1
    collision_mask = 1 | 8
    
    if hitbox:
        hitbox.collision_layer = 2
        hitbox.collision_mask = 4
    
    if head_hitbox:
        head_hitbox.collision_layer = 2
        head_hitbox.collision_mask = 4
    
    # Setup basic requirements
    setup_requirements()
    
    # Update material color based on health
    update_color()
    
    debug_print("Enemy reset complete, ready for use")

func setup_requirements():
    # Add to group for gas cloud detection
    if not is_in_group("enemy"):
        add_to_group("enemy")
    
    # Setup signal connections
    setup_signal_connections()

func setup_signal_connections():
    if not _signal_connections_setup:
        if hitbox and not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
            hitbox.body_entered.connect(_on_hitbox_body_entered)
        
        _signal_connections_setup = true
        debug_print("Signal connections established", DebugSettings.LogLevel.VERBOSE)

func cleanup_signal_connections():
    if _signal_connections_setup:
        if hitbox and hitbox.body_entered.is_connected(_on_hitbox_body_entered):
            hitbox.body_entered.disconnect(_on_hitbox_body_entered)
        
        _signal_connections_setup = false
        debug_print("Signal connections cleaned up", DebugSettings.LogLevel.VERBOSE)

func _physics_process(delta):
    if _is_dying:
        return
        
    if enemy_mesh and enemy_mesh.material_override: # Safe check
        update_color() # Initial update here
        
    if not is_on_floor():
        velocity.y -= gravity * delta
    
    # Apply knockback recovery
    if knockback_velocity.length() > 0:
        velocity = knockback_velocity
        knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_resistance * delta)
        if knockback_velocity.length() < 0.1:
            knockback_velocity = Vector3.ZERO
    # Only move towards player if not being knocked back
    elif player:
        var direction = (player.global_transform.origin - global_transform.origin).normalized()
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = 0
        velocity.z = 0
    
    # Handle damage to player
    if is_instance_valid(player) and current_health > 0:
        for i in get_slide_collision_count():
            var collision = get_slide_collision(i)
            if is_instance_valid(collision):
                var collider = collision.get_collider()
                if is_instance_valid(collider) and collider == player and can_damage:
                    if Time.get_ticks_msec() / 1000.0 - last_damage_time >= damage_cooldown:
                        player.take_damage(damage)
                        last_damage_time = Time.get_ticks_msec() / 1000.0
                        can_damage = false
                        await get_tree().create_timer(damage_cooldown).timeout
                        can_damage = true

    move_and_slide()

func take_damage(amount: float, is_gas_damage: bool = false, is_headshot: bool = false):
    debug_print("Taking damage: %.2f (Gas: %s, Headshot: %s)" % [amount, str(is_gas_damage), str(is_headshot)])
    
    var final_damage = amount
    if is_headshot:
        final_damage *= headshot_multiplier
        debug_print("HEADSHOT! Damage multiplied to %.2f" % final_damage)
    
    current_health -= final_damage
    current_health = clamp(current_health, 0, max_health)
    
    debug_print("Health reduced to %.2f/%.2f" % [current_health, max_health])
    
    # Spawn damage number with appropriate color
    var damage_number = null
    if PoolSystem.has_pool("damage_numbers"):
        damage_number = PoolSystem.get_object(PoolSystem.PoolType.DAMAGE_NUMBER)
    
    if not damage_number:
        damage_number = preload("res://scenes/damage_number.tscn").instantiate()
        debug_print("Created new damage number (not from pool)")
    else:
        debug_print("Got damage number from pool")
    
    damage_number.text = str(int(final_damage))
    
    # Set color based on damage type
    if is_headshot:
        damage_number.color = Color(1, 0, 0)  # Red for headshots
    elif is_gas_damage:
        if amount >= 20:  # Assuming explosion damage is higher than tick damage
            damage_number.color = Color(1, 0, 0)  # Red for gas explosions
        else:
            damage_number.color = Color(0, 1, 0)  # Green for gas tick damage
    else:
        damage_number.color = Color(1, 1, 1)  # White for normal bullet hits
    
    damage_number.spawn_height_offset = 2.5  # Set the spawn height offset
    damage_number.position = global_transform.origin + Vector3(0, damage_number.spawn_height_offset, 0)
    get_parent().add_child(damage_number)
    
    # Only trigger hit feedback for non-gas damage
    if !is_gas_damage:
        if player and player.has_method("play_hit_sound"):
            player.play_hit_sound()
            
    if enemy_mesh and enemy_mesh.material_override:
        update_color()
        
    if current_health <= 0 and not _is_dying:
        die()

func die():
    if _is_dying:
        debug_print("Die called but already dying, ignoring")
        return
        
    _is_dying = true
    debug_print("Enemy dying at position: %s" % str(global_transform.origin))
    
    # Emit died signal before processing death
    died.emit(self) # Pass self reference to signal handlers
    
    # Make enemy invisible immediately
    visible = false
    
    if player:
        debug_print("Awarding score to player")
        player.add_score(5)
        if randf() < drop_chance:
            debug_print("Dropping item (chance: %.2f)" % drop_chance)
            var drop_options = [health_pack_scene, ammo_pack_scene, gas_pack_scene]
            var drop = drop_options[randi() % drop_options.size()]
            var instance = drop.instantiate()
            instance.global_transform.origin = global_transform.origin + Vector3(0, 1, 0)
            get_parent().add_child(instance)
    
    # Create explosion via pool
    var explosion = null
    var explosion_id = -1
    var from_pool = false
    
    # Use pooling system for explosion if available
    if PoolSystem.has_pool("explosions"):
        debug_print("Explosions pool exists, attempting to get object")
        explosion = PoolSystem.get_object(PoolSystem.PoolType.EXPLOSION)
        if explosion:
            explosion_id = explosion.get_instance_id()
            from_pool = true
            debug_print("Got explosion ID:%d from pool for enemy death" % explosion_id)
            
            # Log to DebugSettings if available
            if has_node("/root/DebugSettings"):
                DebugSettings.log_info("pools", "Enemy ID:%d successfully got explosion ID:%d from pool" % 
                    [_id, explosion_id])
    
    # If no pool or couldn't get from pool, instantiate manually
    if explosion == null and explosion_scene:
        explosion = explosion_scene.instantiate()
        explosion_id = explosion.get_instance_id()
        debug_print("Created new explosion (not from pool) for enemy death")
        
        # Log to DebugSettings if available
        if has_node("/root/DebugSettings"):
            DebugSettings.log_warning("pools", "Enemy ID:%d had to create new explosion (pool miss)" % _id)
    
    # Set up the explosion
    if explosion:
        # Add explosion to scene at current position
        var parent = get_parent()
        debug_print("Adding explosion ID:%d to parent ID:%d" % [explosion_id, parent.get_instance_id()])
        parent.add_child(explosion)
        explosion.global_transform.origin = global_transform.origin
        
        # Check if player is within the blast radius
        if player:
            var distance = global_transform.origin.distance_to(player.global_transform.origin)
            debug_print("Player distance from explosion: %.2f (radius: %.2f)" % [distance, explosion_radius])
            
            if distance < explosion_radius:
                debug_print("Player in explosion radius, applying effects")
                var immune = player.has_method("is_immune") and player.is_immune()
                
                if not immune:
                    debug_print("Player not immune, applying %.2f damage" % explosion_damage)
                    player.take_damage(explosion_damage)
                else:
                    debug_print("Player immune to explosion damage, only applying knockback")
                
                # Calculate knockback direction
                var knockback_dir = (player.global_transform.origin - global_transform.origin).normalized()
                knockback_dir.y = -knockback_dir.y  # Reverse y to create upward force
                debug_print("Applied knockback in direction: %s with force: %.2f" % [str(knockback_dir), explosion_force])
                
                # Pass direction and force as separate parameters
                if player.has_method("apply_knockback"):
                    player.apply_knockback(knockback_dir, explosion_force)
    
    # Disable physics and collision to prevent further interactions
    debug_print("Disabling physics and hitbox")
    set_physics_process(false)
    collision_layer = 0
    collision_mask = 0
    
    if hitbox:
        hitbox.collision_layer = 0
        hitbox.collision_mask = 0
    
    if head_hitbox:
        head_hitbox.collision_layer = 0
        head_hitbox.collision_mask = 0
    
    # Calculate active time statistics
    var current_time = Time.get_ticks_msec() / 1000.0
    _total_active_time += (current_time - _last_pool_time)
    
    # We'll return to pool after a short delay to allow explosion effect to happen
    debug_print("Starting queue_free delay timer (0.2 seconds)")
    await get_tree().create_timer(0.2).timeout
    debug_print("Delay complete, preparing for pool")
    
    # Return to pool if we're in one, otherwise queue_free
    prepare_for_pool()

func _on_hitbox_body_entered(body):
    if body == player and can_damage and not _is_dying:
        player.take_damage(damage)
        can_damage = false
        if is_inside_tree():
            await get_tree().create_timer(damage_cooldown).timeout
        can_damage = true

func update_color():
    var new_material = enemy_mesh.material_override.duplicate()
    if current_health <= 10.0:
        new_material.albedo_color = Color(1, 0, 0, 1) # Red
        new_material.emission_enabled = true
        new_material.emission = Color(1, 0, 0, 1) # Red glow
        new_material.emission_energy = 2.0 # Glow intensity
    else:
        new_material.albedo_color = Color(0, 0.5, 0.5, 1) # Teal
        new_material.emission_enabled = false # No glow
    enemy_mesh.material_override = new_material

func apply_knockback(direction_or_force, force = null):
    var knockback_force: Vector3
    if force != null:
        # If we received direction and force separately
        knockback_force = direction_or_force * force
    else:
        # If we received the force vector directly
        knockback_force = direction_or_force
    
    debug_print("Received knockback force: %s" % str(knockback_force))
    knockback_velocity = knockback_force
    # Add a slight upward force to make it look more dramatic
    knockback_velocity.y += 2.0

## Called when the enemy is returned to the pool
func prepare_for_pool():
    var current_time = Time.get_ticks_msec() / 1000.0
    debug_print("Prepared for pool at time: %.2f (used for %.2f seconds)" % 
        [current_time, current_time - _last_pool_time])
    
    # Clean up signal connections
    cleanup_signal_connections()
    
    if PoolSystem and PoolSystem.has_pool("enemies"):
        debug_print("Releasing to pool system")
        PoolSystem.release_object(self)
    else:
        debug_print("No pool available, calling queue_free")
        queue_free()

func debug_print(message: String, level: int = DebugSettings.LogLevel.INFO) -> void:
    # Format the message with the object ID
    var formatted_message = "ID:%d - %s" % [_id, message]
    
    # Print to console with prefix
    print("[ENEMY_DEBUG] %s" % formatted_message)
    
    # Send to central debug system if available
    if has_node("/root/DebugSettings"):
        DebugSettings.debug_print("enemies", formatted_message, level)

# Report detailed statistics about this enemy's pool usage
func report_pool_stats() -> String:
    var stats = "Enemy ID:%d Pool Stats:\n" % _id
    stats += "- Created at: %.2f seconds\n" % _creation_time
    stats += "- Pool retrievals: %d times\n" % _pool_retrieval_count
    stats += "- Total active time: %.2f seconds\n" % _total_active_time
    
    if _pool_retrieval_count > 0:
        stats += "- Average time per retrieval: %.2f seconds\n" % (_total_active_time / _pool_retrieval_count)
    
    return stats 
