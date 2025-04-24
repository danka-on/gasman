extends Area3D

class_name PoolableGasCloud

# Damage properties
@export_group("Damage")
@export var damage_per_tick: float = 5.0
@export var damage_interval: float = 0.5

# Cloud properties
@export_group("Cloud")
@export var lifetime: float = 3.0
@export var fade_out_time: float = 0.5
@export var cloud_size: float = 2.0
@export var particle_amount: int = 50
@export var particle_scale_min: float = 2.0
@export var particle_scale_max: float = 3.0
@export var cloud_color: Color = Color(0.0, 0.8, 0.0, 0.3)
@export var emission_strength: float = 0.5
@export var preserve_scene_visuals: bool = true

# Explosion properties
@export_group("Explosion")
@export var can_explode: bool = true
@export var explosion_damage: float = 30.0
@export var explosion_radius: float = 5.0
@export var explosion_chain_reaction: bool = true
@export var explosion_chain_radius: float = 3.0
@export var explosion_force: float = 10.0
@export var explosion_delay: float = 0.05 # Delay for chain reactions

# Pooling/state tracking variables
var _creation_time: float = 0.0
var _id: int = 0
var _returning_to_pool: bool = false
var _being_reset_by_pool: bool = false
var _pool_return_initiated: bool = false

# Internal state tracking
var enemies_in_cloud: Array = []
var current_lifetime: float = 0.0
var is_fading_out: bool = false
var is_being_freed: bool = false
var tween: Tween = null
var has_exploded: bool = false
var particle_materials_initialized: bool = false

const EXPLOSION_SCENE = preload("res://scenes/PoolableExplosion.tscn")

func _ready():
    _id = get_instance_id()
    _creation_time = Time.get_ticks_msec() / 1000.0
    
    debug_print("Created at time: %.2f" % _creation_time)
    add_to_group("gas_cloud")
    
    # Initialize but ensure reset() is called by the pool
    if not particle_materials_initialized:
        reset()

## Reset the gas cloud for reuse from the pool
func reset():
    # Prevent recursive calls when being reset by the pool
    if _being_reset_by_pool:
        _being_reset_by_pool = false
        _returning_to_pool = false
        _pool_return_initiated = false
        debug_print("Reset during pool return")
        return
    
    var reset_time = Time.get_ticks_msec() / 1000.0
    debug_print("Reset at time: %.2f (alive for %.2f seconds)" % [reset_time, reset_time - _creation_time])
    
    # Reset transform
    transform = Transform3D.IDENTITY
    
    # Reset state variables
    enemies_in_cloud.clear()
    current_lifetime = 0.0
    is_fading_out = false
    is_being_freed = false
    has_exploded = false
    
    # Force visibility and process mode
    visible = true
    process_mode = Node.PROCESS_MODE_INHERIT
    
    # Update cloud size
    if $CollisionShape3D and $CollisionShape3D.shape:
        $CollisionShape3D.shape.radius = cloud_size
    
    # Initialize particle materials only once to prevent the respawning issue
    if not particle_materials_initialized:
        initialize_particle_materials()
        particle_materials_initialized = true
    else:
        # If materials are already initialized but appearance needs updating
        if not preserve_scene_visuals:
            set_particle_properties()
    
    # Reset emission state of particles
    if $GPUParticles3D:
        debug_print("Starting particle emission")
        $GPUParticles3D.emitting = true
        
        # Debug verification
        if $GPUParticles3D.emitting:
            debug_print("Particle emission confirmed ON", DebugSettings.LogLevel.VERBOSE)
        else:
            debug_print("Particles failed to start!", DebugSettings.LogLevel.ERROR)
        
        # Schedule a deferred check to ensure particles are emitting
        call_deferred("_verify_particles_emitting")
    
    # Start/restart damage timer
    if $DamageTimer:
        $DamageTimer.wait_time = damage_interval
        $DamageTimer.start()
    
    # Reset pooling flags
    _returning_to_pool = false
    _pool_return_initiated = false
    
    # Initial enemy scan
    call_deferred("scan_for_enemies")

