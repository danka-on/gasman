extends Area3D

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
@export var debug_logging: bool = false  # Disable by default for performance

# Explosion properties
@export_group("Explosion")
@export var can_explode: bool = true
@export var explosion_damage: float = 30.0
@export var explosion_radius: float = 5.0
@export var explosion_chain_reaction: bool = true
@export var explosion_chain_radius: float = 3.0
@export var explosion_force: float = 10.0
@export var explosion_delay: float = 0.05 # Delay for chain reactions

# Internal state tracking
var enemies_in_cloud: Array = []
var current_lifetime: float = 0.0
var is_fading_out: bool = false
var is_being_freed: bool = false
var tween: Tween = null
var has_exploded: bool = false

func _ready():
    # Simple way to avoid errors from double-instantiation
    if is_being_freed:
        queue_free()
        return
        
    # Add to group for detection and chain reactions
    add_to_group("gas_cloud")
    
    # Debug print to verify properties are being passed correctly
    print("Gas cloud initialized with: size=", cloud_size, " color=", cloud_color, " preserve_visuals=", preserve_scene_visuals)
    
    # Update cloud size - ALWAYS apply this regardless of preserve_scene_visuals
    if $CollisionShape3D and $CollisionShape3D.shape:
        $CollisionShape3D.shape.radius = cloud_size
    
    # Create unique materials for this instance to prevent shared fading
    if $GPUParticles3D and $GPUParticles3D.process_material:
        var particle_material = $GPUParticles3D.process_material.duplicate()
        $GPUParticles3D.process_material = particle_material
        
        # Only create new mesh if needed
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
                    print("  Using scene visuals instead of passed properties")
    
    # Start the damage timer
    if $DamageTimer:
        $DamageTimer.wait_time = damage_interval
        $DamageTimer.start()
    
    # Initial enemy scan
    call_deferred("scan_for_enemies")

func _process(delta):
    # Guard against processing while being freed
    if is_being_freed or not is_inside_tree():
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
    if is_being_freed or not is_inside_tree():
        return
        
    # Try to find all enemies in the scene that are in range
    var overlapping_bodies = get_overlapping_bodies()
    for body in overlapping_bodies:
        if is_instance_valid(body) and body.is_in_group("enemy"):
            if not enemies_in_cloud.has(body):
                if debug_logging:
                    print("Enemy found in gas cloud:", body.name)
                enemies_in_cloud.append(body)

# Called when a bullet enters the gas cloud
func bullet_hit(bullet):
    if not can_explode or has_exploded or is_being_freed:
        return
        
    if debug_logging:
        print("Bullet hit gas cloud! Exploding...")
    
    # Trigger explosion
    explode()

func explode():
    # Prevent multiple explosions
    if has_exploded or is_being_freed:
        return
        
    has_exploded = true
    print("Gas cloud exploding!")
    
   
    
    # Apply explosion damage to entities in range
    var explosion_entities = get_explosion_targets()
    for entity in explosion_entities:
        if entity is CharacterBody3D:
            if entity.has_method("take_damage"):
                entity.take_damage(explosion_damage)
                print("Damaged entity: ", entity.name, " for ", explosion_damage, " damage")
            
            # Apply knockback if the entity has the method
            if entity.has_method("apply_knockback"):
                var direction = (entity.global_transform.origin - global_transform.origin).normalized()
                entity.apply_knockback(direction, explosion_force)
    
    # Chain reaction - find nearby gas clouds
    if explosion_chain_reaction:
        var nearby_clouds = get_nearby_clouds()
        if not nearby_clouds.is_empty():
            print("Found ", nearby_clouds.size(), " nearby clouds for chain reaction")
        trigger_chain_reaction()
    
    # Create explosion effect
    spawn_explosion_effect()
    
    # Delay removal slightly to allow for visual effect
    await get_tree().create_timer(0.1).timeout
    
    # Remove the cloud
    safe_free()

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
            # Add debug info if needed
            if debug_logging:
                print("Entity in explosion radius: ", body.name, " Distance: ", distance)
            targets.append(body)
    
    return targets

# Trigger explosions in nearby gas clouds
func trigger_chain_reaction():
    var other_clouds = get_tree().get_nodes_in_group("gas_cloud")
    
    for cloud in other_clouds:
        if not is_instance_valid(cloud) or cloud == self or cloud.has_exploded or cloud.is_being_freed:
            continue
            
        var distance = global_transform.origin.distance_to(cloud.global_transform.origin)
        if distance <= explosion_chain_radius:
            # Use a Timer instead of await for more reliable chain reactions
            var timer = Timer.new()
            timer.one_shot = true
            timer.wait_time = explosion_delay
            get_tree().root.add_child(timer)
            
            # Create weak references to track both the timer and cloud
            var cloud_ref = weakref(cloud)
            var timer_ref = weakref(timer)
            
            # Connect the timer to a callback
            timer.timeout.connect(func():
                # Check if the cloud still exists
                if cloud_ref.get_ref() and is_instance_valid(cloud_ref.get_ref()) and not cloud_ref.get_ref().has_exploded:
                    cloud_ref.get_ref().explode()
                
                # Clean up the timer
                if timer_ref.get_ref() and is_instance_valid(timer_ref.get_ref()):
                    timer_ref.get_ref().queue_free()
            )
            
            # Start the timer
            timer.start()

