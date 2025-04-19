extends Area3D

class_name PoolableBullet

signal enemy_hit(is_headshot: bool)

@export var speed : float = 20.0
var velocity : Vector3
@export var hit_effect_scene : PackedScene = preload("res://scenes/hit_effect.tscn")
@export var can_ignite_gas: bool = true

var _lifetime_timer: SceneTreeTimer = null
var _signal_connections_setup: bool = false

func _ready():
    add_to_group("bullet")
    collision_layer = 4  # Bullets - layer 3 (value 4)
    collision_mask = 2 | 8  # Detect hitboxes (layer 2) AND gas clouds (layer 4, value 8)
    
    # We'll connect signals in setup_signal_connections to avoid duplicate connections
    setup_signal_connections()
    
    # Don't start the timer in _ready
    # The timer will be started in reset() which is called when the bullet is activated from the pool
    
    print("Bullet initialized: ", get_instance_id())

func setup_signal_connections():
    if not _signal_connections_setup:
        body_entered.connect(_on_body_entered)
        area_entered.connect(_on_area_entered)
        _signal_connections_setup = true

func cleanup_signal_connections():
    # Disconnect any existing signals to prevent duplicates
    if _signal_connections_setup:
        if body_entered.is_connected(_on_body_entered):
            body_entered.disconnect(_on_body_entered)
        if area_entered.is_connected(_on_area_entered):
            area_entered.disconnect(_on_area_entered)
        _signal_connections_setup = false

func _physics_process(delta):
    if velocity.length_squared() > 0:
        transform.origin += velocity * delta
    else:
        print("WARNING: Bullet has zero velocity in _physics_process: ", get_instance_id())

## Reset the bullet for reuse from the pool
func reset():
    print("Bullet reset: ", get_instance_id())
    
    # Reset position and velocity
    transform = Transform3D.IDENTITY
    velocity = Vector3.ZERO  # We zero the velocity here, but it will be set by the player's shoot function
    
    # Reset visibility and physics - ensure physics processing is enabled
    set_physics_process(true)
    visible = true
    
    # Cancel any existing lifetime timer
    if _lifetime_timer != null and _lifetime_timer.time_left > 0:
        if _lifetime_timer.timeout.is_connected(_on_lifetime_timeout):
            _lifetime_timer.timeout.disconnect(_on_lifetime_timeout)
    
    # Reset signals to prevent duplicate connections
    cleanup_signal_connections()
    setup_signal_connections()
    
    # Disconnect any external connections to our signals
    # This is critical to avoid memory leaks when the player connects to us
    if has_signal("enemy_hit"):
        get_signal_connection_list("enemy_hit").map(func(conn): enemy_hit.disconnect(conn.callable))
    
    # Start a new lifetime timer
    _start_lifetime_timer()

## Start the lifetime timer for this bullet
func _start_lifetime_timer():
    # Only start timer if the bullet is actually visible/active
    if visible and process_mode == Node.PROCESS_MODE_INHERIT:
        _lifetime_timer = get_tree().create_timer(5)
        _lifetime_timer.timeout.connect(_on_lifetime_timeout)
        print("Started lifetime timer for bullet: ", get_instance_id())

## Called when this bullet hits something
func hit():
    print("Bullet hit: ", get_instance_id())
    
    # Prevent multiple calls
    set_physics_process(false)
    
    # Get a hit effect from the pool instead of instantiating
    var hit_effect = null
    var parent_node = get_parent()
    
    # Ensure we have a valid parent
    if not is_instance_valid(parent_node):
        push_warning("Bullet hit: Parent node is not valid, cannot add hit effect")
        # Still return the bullet to the poold
        if PoolManager.instance != null:
            PoolManager.instance.release_object(self)
        else:
            queue_free()
        return
    
    # Try to get a hit effect from the pool
    if PoolSystem.has_pool("hit_effects"):
        hit_effect = PoolSystem.get_object(PoolSystem.PoolType.HIT_EFFECT)
    
    # If no pooled hit effect is available, instantiate one
    if hit_effect == null:
        hit_effect = hit_effect_scene.instantiate()
        if hit_effect == null:
            push_warning("Bullet hit: Failed to instantiate hit effect")
        else:
            print("Created new hit effect (not from pool)")
    else:
        print("Got hit effect from pool")
    
    # Add the hit effect to the scene and position it
    if hit_effect != null:
        parent_node.add_child(hit_effect)
        hit_effect.global_transform.origin = global_transform.origin
    
    # Return bullet to pool
    if PoolManager.instance != null:
        PoolManager.instance.release_object(self)
    else:
        queue_free()

func _on_body_entered(body):
    if body.has_method("take_damage"):
        if body.is_in_group("enemy"):
            body.take_damage(10, false)  # Specify this is not gas damage
            enemy_hit.emit(false)  # Signal normal hit
    call_deferred("hit")

func _on_area_entered(area):
    # Check if this is a hitbox
    if area.get_parent().is_in_group("enemy"):
        if area.name == "HeadHitbox":
            area.get_parent().take_damage(10, false, true)  # Headshot
            enemy_hit.emit(true)  # Signal headshot
        elif area.name == "Hitbox":
            area.get_parent().take_damage(10, false, false)  # Body shot
            enemy_hit.emit(false)  # Signal normal hit
    
    # Check if this is a gas cloud
    elif can_ignite_gas and area.is_in_group("gas_cloud") and area.has_method("bullet_hit"):
        area.bullet_hit(self)
    
    call_deferred("hit")

func _on_lifetime_timeout():
    print("Bullet lifetime expired: ", get_instance_id())
    
    # Return to pool instead of queue_free
    if PoolManager.instance != null:
        PoolManager.instance.release_object(self)
    else:
        queue_free()

## Called when the bullet is returned to the pool
## This ensures all timers and ongoing processes are stopped
func prepare_for_pool():
    print("Bullet prepared for pool: ", get_instance_id())
    
    # Cancel the lifetime timer if it's still running
    if _lifetime_timer != null and _lifetime_timer.time_left > 0:
        if _lifetime_timer.timeout.is_connected(_on_lifetime_timeout):
            _lifetime_timer.timeout.disconnect(_on_lifetime_timeout)
            
    # Don't completely disable physics processing - just pause it
    # This is to avoid issues when the bullet is activated again
    # set_physics_process(false)
    
    # Reset velocity to prevent any movement while pooled
    velocity = Vector3.ZERO 