# Initialize particle materials to prevent the respawning issue
func initialize_particle_materials():
    if $GPUParticles3D and $GPUParticles3D.process_material:
        debug_print("Initializing particle materials")
        
        # Create a unique material for this instance to prevent shared properties
        var particle_material = $GPUParticles3D.process_material.duplicate()
        $GPUParticles3D.process_material = particle_material
        
        # Only create new mesh material if needed
        if $GPUParticles3D.draw_pass_1:
            var mesh = $GPUParticles3D.draw_pass_1.duplicate()
            if mesh and mesh.material:
                var mesh_material = mesh.material.duplicate()
                mesh.material = mesh_material
                $GPUParticles3D.draw_pass_1 = mesh
                
                # ALWAYS update the particle sphere radius regardless of preserve_scene_visuals
                particle_material.emission_sphere_radius = cloud_size
                
                # Only override visual properties if preserve_scene_visuals is false
                if not preserve_scene_visuals:
                    # Update particle properties
                    $GPUParticles3D.amount = particle_amount
                    particle_material.scale_min = particle_scale_min
                    particle_material.scale_max = particle_scale_max
                    particle_material.color = cloud_color
                    
                    # Update visual properties
                    mesh_material.albedo_color = cloud_color
                    mesh_material.emission = Color(cloud_color.r, cloud_color.g, cloud_color.b, 1.0)
                    mesh_material.emission_energy_multiplier = emission_strength
                else:
                    debug_print("Using scene visuals instead of passed properties", DebugSettings.LogLevel.VERBOSE)
        
        debug_print("Particle materials initialized successfully", DebugSettings.LogLevel.VERBOSE)

# Set particle properties without re-initializing materials
func set_particle_properties():
    if $GPUParticles3D and $GPUParticles3D.process_material:
        debug_print("Updating particle properties")
        
        var particle_material = $GPUParticles3D.process_material
        
        # Always update the emission sphere radius
        particle_material.emission_sphere_radius = cloud_size
        
        # Update particle properties
        $GPUParticles3D.amount = particle_amount
        particle_material.scale_min = particle_scale_min
        particle_material.scale_max = particle_scale_max
        particle_material.color = cloud_color
        
        # Update mesh material if it exists
        if $GPUParticles3D.draw_pass_1 and $GPUParticles3D.draw_pass_1.material:
            var mesh_material = $GPUParticles3D.draw_pass_1.material
            mesh_material.albedo_color = cloud_color
            mesh_material.emission = Color(cloud_color.r, cloud_color.g, cloud_color.b, 1.0)
            mesh_material.emission_energy_multiplier = emission_strength
            
        debug_print("Particle properties updated", DebugSettings.LogLevel.VERBOSE)

# Debug verification function (similar to poolable_explosion.gd)
func _verify_particles_emitting():
    # Skip the check if we're no longer visible or active
    if not visible or process_mode == Node.PROCESS_MODE_DISABLED:
        return
    
    if $GPUParticles3D:
        var particles = $GPUParticles3D
        debug_print("DEFERRED CHECK: Particles emitting: %s" % str(particles.emitting), 
            DebugSettings.LogLevel.VERBOSE)
        
        # Try to force emission if it's not emitting
        if not particles.emitting:
            debug_print("ATTEMPTING FORCE RESTART OF PARTICLES", DebugSettings.LogLevel.WARNING)
            particles.restart()
            particles.emitting = true
            
            # Create new particles if restart fails
            if not particles.emitting:
                debug_print("CRITICAL: Particles won't emit! Trying alternative approach", 
                    DebugSettings.LogLevel.ERROR)
                
                # Try applying a different solution to prevent the bug
                var current_material = particles.process_material
                if current_material:
                    var material_copy = current_material.duplicate()
                    particles.process_material = material_copy
                    particles.restart()
                    particles.emitting = true
                    debug_print("Applied material copy fix", DebugSettings.LogLevel.WARNING)
    else:
        debug_print("DEFERRED CHECK: Particles node not found!", DebugSettings.LogLevel.ERROR)

func _process(delta):
    # Guard against processing while being freed or returning to pool
    if is_being_freed or _returning_to_pool or not is_inside_tree():
        return
    
    # Handle cloud lifetime
    if not is_fading_out:
        current_lifetime += delta
        if current_lifetime >= lifetime:
            start_fade_out()
    
    # Periodically cleanup invalid enemies (once every ~30 frames)
    if randf() < 0.03:
        cleanup_invalid_enemies()

func cleanup_invalid_enemies():
    # Early exit if we're being freed or empty array
    if is_being_freed or enemies_in_cloud.is_empty():
        return
        
    # Remove any invalid enemies from the tracking array
    for i in range(enemies_in_cloud.size() - 1, -1, -1):
        if i >= enemies_in_cloud.size(): 
            continue # Array might have changed size during loop
        if not is_instance_valid(enemies_in_cloud[i]):
            enemies_in_cloud.remove_at(i)