# Create explosion visual effect
func spawn_explosion_effect():
    # Try to get the explosion scene from the enemy script
    var explosion_scene_path = "res://scenes/Explosion.tscn"
    var explosion_scene = load(explosion_scene_path)
    
    if explosion_scene:
        var explosion = explosion_scene.instantiate()
        get_parent().add_child(explosion)
        explosion.global_transform.origin = global_transform.origin
        
        # Scale the explosion based on cloud size
        explosion.scale = Vector3.ONE * (cloud_size / 2.0)

func start_fade_out():
    # Only start fade if not already fading or being freed
    if is_fading_out or is_being_freed:
        return
        
    is_fading_out = true
    
    # Safety check if we're still in the tree and have valid nodes
    if not is_inside_tree() or not $GPUParticles3D or not $GPUParticles3D.draw_pass_1:
        safe_free()
        return
    
    # Cancel any previous tween if it exists
    if tween and tween.is_valid():
        tween.kill()
    
    # Get this cloud's unique material
    var mesh_material = $GPUParticles3D.draw_pass_1.material
    if not mesh_material:
        safe_free()
        return
    
    # Immediately disconnect signals to prevent callbacks after potential free
    disconnect_signals()
    
    # Create weak reference to self to prevent crashes if freed early
    var self_ref = weakref(self)
    
    # Fade out effect with unique material
    tween = create_tween()
    tween.tween_property(mesh_material, "albedo_color:a", 0.0, fade_out_time)
    tween.parallel().tween_property(mesh_material, "emission_energy_multiplier", 0.0, fade_out_time)
    
    # Safe callback that checks if object still exists, but uses a safer approach
    tween.tween_callback(func():
        if Engine.is_editor_hint():
            return
            
        # Use weakref to check if object still exists
        if self_ref.get_ref():
            if is_instance_valid(self_ref.get_ref()):
                safe_free()
    )

# A safer way to free the object
func safe_free():
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
    
    # Now queue for deletion if valid
    if is_instance_valid(self) and not is_queued_for_deletion():
        call_deferred("queue_free")

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

# Also ensure cleanup happens on destruction
func _exit_tree():
    # Mark as being freed
    is_being_freed = true
    
    # Cancel any active tween
    if tween and tween.is_valid():
        tween.kill()
        tween = null
    
    # Clear references to prevent memory leaks
    enemies_in_cloud.clear()

func _on_body_entered(body):
    if is_being_freed or not is_instance_valid(body):
        return
        
    # Check if this is a bullet
    if "bullet" in body.name.to_lower() and body.has_method("hit"):
        bullet_hit(body)
        
    if body.is_in_group("enemy"):
        if debug_logging:
            print("Enemy entered gas cloud:", body.name)
        if not enemies_in_cloud.has(body):
            enemies_in_cloud.append(body)

func _on_body_exited(body):
    if is_being_freed or not is_instance_valid(body):
        return
        
    if enemies_in_cloud.has(body):
        enemies_in_cloud.erase(body)

func _on_damage_timer_timeout():
    # Safety check if we're still in the tree
    if is_being_freed or not is_inside_tree():
        return
    
    # Cleanup invalid enemies first
    cleanup_invalid_enemies()
    
    # Only scan for new enemies occasionally to reduce overhead
    #if randf() < 0.3:  # 30% chance to scan each tick
     #   scan_for_enemies()
    
    # Apply damage to all enemies in the cloud
    for enemy in enemies_in_cloud:
        if is_instance_valid(enemy):
            if debug_logging:
                print("Damaging enemy:", enemy.name, " Amount:", damage_per_tick)
            enemy.take_damage(damage_per_tick) 

# Get nearby clouds for chain reaction
func get_nearby_clouds() -> Array:
    var result = []
    var other_clouds = get_tree().get_nodes_in_group("gas_cloud")
    
    for cloud in other_clouds:
        if not is_instance_valid(cloud) or cloud == self or cloud.has_exploded or cloud.is_being_freed:
            continue
            
        var distance = global_transform.origin.distance_to(cloud.global_transform.origin)
        if distance <= explosion_chain_radius:
            result.append(cloud)
    
    return result 
