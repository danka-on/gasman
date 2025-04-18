extends Node

class_name ObjectPool

## The scene that this pool will instantiate
@export var pooled_scene: PackedScene
## Initial size of the pool (will grow if needed)
@export var initial_pool_size: int = 10
## Maximum size the pool can grow to (-1 for unlimited)
@export var max_pool_size: int = -1
## Whether objects should be reset when returned to pool
@export var should_reset_on_return: bool = true

## The list of available pooled objects
var _available_objects: Array[Node] = []
## The list of active objects currently in use
var _active_objects: Array[Node] = []

# Statistics
var stats_total_created: int = 0
var stats_total_accessed: int = 0
var stats_current_size: int = 0
var stats_max_size_reached: int = 0
var stats_cache_misses: int = 0
var stats_objects_deleted: int = 0

## Initialize the pool with the specified number of objects
func _ready() -> void:
    if pooled_scene == null:
        push_warning("ObjectPool: No pooled_scene specified. Pool will be empty until one is set.")
        return
        
    _initialize_pool()

## Initializes the pool with initial objects
func _initialize_pool() -> void:
    for i in range(initial_pool_size):
        var instance = _create_instance()
        if instance:
            _return_to_pool(instance)
    
    # Initialize statistics
    stats_total_created = initial_pool_size
    stats_current_size = initial_pool_size
    stats_max_size_reached = initial_pool_size

## Creates a new instance of the pooled scene
func _create_instance() -> Node:
    if pooled_scene == null:
        push_error("ObjectPool: Cannot create instance - no pooled_scene specified")
        return null
        
    var instance = pooled_scene.instantiate()
    add_child(instance)
    
    # Ensure the object is fully deactivated
    instance.process_mode = Node.PROCESS_MODE_DISABLED
    instance.visible = false
    
    # If we're processing, pause it until needed
    if instance.has_method("set_physics_process"):
        instance.set_physics_process(false)
    
    # Update statistics
    stats_total_created += 1
    stats_current_size += 1
    stats_max_size_reached = max(stats_max_size_reached, stats_current_size)
    
    # Log to DebugSettings if available
    if has_node("/root/DebugSettings"):
        DebugSettings.debug_print("pools", "Pool '%s' created new object ID:%d (total: %d)" % 
            [name, instance.get_instance_id(), stats_total_created], DebugSettings.LogLevel.VERBOSE)
    
    return instance

## Gets an object from the pool
func get_object() -> Node:
    print("[POOL_INTERNAL] Getting object from pool: " + name)
    stats_total_accessed += 1
    
    var obj: Node = null
    
    # If we have available objects, find a valid one
    while _available_objects.size() > 0:
        var candidate = _available_objects.pop_back()
        # Check if the object is still valid
        if is_instance_valid(candidate):
            obj = candidate
            print("[POOL_INTERNAL] Found valid object ID: " + str(obj.get_instance_id()))
            break
        else:
            # Object was freed, skip it
            push_warning("ObjectPool: Found invalid (freed) object in pool. Skipping it.")
            stats_objects_deleted += 1
            stats_current_size -= 1
    
    # If no valid object was found, create a new one if we can
    if obj == null and (max_pool_size == -1 or (_active_objects.size() + _available_objects.size()) < max_pool_size):
        print("[POOL_INTERNAL] Creating new instance for pool: " + name)
        obj = _create_instance()
        
        # Log to DebugSettings if available
        if has_node("/root/DebugSettings"):
            DebugSettings.debug_print("pools", "Pool '%s' cache miss - creating new object (hit rate: %.1f%%)" % 
                [name, (stats_total_accessed - stats_cache_misses) / float(stats_total_accessed) * 100], 
                DebugSettings.LogLevel.INFO)
        
        stats_cache_misses += 1
    # If we can't create more and found no valid objects, return null
    elif obj == null:
        push_warning("ObjectPool: No valid objects available and reached max_pool_size")
        
        # Log to DebugSettings if available
        if has_node("/root/DebugSettings"):
            DebugSettings.debug_print("pools", "Pool '%s' at max capacity (%d/%d) - denying object creation" % 
                [name, stats_current_size, max_pool_size], DebugSettings.LogLevel.WARNING)
        
        return null
    
    if obj:
        # Re-activate the object
        _active_objects.append(obj)
        obj.process_mode = Node.PROCESS_MODE_INHERIT
        obj.visible = true
        
        # Re-enable physics processing explicitly
        if obj.has_method("set_physics_process"):
            obj.set_physics_process(true)
        
        # Reset the object if it has a reset method
        # This is critical for poolable objects to initialize properly
        if obj.has_method("reset"):
            print("[POOL_INTERNAL] Resetting object ID: " + str(obj.get_instance_id()))
            obj.reset()
    
    return obj