func scan_for_enemies():
    # Safety check if we're still in the tree
    if is_being_freed or not is_inside_tree() or _returning_to_pool:
        return
        
    # Try to find all enemies in the scene that are in range
    var overlapping_bodies = get_overlapping_bodies()
    for body in overlapping_bodies:
        if is_instance_valid(body) and body.is_in_group("enemy"):
            if not enemies_in_cloud.has(body):
                debug_print("Enemy found in gas cloud: %s" % body.name, DebugSettings.LogLevel.VERBOSE)
                enemies_in_cloud.append(body)

# Called when a bullet enters the gas cloud
func bullet_hit(bullet):
    if not can_explode or has_exploded or is_being_freed or _returning_to_pool:
        return
        
    debug_print("Bullet hit gas cloud! Exploding...")
    
    # Trigger explosion
    explode()

func explode():
    # Prevent multiple explosions
    if has_exploded or is_being_freed or _returning_to_pool:
        return
        
    has_exploded = true
    
    # Apply explosion damage to entities in range
    var explosion_entities = get_explosion_targets()
    for entity in explosion_entities:
        if entity is CharacterBody3D:
            if entity.has_method("take_damage"):
                if entity.is_in_group("enemy"):
                    entity.take_damage(explosion_damage, true)  # Specify this is gas damage for enemies
                else:
                    entity.take_damage(explosion_damage)  # For player, only pass damage amount
                debug_print("Damaged entity: %s for %.1f damage" % [entity.name, explosion_damage], 
                    DebugSettings.LogLevel.VERBOSE)
            
            # Apply knockback if the entity has the method
            if entity.has_method("apply_knockback"):
                var direction = (entity.global_transform.origin - global_transform.origin).normalized()
                entity.apply_knockback(direction, explosion_force)
    
    # Chain reaction - find nearby gas clouds
    if explosion_chain_reaction:
        var nearby_clouds = get_nearby_clouds()
        if not nearby_clouds.is_empty():
            debug_print("Found %d nearby clouds for chain reaction" % nearby_clouds.size())
        trigger_chain_reaction()
    
    # Create explosion effect
    spawn_explosion_effect()
    
    # Delay removal slightly to allow for visual effect
    await get_tree().create_timer(0.1).timeout
    
    # Return to pool instead of freeing
    prepare_for_pool()

# Find targets within explosion radius
func get_explosion_targets() -> Array:
    var targets = []
    
    # Get all bodies in the scene and check distance
    var bodies = get_tree().get_nodes_in_group("enemy")
    bodies.append_array(get_tree().get_nodes_in_group("player"))
    
    for body in bodies:
        if not is_instance_valid(body):
            continue
            
        var distance = global_transform.origin.distance_to(body.global_transform.origin)
        if distance <= explosion_radius:
            debug_print("Entity in explosion radius: %s, Distance: %.2f" % [body.name, distance], 
                DebugSettings.LogLevel.VERBOSE)
            targets.append(body)
    
    return targets

# Trigger explosions in nearby gas clouds
func trigger_chain_reaction():
    debug_print("Attempting to trigger chain reaction")
    var nearby_clouds = get_nearby_clouds()
    
    if nearby_clouds.is_empty():
        debug_print("No valid gas clouds found in range for chain reaction", DebugSettings.LogLevel.WARNING)
        return
        
    debug_print("Triggering chain reaction on %d nearby gas clouds" % nearby_clouds.size())
    
    for cloud in nearby_clouds:
        if not is_instance_valid(cloud) or cloud == self or cloud.has_exploded or cloud.is_being_freed:
            continue
            
        var distance = global_transform.origin.distance_to(cloud.global_transform.origin)
        if distance <= explosion_chain_radius:
            debug_print("Scheduling explosion for gas cloud ID:%d at distance %.2f with delay %.2f seconds" % 
                [cloud.get_instance_id(), distance, explosion_delay])
            
            # Use a Timer instead of await for more reliable chain reactions
            var timer = Timer.new()
            timer.one_shot = true
            timer.wait_time = explosion_delay
            timer.name = "ChainReactionTimer_" + str(cloud.get_instance_id())
            get_tree().root.add_child(timer)
            
            # Create weak references to track both the timer and cloud
            var cloud_ref = weakref(cloud)
            var timer_ref = weakref(timer)
            
            # Connect the timer to a callback
            timer.timeout.connect(func():
                debug_print("Chain reaction timer fired for cloud ID:%d" % cloud.get_instance_id() if cloud_ref.get_ref() else -1)
                # Check if the cloud still exists
                if cloud_ref.get_ref() and is_instance_valid(cloud_ref.get_ref()) and not cloud_ref.get_ref().has_exploded:
                    debug_print("Triggering chain explosion on gas cloud ID:%d" % cloud_ref.get_ref().get_instance_id())
                    cloud_ref.get_ref().explode()
                else:
                    debug_print("Target gas cloud no longer valid for chain reaction", DebugSettings.LogLevel.WARNING)
                
                # Clean up the timer
                if timer_ref.get_ref() and is_instance_valid(timer_ref.get_ref()):
                    timer_ref.get_ref().queue_free()
            )
            
            # Start the timer
            timer.start()
            debug_print("Chain reaction timer started for gas cloud ID:%d" % cloud.get_instance_id())

