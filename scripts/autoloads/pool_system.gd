extends Node

## Pool system autoload for easy access to the object pool system

# The pool manager instance
var _pool_manager: PoolManager = null

# Enumeration of common pool types for easy reference
enum PoolType {
    BULLET,
    EXPLOSION,
    HIT_EFFECT,
    DAMAGE_NUMBER
    # Add more as needed
}

# Dictionary mapping pool types to their string names
var _pool_names: Dictionary = {
    PoolType.BULLET: "bullets",
    PoolType.EXPLOSION: "explosions",
    PoolType.HIT_EFFECT: "hit_effects",
    PoolType.DAMAGE_NUMBER: "damage_numbers"
    # Add more as needed
}

# Paths to common scenes we'll pool
const BULLET_SCENE = "res://scenes/bullet.tscn"
const EXPLOSION_SCENE = "res://scenes/Explosion.tscn"
const HIT_EFFECT_SCENE = "res://scenes/hit_effect.tscn"
const DAMAGE_NUMBER_SCENE = "res://scenes/damage_number.tscn"

func _ready() -> void:
    # Create the pool manager
    _pool_manager = PoolManager.new()
    _pool_manager.name = "PoolManager"
    add_child(_pool_manager)
    
    # Initialize common pools
    _initialize_common_pools()
    
    print("Pool System initialized!")

## Initialize commonly used object pools
func _initialize_common_pools() -> void:
    print("PoolSystem: Initializing common object pools...")
    
    # Load common scenes
    var bullet_scene: PackedScene = load(BULLET_SCENE)
    var explosion_scene: PackedScene = load(EXPLOSION_SCENE)
    var hit_effect_scene: PackedScene = load(HIT_EFFECT_SCENE)
    var damage_number_scene: PackedScene = load(DAMAGE_NUMBER_SCENE)
    
    # Create pools with appropriate initial sizes
    if bullet_scene:
        _pool_manager.create_pool(_pool_names[PoolType.BULLET], bullet_scene, 20)
        print("PoolSystem: Created bullet pool with initial size of 20")
    else:
        push_warning("PoolSystem: Failed to load bullet scene at " + BULLET_SCENE)
    
    if explosion_scene:
        _pool_manager.create_pool(_pool_names[PoolType.EXPLOSION], explosion_scene, 10)
        print("PoolSystem: Created explosion pool with initial size of 10")
    else:
        push_warning("PoolSystem: Failed to load explosion scene at " + EXPLOSION_SCENE)
    
    if hit_effect_scene:
        _pool_manager.create_pool(_pool_names[PoolType.HIT_EFFECT], hit_effect_scene, 30)
        print("PoolSystem: Created hit effect pool with initial size of 30")
    else:
        push_warning("PoolSystem: Failed to load hit effect scene at " + HIT_EFFECT_SCENE)
    
    if damage_number_scene:
        _pool_manager.create_pool(_pool_names[PoolType.DAMAGE_NUMBER], damage_number_scene, 20)
        print("PoolSystem: Created damage number pool with initial size of 20")
    else:
        push_warning("PoolSystem: Failed to load damage number scene at " + DAMAGE_NUMBER_SCENE)
    
    print("PoolSystem: Pool initialization complete")

## Get an object from a pool using the PoolType enum
func get_object(pool_type: PoolType) -> Node:
    if not _pool_names.has(pool_type):
        push_error("PoolSystem: Invalid pool type: %d" % pool_type)
        return null
    
    return _pool_manager.get_object(_pool_names[pool_type])

## Release an object back to its pool
func release_object(obj: Node) -> void:
    _pool_manager.release_object(obj)

## Create a custom pool with a specific scene
func create_custom_pool(pool_name: String, scene_path: String, initial_size: int = 10, max_size: int = -1) -> ObjectPool:
    var scene: PackedScene = load(scene_path)
    if not scene:
        push_error("PoolSystem: Failed to load scene: %s" % scene_path)
        return null
    
    return _pool_manager.create_pool(pool_name, scene, initial_size, max_size)

## Get a reference to a specific pool by name
func get_pool(pool_name: String) -> ObjectPool:
    return _pool_manager.get_pool(pool_name)

## Check if a pool with the given name exists
func has_pool(pool_name: String) -> bool:
    return _pool_manager.has_pool(pool_name)

## Get a reference to a specific pool by pool type
func get_pool_by_type(pool_type: PoolType) -> ObjectPool:
    if not _pool_names.has(pool_type):
        push_error("PoolSystem: Invalid pool type: %d" % pool_type)
        return null
    
    return _pool_manager.get_pool(_pool_names[pool_type])

## Get statistics about all pools
func get_stats() -> Dictionary:
    return _pool_manager.get_pool_counts()

## Get the raw pool manager instance
func get_pool_manager() -> PoolManager:
    return _pool_manager

## Clean up invalid objects in all pools
func cleanup_pools() -> void:
    if _pool_manager:
        _pool_manager.cleanup_all_pools()

## Print debug information about all pools
func debug_pools() -> void:
    if _pool_manager:
        var stats = get_stats()
        print("\n=== POOL SYSTEM DEBUG INFO ===")
        
        for pool_name in stats:
            var pool_stat = stats[pool_name]
            print("%s: %d active, %d available, %d total" % [
                pool_name, 
                pool_stat.active, 
                pool_stat.available, 
                pool_stat.total
            ])
            
            # Get actual objects in the pool
            var pool = _pool_manager.get_pool(pool_name)
            if pool:
                print("  Active objects:")
                for obj in pool._active_objects:
                    if is_instance_valid(obj):
                        print("    - ID: %d, Type: %s" % [obj.get_instance_id(), obj.get_class()])
                    else:
                        print("    - INVALID OBJECT")
                        
                print("  Available objects: %d" % pool._available_objects.size())
        
        print("==============================\n") 
