extends Node

class_name PoolManager

## Singleton pattern
static var instance: PoolManager = null

## Dictionary mapping pool names to ObjectPool nodes
var _pools: Dictionary[String, ObjectPool] = {}

## Signal emitted when a new pool is created
signal pool_created(pool_name: String)
## Signal emitted when a pool is removed
signal pool_removed(pool_name: String)

## Create the singleton instance
func _init() -> void:
    if instance != null:
        push_error("PoolManager: Singleton instance already exists!")
        return
        
    instance = self
    process_mode = Node.PROCESS_MODE_PAUSABLE

## Create a new object pool with the given name and scene
func create_pool(pool_name: String, scene: PackedScene, initial_size: int = 10, max_size: int = -1) -> ObjectPool:
    if _pools.has(pool_name):
        push_warning("PoolManager: Pool with name '%s' already exists. Returning existing pool." % pool_name)
        return _pools[pool_name]
    
    var pool := ObjectPool.new()
    pool.name = "Pool_" + pool_name
    pool.pooled_scene = scene
    pool.initial_pool_size = initial_size
    pool.max_pool_size = max_size
    
    add_child(pool)
    _pools[pool_name] = pool
    
    pool_created.emit(pool_name)
    return pool

## Get an object pool by name
func get_pool(pool_name: String) -> ObjectPool:
    if not _pools.has(pool_name):
        push_error("PoolManager: No pool found with name '%s'" % pool_name)
        return null
    
    return _pools[pool_name]

## Get an object from a specific pool by name
## A convenience method that combines get_pool() and get_object()
func get_object(pool_name: String) -> Node:
    var pool := get_pool(pool_name)
    if pool == null:
        return null
    
    return pool.get_object()

## Release an object back to its pool
## A convenience method that identifies which pool the object belongs to
func release_object(obj: Node) -> void:
    if not is_instance_valid(obj):
        push_warning("PoolManager: Cannot release invalid object")
        return
    
    for pool_name in _pools:
        var pool: ObjectPool = _pools[pool_name]
        if pool._active_objects.has(obj):
            pool.release_object(obj)
            return
    
    push_warning("PoolManager: Object not found in any pool: " + obj.name)

## Remove a pool by name
func remove_pool(pool_name: String) -> void:
    if not _pools.has(pool_name):
        push_warning("PoolManager: No pool found with name '%s'" % pool_name)
        return
    
    var pool: ObjectPool = _pools[pool_name]
    pool.queue_free()
    _pools.erase(pool_name)
    
    pool_removed.emit(pool_name)

## Remove all pools
func remove_all_pools() -> void:
    var pool_names := _pools.keys()
    for pool_name in pool_names:
        remove_pool(pool_name)

## Returns whether a pool with the given name exists
func has_pool(pool_name: String) -> bool:
    return _pools.has(pool_name)

## List all available pool names
func get_pool_names() -> Array:
    return _pools.keys()

## Get counts of all pools as a Dictionary
func get_pool_counts() -> Dictionary:
    var counts := {}
    for pool_name in _pools:
        var pool: ObjectPool = _pools[pool_name]
        counts[pool_name] = {
            "active": pool.get_active_count(),
            "available": pool.get_available_count(),
            "total": pool.get_active_count() + pool.get_available_count()
        }
    return counts

## Clean up invalid objects in all pools
func cleanup_all_pools() -> void:
    for pool_name in _pools:
        var pool: ObjectPool = _pools[pool_name]
        pool.cleanup()
        
    print("Pool Manager: Cleaned up all pools") 