# Create explosion visual effect
func spawn_explosion_effect():
    debug_print("Spawning explosion effect at position: %s" % str(global_transform.origin))
    
    var explosion = null
    var explosion_id = -1
    var from_pool = false
    
    # Try to get an explosion from the pool first
    var pool_system = null
    if Engine.has_singleton("PoolSystem"):
        pool_system = Engine.get_singleton("PoolSystem")
        debug_print("PoolSystem singleton found via Engine.has_singleton")
    elif is_instance_valid(PoolSystem):
        pool_system = PoolSystem
        debug_print("PoolSystem found via global reference")
    
    if pool_system:
        debug_print("PoolSystem accessed, checking for explosions pool")
        
        # Use the safe method to ensure the pool exists
        if pool_system.has_method("get_object_safe"):
            debug_print("Using get_object_safe method to retrieve explosion")
            explosion = pool_system.get_object_safe(pool_system.PoolType.EXPLOSION)
            if explosion:
                explosion_id = explosion.get_instance_id()
                from_pool = true
                debug_print("Got explosion ID:%d from pool" % explosion_id)
                
                # Log to DebugSettings
                DebugSettings.log_info("pools", "Gas cloud ID:%d successfully got explosion ID:%d from pool" % 
                    [_id, explosion_id])
            else:
                debug_print("Failed to get explosion from pool (returned null)", DebugSettings.LogLevel.WARNING)
                DebugSettings.log_warning("pools", "Gas cloud ID:%d failed to get explosion from pool" % _id)
        elif pool_system.has_pool("explosions"):
            debug_print("Explosions pool exists, attempting to get object with standard method")
            explosion = pool_system.get_object(pool_system.PoolType.EXPLOSION)
            if explosion:
                explosion_id = explosion.get_instance_id()
                from_pool = true
                debug_print("Got explosion ID:%d from pool" % explosion_id)
                
                # Log to DebugSettings
                DebugSettings.log_info("pools", "Gas cloud ID:%d successfully got explosion ID:%d from pool" % 
                    [_id, explosion_id])
            else:
                debug_print("Failed to get explosion from pool (returned null)", DebugSettings.LogLevel.WARNING)
                DebugSettings.log_warning("pools", "Gas cloud ID:%d failed to get explosion from pool" % _id)
        else:
            debug_print("Explosions pool does not exist!", DebugSettings.LogLevel.ERROR)
            DebugSettings.log_error("pools", "Gas cloud ID:%d found no explosion pool" % _id)
    else:
        debug_print("PoolSystem not available by any method", DebugSettings.LogLevel.ERROR)
        DebugSettings.log_error("pools", "Gas cloud ID:%d could not access PoolSystem singleton" % _id)
    
    # If no pooled explosion is available, instantiate one
    if explosion == null:
        debug_print("No pooled explosion available, instantiating new one", DebugSettings.LogLevel.WARNING)
        var explosion_scene_path = "res://scenes/PoolableExplosion.tscn"
        var explosion_scene = load(explosion_scene_path)
        if not explosion_scene:
            explosion_scene_path = "res://scenes/Explosion.tscn"
            explosion_scene = load(explosion_scene_path)
        
        if explosion_scene:
            explosion = explosion_scene.instantiate()
            explosion_id = explosion.get_instance_id()
            debug_print("Created new explosion ID:%d (not from pool)" % explosion_id, DebugSettings.LogLevel.WARNING)
            
            # Log to DebugSettings
            DebugSettings.log_warning("pools", "Gas cloud ID:%d CREATED NEW explosion ID:%d (pool bypassed)" % 
                [_id, explosion_id])
        else:
            debug_print("ERROR: Failed to load explosion scene!", DebugSettings.LogLevel.ERROR)
            DebugSettings.log_error("pools", "Gas cloud ID:%d failed to load explosion scene" % _id)
    
    if explosion:
        if get_parent():
            var parent_id = get_parent().get_instance_id()
            debug_print("Adding explosion ID:%d to parent ID:%d" % [explosion_id, parent_id])
            
            get_parent().add_child(explosion)
            explosion.global_transform.origin = global_transform.origin
            
            # Scale the explosion based on cloud size
            explosion.scale = Vector3.ONE * (cloud_size / 2.0)
            debug_print("Set explosion ID:%d scale to: %s" % [explosion_id, str(explosion.scale)])
            
            # Record pool usage statistics if not from pool
            if not from_pool:
                DebugSettings.log_warning("performance", "Non-pooled explosion ID:%d created by gas cloud ID:%d" % 
                    [explosion_id, _id])
        else:
            debug_print("ERROR: Gas cloud has no parent to add explosion to!", DebugSettings.LogLevel.ERROR)
    else:
        debug_print("ERROR: Failed to create explosion!", DebugSettings.LogLevel.ERROR)
        DebugSettings.log_error("gas_clouds", "Gas cloud ID:%d completely failed to create explosion" % _id)

