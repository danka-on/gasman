extends RigidBody3D

@export var health_amount : float = 25.0

func _ready():
    # First-time setup only
    add_to_group("health_pack")
    
func reset():
    # Reset the pack's state when pulled from the pool
    visible = true
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    apply_central_impulse(Vector3(0, 5, 0)) # 5 units up

func _on_body_entered(body):
    if body.has_method("take_damage"):
        body.take_damage(-health_amount)
        
        # Return to pool instead of queue_free
        var object_pool = get_node_or_null("/root/ObjectPool")
        if object_pool:
            object_pool.return_object(self)
        else:
            queue_free() # Fallback if pool not available
