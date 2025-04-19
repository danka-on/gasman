extends CharacterBody3D

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
@export var explosion_scene : PackedScene = preload("res://scenes/Explosion.tscn")

@export var explosion_radius : float = 5.0 # Blast radius
@export var explosion_damage : float = 20.0 # Damage to player
@export var explosion_force : float = 10.0 # Knockback strength

@export var drop_chance : float = 0.5 # 50% chance to drop

@onready var enemy_mesh = $EnemyMesh # Reference to mesh
@onready var hitbox = $Hitbox # Add reference

func _ready():
    
    # Add to group for gas cloud detection
    add_to_group("enemy")
    
    # Set collision properties
    collision_layer = 1
    collision_mask = 1 | 8
    
    current_health = max_health
    if enemy_mesh:
        # Ensure material override exists
        if not enemy_mesh.material_override:
            enemy_mesh.material_override = StandardMaterial3D.new()
        # Clear surface material if present
        if enemy_mesh.get_surface_override_material(0):
            enemy_mesh.set_surface_override_material(0, null)
        update_color()
    else:
        print("Ready - EnemyMesh missing: ", enemy_mesh)
        
func _physics_process(delta):
    
           
    
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
    var final_damage = amount
    if is_headshot:
        final_damage *= headshot_multiplier
        print("HEADSHOT! Damage multiplied by ", headshot_multiplier)
    
    current_health -= final_damage
    current_health = clamp(current_health, 0, max_health)
    print("enemy TOOK ", final_damage, " damage")
    
    # Spawn damage number with appropriate color
    var damage_number = null
    if PoolSystem.has_pool("damage_numbers"):
        damage_number = PoolSystem.get_object(PoolSystem.PoolType.DAMAGE_NUMBER)
    
    if not damage_number:
        damage_number = preload("res://scenes/damage_number.tscn").instantiate()
        if DebugSettings and DebugSettings.is_debug_enabled("pools"):
            DebugSettings.log_warning("pools", "Enemy created new damage number (not from pool)")
    else:
        if DebugSettings and DebugSettings.is_debug_enabled("pools"):
            DebugSettings.log_debug("pools", "Enemy got damage number from pool")
        
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
    damage_number.display()  # Call the display method to start the animation
    
    # Only trigger hit feedback for non-gas damage
    if !is_gas_damage:
        if player and player.has_method("play_hit_sound"):
            player.play_hit_sound()
    if enemy_mesh and enemy_mesh.material_override:
        update_color()
    else:
        print("Take damage - EnemyMesh issue: ", enemy_mesh, " Material: ", enemy_mesh.material_override if enemy_mesh else "null")
    if current_health <= 0:
        die()