## Returns an object to the pool
func release_object(obj: Node) -> void:
    if obj == null or not is_instance_valid(obj) or not _active_objects.has(obj):
        push_warning("ObjectPool: Attempting to release an invalid object or one not managed by this pool")
        
        # Log to DebugSettings if available
        if has_node("/root/DebugSettings") and obj != null and is_instance_valid(obj):
            DebugSettings.debug_print("pools", "Pool '%s' refused object ID:%d - not managed by this pool" % 
                [name, obj.get_instance_id()], DebugSettings.LogLevel.WARNING)
        
        return
    
    _active_objects.erase(obj)
    
    if should_reset_on_return and obj.has_method("reset"):
        obj.reset()
    
    _return_to_pool(obj)

## Helper to add an object back to the pool
func _return_to_pool(obj: Node) -> void:
    if not is_instance_valid(obj):
        push_warning("ObjectPool: Attempting to return invalid object to pool")
        stats_objects_deleted += 1
        stats_current_size -= 1
        return
        
    # Make sure the object is completely deactivated
    obj.process_mode = Node.PROCESS_MODE_DISABLED
    obj.visible = false
    
    # If the object has a specific method to prepare it for pooling, call it
    if obj.has_method("prepare_for_pool"):
        obj.prepare_for_pool()
    
    _available_objects.append(obj)

## Returns all active objects to the pool
func release_all() -> void:
    # Create a copy of the array to avoid issues while iterating
    var active_copy = _active_objects.duplicate()
    for obj in active_copy:
        if is_instance_valid(obj):
            release_object(obj)
        else:
            # Just remove invalid objects from the active list
            _active_objects.erase(obj)

## Returns the number of available objects in the pool
func get_available_count() -> int:
    return _available_objects.size()

## Returns the number of active objects from this pool
func get_active_count() -> int:
    return _active_objects.size()

## Gets all currently active objects
func get_active_objects() -> Array[Node]:
    return _active_objects

## Clean up any invalid objects from the pool
func cleanup() -> void:
    # Clean up available objects list
    for i in range(_available_objects.size() - 1, -1, -1):
        if not is_instance_valid(_available_objects[i]):
            _available_objects.remove_at(i)
    
    # Clean up active objects list
    for i in range(_active_objects.size() - 1, -1, -1):
        if not is_instance_valid(_active_objects[i]):
            _active_objects.remove_at(i)

## Set a new scene and rebuild the pool
func set_pooled_scene(scene: PackedScene) -> void:
    # First release all current objects
    release_all()
    
    # Clear the pool
    for obj in _available_objects:
        if is_instance_valid(obj):
            obj.queue_free()
    _available_objects.clear()
    
    # Set the new scene and initialize
    pooled_scene = scene
    _initialize_pool() 

## Get detailed statistics about this pool
func get_detailed_stats() -> Dictionary:
    return {
        "name": name,
        "active": get_active_count(),
        "available": get_available_count(),
        "total_current": stats_current_size,
        "total_created": stats_total_created,
        "max_size_reached": stats_max_size_reached,
        "total_accessed": stats_total_accessed,
        "cache_misses": stats_cache_misses,
        "cache_hit_rate": (stats_total_accessed - stats_cache_misses) / float(max(1, stats_total_accessed)) * 100,
        "objects_deleted": stats_objects_deleted
    }

## Print detailed statistics for this pool
func print_detailed_stats() -> void:
    var stats = get_detailed_stats()
    print("\n=== POOL '%s' STATISTICS ===" % name)
    print("Active objects: %d" % stats.active)
    print("Available objects: %d" % stats.available)
    print("Current total size: %d" % stats.total_current)
    print("Total objects created: %d" % stats.total_created)
    print("Maximum size reached: %d" % stats.max_size_reached)
    print("Total object requests: %d" % stats.total_accessed)
    print("Cache misses: %d" % stats.cache_misses)
    print("Cache hit rate: %.1f%%" % stats.cache_hit_rate)
    print("Objects deleted/leaked: %d" % stats.objects_deleted)
    print("==============================\n")
    
    # Log to DebugSettings if available
    if has_node("/root/DebugSettings"):
        DebugSettings.debug_print("pools", "Pool '%s' stats: %.1f%% hit rate, %d active, %d available, %d created" % 
            [name, stats.cache_hit_rate, stats.active, stats.available, stats.total_created], 
            DebugSettings.LogLevel.INFO)

## Clear the pool and recreate it with fresh objects
func reset_pool() -> void:
    # First release all current objects
    release_all()
    
    # Clear the pool
    for obj in _available_objects:
        if is_instance_valid(obj):
            obj.queue_free()
    _available_objects.clear()
    
    # Reset statistics
    stats_total_created = 0
    stats_current_size = 0
    stats_cache_misses = 0
    stats_objects_deleted = 0
    
    # Initialize with fresh objects
    _initialize_pool()
    
    # Log to DebugSettings if available
    if has_node("/root/DebugSettings"):
        DebugSettings.debug_print("pools", "Pool '%s' has been reset with %d fresh objects" % 
            [name, initial_pool_size], DebugSettings.LogLevel.INFO) 
