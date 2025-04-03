# ammopack.gd - Updated version with reset()
extends RigidBody3D

@export var ammo_amount : int = 30

func _ready():
    # First-time setup only
    add_to_group("ammo_pack")
    
func reset():
    # Reset the pack's state when pulled from the pool
    visible = true
    collision_layer = 2  # Ensure collision is on
    collision_mask = 1   # Ensure collision is on
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    apply_central_impulse(Vector3(0, 5, 0)) # 5 units up

func _on_body_entered(body):
    if not visible or not is_instance_valid(body):
        return
        
    if body.has_method("add_ammo"):
        body.add_ammo(ammo_amount)
        
        # Return to pool instead of queue_free
        var object_pool = get_node_or_null("/root/ObjectPool")
        if object_pool:
            object_pool.return_object(self)
        else:
            queue_free() # Fallback if pool not available
