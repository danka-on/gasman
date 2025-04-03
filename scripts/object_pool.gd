# object_pool.gd - Updated version
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
        
        # Make sure object has required methods
        if not instance.has_method("reset"):
            printerr("Pooled object ", pool_name, " is missing reset() method!")
            
        instance.visible = false
        add_child(instance)
        pools[pool_name].append(instance)
        print("Added object to pool: ", pool_name)

# Get an object from the pool (or create new if needed)
func get_object(scene_path: String):
    var pool_name = scene_path.get_file().get_basename()
    
    # Initialize pool if it doesn't exist
    if not pools.has(pool_name):
        printerr("Pool doesn't exist, initializing: ", pool_name)
        initialize_pool(scene_path)
    
    # Find an inactive object in the pool
    for obj in pools[pool_name]:
        if not obj.visible:
            # Call reset to properly initialize the object
            if obj.has_method("reset"):
                obj.reset()
            return obj
    
    # If no inactive objects, create a new one and add it to the pool
    printerr("Pool for ", pool_name, " exhausted, creating new instance")
    var scene = load(scene_path)
    var instance = scene.instantiate()
    instance.set_meta("pool_name", pool_name)
    add_child(instance)
    pools[pool_name].append(instance)
    
    # Call reset to properly initialize the object
    if instance.has_method("reset"):
        instance.reset()
    return instance

# Return an object to the pool
func return_object(object):
    # Prevent double returns
    if not object.visible:
        return
        
    object.visible = false
    # The object's own reset() method will handle specific resets when retrieved again