func start_fade_out():
    # Only start fade if not already fading or being freed
    if is_fading_out or is_being_freed or _returning_to_pool:
        return
        
    is_fading_out = true
    debug_print("Starting fade out")
    
    # Safety check if we're still in the tree and have valid nodes
    if not is_inside_tree() or not $GPUParticles3D or not $GPUParticles3D.draw_pass_1:
        debug_print("Invalid state for fade out, preparing for pool", DebugSettings.LogLevel.WARNING)
        prepare_for_pool()
        return
    
    # Cancel any previous tween if it exists
    if tween and tween.is_valid():
        tween.kill()
    
    # Get this cloud's unique material
    var mesh_material = $GPUParticles3D.draw_pass_1.material
    if not mesh_material:
        debug_print("No material found for fade out, preparing for pool", DebugSettings.LogLevel.WARNING)
        prepare_for_pool()
        return
    
    # Immediately disconnect signals to prevent callbacks after potential free
    disconnect_signals()
    
    # Create weak reference to self to prevent crashes if freed early
    var self_ref = weakref(self)
    
    # Fade out effect with unique material
    tween = create_tween()
    tween.tween_property(mesh_material, "albedo_color:a", 0.0, fade_out_time)
    tween.parallel().tween_property(mesh_material, "emission_energy_multiplier", 0.0, fade_out_time)
    
    # Safe callback that checks if object still exists
    tween.tween_callback(func():
        if Engine.is_editor_hint():
            return
            
        # Use weakref to check if object still exists
        if self_ref.get_ref() and is_instance_valid(self_ref.get_ref()):
            debug_print("Fade out complete, preparing for pool")
            prepare_for_pool()
    )

## Called when returning to the pool
func prepare_for_pool():
    # If we already went through this process once and are being called by the pool system
    if _pool_return_initiated:
        debug_print("Pool system calling prepare_for_pool, already handled")
        return
    
    # If we're already in the returning_to_pool state, prevent recursion
    if _returning_to_pool:
        debug_print("Already returning to pool, skipping duplicate call")
        return
    
    # Set flags to track that we initiated the pool return process
    _returning_to_pool = true
    _pool_return_initiated = true
    
    var prepare_time = Time.get_ticks_msec() / 1000.0
    debug_print("Prepared for pool at time: %.2f (used for %.2f seconds)" % 
        [prepare_time, prepare_time - _creation_time])
    
    # Mark as being freed to avoid any new operations
    is_being_freed = true
    
    # Clear references
    enemies_in_cloud.clear()
    
    # Cancel any active tween
    if tween and tween.is_valid():
        tween.kill()
        tween = null
    
    # Disconnect any signals
    disconnect_signals()
    
    # Stop any ongoing particles and hide
    if $GPUParticles3D:
        $GPUParticles3D.emitting = false
    
    # Hide while in pool
    visible = false
    
    # First remove from parent if we have one
    if get_parent():
        debug_print("Removing from parent")
        get_parent().remove_child(self)
    
    # Access PoolSystem to return to pool
    var pool_system = null
    if Engine.has_singleton("PoolSystem"):
        pool_system = Engine.get_singleton("PoolSystem")
        debug_print("Found PoolSystem via singleton")
    elif is_instance_valid(PoolSystem):
        pool_system = PoolSystem
        debug_print("Found PoolSystem via global")
    
    if pool_system:
        if pool_system.has_pool("gas_clouds"):
            debug_print("Releasing to gas_clouds pool")
            # Set flag to indicate pool system is about to reset us
            _being_reset_by_pool = true
            pool_system.release_object(self)
        else:
            debug_print("No gas_clouds pool found, queue_freeing", DebugSettings.LogLevel.WARNING)
            queue_free()
    else:
        debug_print("PoolSystem not available by any method, queue_freeing", DebugSettings.LogLevel.WARNING)
        queue_free()