func die():
    var enemy_id = get_instance_id()
    print("[ENEMY_DEBUG] ID:%d - Enemy dying at position: %s" % [enemy_id, str(global_transform.origin)])
    
    if player:
        print("[ENEMY_DEBUG] ID:%d - Awarding score to player" % enemy_id)
        player.add_score(5)
        if randf() < drop_chance:
            print("[ENEMY_DEBUG] ID:%d - Dropping item (chance: %.2f)" % [enemy_id, drop_chance])
            var drop_options = [health_pack_scene, ammo_pack_scene, gas_pack_scene]
            var drop = drop_options[randi() % drop_options.size()]
            var instance = drop.instantiate()
            instance.global_transform.origin = global_transform.origin + Vector3(0, 1, 0)
            get_parent().add_child(instance)
    
    var explosion = null
    var explosion_id = -1
    var from_pool = false
    
    # Try to get an explosion from the pool first
    if PoolSystem.has_pool("explosions"):
        print("[ENEMY_DEBUG] ID:%d - Explosions pool exists, attempting to get object" % enemy_id)
        explosion = PoolSystem.get_object(PoolSystem.PoolType.EXPLOSION)
        if explosion:
            explosion_id = explosion.get_instance_id()
            from_pool = true
            print("[ENEMY_DEBUG] ID:%d - Got explosion ID:%d from pool for enemy death" % [enemy_id, explosion_id])
            
            # Log to DebugSettings if available
            if has_node("/root/DebugSettings"):
                DebugSettings.debug_print("pools", "Enemy ID:%d successfully got explosion ID:%d from pool" % 
                    [enemy_id, explosion_id])
        else:
            print("[ENEMY_DEBUG] ID:%d - Failed to get explosion from pool (returned null)" % enemy_id)
            
            # Log to DebugSettings if available
            if has_node("/root/DebugSettings"):
                DebugSettings.debug_print("pools", "Enemy ID:%d failed to get explosion from pool" % 
                    enemy_id, DebugSettings.LogLevel.WARNING)
    else:
        print("[ENEMY_DEBUG] ID:%d - Explosions pool does not exist!" % enemy_id)
        
        # Log to DebugSettings if available
        if has_node("/root/DebugSettings"):
            DebugSettings.debug_print("pools", "Enemy ID:%d found no explosion pool" % 
                enemy_id, DebugSettings.LogLevel.ERROR)
    
    # If no pooled explosion is available, instantiate one
    if explosion == null:
        print("[ENEMY_DEBUG] ID:%d - No pooled explosion available, instantiating new one" % enemy_id)
        explosion = explosion_scene.instantiate()
        explosion_id = explosion.get_instance_id()
        print("[ENEMY_DEBUG] ID:%d - Created new explosion ID:%d for enemy death (not from pool)" % [enemy_id, explosion_id])
        
        # Log to DebugSettings if available
        if has_node("/root/DebugSettings"):
            DebugSettings.debug_print("pools", "Enemy ID:%d CREATED NEW explosion ID:%d (pool bypassed)" % 
                [enemy_id, explosion_id], DebugSettings.LogLevel.WARNING)
    
    explosion.global_transform.origin = global_transform.origin
    var parent_id = get_parent().get_instance_id()
    print("[ENEMY_DEBUG] ID:%d - Adding explosion ID:%d to parent ID:%d" % [enemy_id, explosion_id, parent_id])
    get_parent().add_child(explosion)
    
    # Record pool usage statistics if not from pool
    if not from_pool and has_node("/root/DebugSettings"):
        DebugSettings.debug_print("performance", "Non-pooled explosion ID:%d created by enemy ID:%d" % 
            [explosion_id, enemy_id], DebugSettings.LogLevel.WARNING)
    
    if is_instance_valid(player):
        var distance = global_transform.origin.distance_to(player.global_transform.origin)
        print("[ENEMY_DEBUG] ID:%d - Player distance from explosion: %.2f (radius: %.2f)" % [enemy_id, distance, explosion_radius])
        
        if distance <= explosion_radius:
            var direction = (player.global_transform.origin - global_transform.origin).normalized()
            print("[ENEMY_DEBUG] ID:%d - Player in explosion radius, applying effects" % enemy_id)
            
            if !player.immunity:
                print("[ENEMY_DEBUG] ID:%d - Player not immune, applying %.2f damage" % [enemy_id, explosion_damage])
                player.take_damage(explosion_damage)
                player.apply_knockback(direction, explosion_force)
                print("[ENEMY_DEBUG] ID:%d - Applied knockback in direction: %s with force: %.2f" % 
                      [enemy_id, str(direction), explosion_force])
            elif player.immunity:
                print("[ENEMY_DEBUG] ID:%d - Player immune to explosion damage, only applying knockback" % enemy_id)
                player.apply_knockback(direction, explosion_force)
    
    print("[ENEMY_DEBUG] ID:%d - Disabling physics and hitbox" % enemy_id)
    hitbox.collision_layer = 0
    hitbox.collision_mask = 0
    hide()
    remove_from_group("enemy")
    set_physics_process(false)
    
    print("[ENEMY_DEBUG] ID:%d - Starting queue_free delay timer (0.5 seconds)" % enemy_id)
    await get_tree().create_timer(0.5).timeout
    print("[ENEMY_DEBUG] ID:%d - Delay complete, calling queue_free()" % enemy_id)
    queue_free()

func _on_hitbox_body_entered(body):
    if body == player and can_damage:
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
    
    print("Enemy received knockback force: ", knockback_force)
    knockback_velocity = knockback_force
    # Add a slight upward force to make it look more dramatic
    knockback_velocity.y += 2.0
