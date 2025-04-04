extends RigidBody3D

@export var health_amount : float = 25.0

# Debug flag
var debug_pack = false

func _ready():
    # First-time setup only
    add_to_group("health_pack")
    
    # Ensure proper collision setup
    collision_layer = 2    # Items layer
    collision_mask = 1     # Collide with environment (floor/walls)
    
    if debug_pack:
        print("Health Pack: Ready called, collision layer=", collision_layer, " mask=", collision_mask)
    
func reset():
    # Reset the pack's state when pulled from the pool
    visible = true
    
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    collision_layer = 2  # Restore original layer (set in .tscn file)
    collision_mask = 1   # Restore mask to detect player (adjust as needed)
    apply_central_impulse(Vector3(0, 5, 0)) # 5 units up
    
    # DON'T play sounds during reset - will be played by the pickup system
    # Don't make any nodes emit particles or play sounds here
    if debug_pack:
        print("Health Pack: Reset called")

func _on_body_entered(body):
    if not visible or not is_instance_valid(body):
        return
        
    if debug_pack:
        print("Health Pack: Body entered: ", body.name)
        
    if body.has_method("take_damage"):
        body.take_damage(-health_amount)
        
        if debug_pack:
            print("Health Pack: Applied healing to player")
        
        # Return to pool instead of queue_free
        var object_pool = get_node_or_null("/root/ObjectPool")
        if object_pool:
            object_pool.return_object(self)
        else:
            queue_free() # Fallback if pool not available
