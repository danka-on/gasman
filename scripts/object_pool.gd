extends Node

# Dictionary to store pools of different object types
var pools = {}

# Initialize a pool with a specific object type
func initialize_pool(scene_path: String, initial_size: int = 10):
    var scene = load(scene_path)
    if not scene:
        printerr("Failed to load scene: ", scene_path)
        return
        
    var pool_name = scene_path.get_file().get_basename()
    pools[pool_name] = []
    
    # Pre-instantiate objects for the pool
    for i in range(initial_size):
        var instance = scene.instantiate()
        instance.set_meta("pool_name", pool_name)
        
        # IMPORTANT: Set objects to invisible BEFORE adding to scene
        # This prevents them from auto-playing sounds/effects
        instance.visible = false
        
        add_child(instance)
        pools[pool_name].append(instance)

# Get an object from the pool (or create new if needed)
func get_object(scene_path: String):
    var pool_name = scene_path.get_file().get_basename()
    
    # Initialize pool if it doesn't exist
    if not pools.has(pool_name):
        initialize_pool(scene_path)
    
    # Find an inactive object in the pool
    for obj in pools[pool_name]:
        if not obj.visible:
            # Don't set visible here, let the reset() function handle it
            if obj.has_method("reset"):
                obj.reset()
            else:
                obj.visible = true
            return obj
    
    # If no inactive objects, create a new one and add it to the pool
    var scene = load(scene_path)
    var instance = scene.instantiate()
    instance.set_meta("pool_name", pool_name)
    
    # Set invisible first, then add to scene
    instance.visible = false
    add_child(instance)
    
    # Now make it visible (or call reset if available)
    if instance.has_method("reset"):
        instance.reset()
    else:
        instance.visible = true
        
    pools[pool_name].append(instance)
    return instance

# Return an object to the pool
func return_object(object):
    if not is_instance_valid(object):
        return
        
    object.visible = false
    
    # Stop any sounds if the object has audio players
    for child in object.get_children():
        if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
            child.stop()
    
    # Reset any physics properties
    if object is RigidBody3D:
        object.linear_velocity = Vector3.ZERO
        object.angular_velocity = Vector3.ZERO
        object.collision_layer = 0  # Disable collision layer
        object.collision_mask = 0   # Disable collision mask