# Manually disconnect all signals to avoid callbacks after being freed
func disconnect_signals():
    if not is_inside_tree():
        return
        
    # Disconnect the body entered/exited signals
    if is_connected("body_entered", Callable(self, "_on_body_entered")):
        disconnect("body_entered", Callable(self, "_on_body_entered"))
        
    if is_connected("body_exited", Callable(self, "_on_body_exited")):
        disconnect("body_exited", Callable(self, "_on_body_exited"))
    
    # Disconnect the damage timer
    if $DamageTimer and $DamageTimer.is_connected("timeout", Callable(self, "_on_damage_timer_timeout")):
        $DamageTimer.disconnect("timeout", Callable(self, "_on_damage_timer_timeout"))
        $DamageTimer.stop()

func _on_body_entered(body):
    if is_being_freed or not is_instance_valid(body) or _returning_to_pool:
        return
        
    # Check if this is a bullet
    if "bullet" in body.name.to_lower() and body.has_method("hit"):
        bullet_hit(body)
        
    if body.is_in_group("enemy"):
        debug_print("Enemy entered gas cloud: %s" % body.name, DebugSettings.LogLevel.VERBOSE)
        if not enemies_in_cloud.has(body):
            enemies_in_cloud.append(body)

func _on_body_exited(body):
    if is_being_freed or not is_instance_valid(body) or _returning_to_pool:
        return
        
    if enemies_in_cloud.has(body):
        enemies_in_cloud.erase(body)

func _on_damage_timer_timeout():
    # Safety check if we're still in the tree
    if is_being_freed or not is_inside_tree() or _returning_to_pool:
        return
    
    # Cleanup invalid enemies first
    cleanup_invalid_enemies()
    
    # Apply damage to all enemies in the cloud
    for enemy in enemies_in_cloud:
        if is_instance_valid(enemy):
            debug_print("Damaging enemy: %s Amount: %.1f" % [enemy.name, damage_per_tick], 
                DebugSettings.LogLevel.VERBOSE)
            enemy.take_damage(damage_per_tick, true)  # Specify this is gas damage

# Get all gas clouds within explosion chain radius
func get_nearby_clouds() -> Array:
    var nearby_clouds = []
    var all_clouds = get_tree().get_nodes_in_group("gas_cloud")
    
    debug_print("Found %d total gas clouds in scene" % all_clouds.size())
    if all_clouds.size() <= 1:
        debug_print("Only this gas cloud exists, no chain reaction possible", DebugSettings.LogLevel.WARNING)
        return nearby_clouds
    
    for cloud in all_clouds:
        if cloud == self or not is_instance_valid(cloud) or cloud.has_exploded or cloud.is_being_freed:
            continue
            
        var distance = global_transform.origin.distance_to(cloud.global_transform.origin)
        debug_print("Gas cloud ID:%d is at distance %.2f (max chain radius: %.2f)" % 
            [cloud.get_instance_id(), distance, explosion_chain_radius])
            
        if distance <= explosion_chain_radius:
            nearby_clouds.append(cloud)
            debug_print("Added gas cloud ID:%d to chain reaction at distance %.2f" % 
                [cloud.get_instance_id(), distance])
    
    return nearby_clouds

# Helper function to print debug messages using the central debug system
func debug_print(message: String, level: int = DebugSettings.LogLevel.INFO) -> void:
    # Format the message with the object ID
    var formatted_message = "ID:%d - %s" % [_id, message]
    
    # Send to central debug system if available
    if Engine.has_singleton("DebugSettings"):
        DebugSettings.debug_print("gas_clouds", formatted_message, level)
    else:
        # Fallback to direct print if debug system isn't available
        print("[GAS_CLOUD] " + formatted_message) 
