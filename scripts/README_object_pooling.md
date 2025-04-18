# Object Pooling System for Godot 4.4

This system provides a robust, efficient, and modular way to manage object pooling in your Godot game. Object pooling reduces the overhead of frequently creating and destroying objects, which can significantly improve performance.

## Components

The system consists of the following components:

1. **ObjectPool** (`object_pool.gd`): The base class that manages a pool of objects of the same type.
2. **PoolManager** (`pool_manager.gd`): A singleton that manages multiple object pools.
3. **PoolSystem** (`autoloads/pool_system.gd`): An autoload script that initializes the pool system and provides easy access to common pools.
4. **Poolable Object Scripts**: Extended versions of common objects with added pooling support:
   - `poolable_bullet.gd`
   - `poolable_explosion.gd`
   - `poolable_hit_effect.gd`
5. **Usage Example** (`pool_usage_example.gd`): Examples of how to use the pooling system.

## Setup

1. **Register the autoload**:
   - In Project Settings > Autoload, add `PoolSystem` pointing to `res://scripts/autoloads/pool_system.gd`

2. **Update your scene references**:
   - If using the provided poolable objects, update your scenes to use them instead of the regular versions

## Using the System

### Basic Usage

1. **Get an object from a pool**:
```gdscript
# Get a bullet from the predefined bullet pool
var bullet = PoolSystem.get_object(PoolSystem.PoolType.BULLET)

# Set up the bullet
bullet.global_transform = spawn_transform
bullet.velocity = direction * speed
```

2. **Return an object to the pool**:
```gdscript
# Objects automatically return to the pool when they're done
# For poolable objects with a reset() method, this happens automatically

# To manually return an object:
PoolSystem.release_object(my_object)
```

### Creating Custom Pools

You can easily create pools for your own custom objects:

```gdscript
# Create a custom pool
var custom_pool = PoolSystem.create_custom_pool(
    "custom_objects",        # Pool name
    "res://my_object.tscn",  # Scene path
    10,                      # Initial size
    -1                       # Max size (-1 for unlimited)
)

# Get an object from the custom pool
var obj = PoolSystem.get_pool("custom_objects").get_object()
```

### Making Objects Poolable

To make your own objects poolable:

1. Add a `reset()` method that resets the object to its initial state
2. Replace calls to `queue_free()` with checks for the PoolManager:

```gdscript
func _on_lifetime_timeout():
    # Return to pool instead of queue_free
    if PoolManager.instance != null:
        PoolManager.instance.release_object(self)
    else:
        queue_free()
```

## Performance Monitoring

You can check pool statistics:

```gdscript
var stats = PoolSystem.get_stats()
print("Bullet pool: %d active, %d available" % [
    stats["bullets"].active,
    stats["bullets"].available
])
```

## Extending the System

To add more pool types to the PoolSystem:

1. Add a new type to the `PoolType` enum in `pool_system.gd`
2. Add the corresponding name to the `_pool_names` dictionary
3. Add the scene path constant
4. Add the pool initialization in the `_initialize_common_pools()` method

## Best Practices

1. **Initial Pool Size**: Set initial pool sizes based on the maximum number of objects you expect to use simultaneously
2. **Reset Method**: Always implement a thorough `reset()` method for poolable objects
3. **Parent Management**: Be mindful of where pooled objects are added in the scene tree
4. **Object Lifetime**: Ensure objects return to the pool when they're no longer needed
5. **Signal Connections**: Be careful with signal connections - disconnect signals when returning objects to the pool if necessary

## Benefits of This System

- **Performance**: Reduces CPU usage and garbage collection pauses
- **Memory Efficiency**: Reuses objects instead of creating new ones
- **Easy Integration**: Simple API for common use cases
- **Flexible**: Supports different object types and custom pools
- **Scalable**: Can grow pools as needed or set hard limits
- **Debuggable**: Provides statistics for monitoring pool usage 