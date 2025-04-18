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

## Creates a new instance of the pooled scene
func _create_instance() -> Node:
    if pooled_scene == null:
        push_error("ObjectPool: Cannot create instance - no pooled_scene specified")
        return null
        
    var instance = pooled_scene.instantiate()
    add_child(instance)
    instance.process_mode = Node.PROCESS_MODE_DISABLED
    instance.visible = false
    return instance

## Gets an object from the pool
func get_object() -> Node:
    var obj: Node = null
    
    # If we have available objects, find a valid one
    while _available_objects.size() > 0:
        var candidate = _available_objects.pop_back()
        # Check if the object is still valid
        if is_instance_valid(candidate):
            obj = candidate
            break
        else:
            # Object was freed, skip it
            push_warning("ObjectPool: Found invalid (freed) object in pool. Skipping it.")
    
    # If no valid object was found, create a new one if we can
    if obj == null and (max_pool_size == -1 or (_active_objects.size() + _available_objects.size()) < max_pool_size):
        obj = _create_instance()
    # If we can't create more and found no valid objects, return null
    elif obj == null:
        push_warning("ObjectPool: No valid objects available and reached max_pool_size")
        return null
    
    if obj:
        _active_objects.append(obj)
        obj.process_mode = Node.PROCESS_MODE_INHERIT
        obj.visible = true
    
    return obj

## Returns an object to the pool
func release_object(obj: Node) -> void:
    if obj == null or not is_instance_valid(obj) or not _active_objects.has(obj):
        push_warning("ObjectPool: Attempting to release an invalid object or one not managed by this pool")
        return
    
    _active_objects.erase(obj)
    
    if should_reset_on_return and obj.has_method("reset"):
        obj.reset()
    
    _return_to_pool(obj)

## Helper to add an object back to the pool
func _return_to_pool(obj: Node) -> void:
    if not is_instance_valid(obj):
        push_warning("ObjectPool: Attempting to return invalid object to pool")
        return
        
    obj.process_mode = Node.PROCESS_MODE_DISABLED
    obj.visible = false
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
