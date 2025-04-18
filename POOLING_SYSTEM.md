# Object Pooling System

This document outlines the object pooling system implemented in our game, with a focus on the enemy pooling implementation.

## Overview

The object pooling system is designed to improve performance by reusing game objects instead of creating and destroying them constantly. This reduces both CPU usage (from instantiation/destruction) and memory fragmentation.

Key components that use pooling:
- Bullets
- Explosions
- Hit Effects
- Damage Numbers
- Enemies (newly implemented)

## Architecture

### Core Components

1. **PoolManager** - Core singleton that manages object pools
2. **PoolSystem** - Autoload that provides easy access to pools
3. **ObjectPool** - Individual pool implementation for each object type
4. **Poolable Objects** - Objects that implement pooling lifecycle methods

### Required Methods for Poolable Objects

For an object to work with the pooling system, it should implement:

- **reset()** - Called when object is retrieved from pool, reset all state
- **prepare_for_pool()** - Called when object is returned to pool, cleanup

## Enemy Pooling Implementation

### PoolableEnemy Class

The `PoolableEnemy` class extends `CharacterBody3D` and implements the pooling lifecycle methods:

```gdscript
class_name PoolableEnemy
extends CharacterBody3D

# Pooling-specific variables
var _id : int = 0
var _creation_time : float = 0.0
var _is_pooled : bool = false
var _signal_connections_setup : bool = false
var _is_dying : bool = false

# Statistics for pool usage
var _pool_retrieval_count : int = 0
var _last_pool_time : float = 0.0
var _total_active_time : float = 0.0

# Pooling lifecycle methods
func reset(): # Reset state for reuse
func prepare_for_pool(): # Prepare for returning to pool
```

### Pool Configuration

Enemies are pooled with:
- Initial size: 15 enemies
- Unlimited maximum size (default)
- Detailed statistics tracking

### Integration with Main Game

When an enemy is spawned:
1. The system attempts to get an enemy from the pool
2. If no pooled enemy is available, it instantiates a new one
3. The enemy is positioned and initialized
4. When the enemy dies, it's returned to the pool instead of being destroyed

## Debugging Features

The enemy pooling system includes extensive debugging:

### Individual Enemy Tracking

Each enemy tracks:
- Creation time
- Number of times retrieved from pool
- Total active time
- Average time between reuses

### Pool Statistics

The system captures aggregate statistics:
- Total objects created
- Pool hit rate
- Maximum pool size reached
- Objects unexpectedly deleted

### Debug Output

Debug output can be enabled with:
```gdscript
DebugSettings.toggle_debug("enemies", true)
DebugSettings.toggle_debug("pools", true)
```

The system logs:
- Enemy creation and destruction
- Pool retrieval and returns
- Performance metrics
- Statistics summaries (every 10 seconds)

## Usage Best Practices

1. **Initial Pool Size** - Set initial pool size based on expected maximum number of concurrent enemies
2. **Reset Behavior** - Ensure all properties are properly reset when an enemy is reused
3. **Signal Connections** - Properly disconnect signals in prepare_for_pool and reconnect in reset
4. **State Management** - Use the _is_dying flag to prevent multiple death sequences

## Performance Considerations

- The pooling system creates a small CPU overhead during pool operations
- This is significantly offset by avoiding the cost of instantiation
- Statistics tracking can be disabled in production builds if needed
- A properly sized initial pool reduces runtime allocations

## Future Improvements

- Configurable max pool size for enemies (currently unlimited)
- Pool warm-up/pre-loading at level start
- Advanced pool purging strategies (LRU, timeout-based)
- Object validation to ensure pooled objects remain valid
- More detailed performance metrics 