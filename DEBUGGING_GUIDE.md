# Game Debugging Guide

## Overview

This document outlines our game's debugging system and establishes best practices for debugging moving forward. The system is designed to provide detailed insights into game performance, object pooling, and specific game systems while allowing granular control over what debugging information is displayed.

## Core Components

### DebugSettings System

The central system for managing debug output is the `DebugSettings` autoload singleton, which allows:

- Toggling specific debug categories on/off
- Centralized logging functions
- Runtime control of debug verbosity

```gdscript
# Enable debugging for a specific system
DebugSettings.toggle_debug("explosions", true)
DebugSettings.toggle_debug("pools", true)

# Log a message to a category
DebugSettings.log_debug("explosions", "Explosion created with ID: " + str(get_instance_id()))

# Log an error or warning
DebugSettings.log_error("pools", "Failed to find pool: " + pool_name)
```

### Debug Categories

The system supports several predefined categories:

| Category | Prefix | Purpose |
|----------|--------|---------|
| `pools` | `[POOL_DEBUG]` | Object pool management |
| `explosions` | `[EXPLOSIONS]` | Explosion lifecycle and effects |
| `gas_clouds` | `[GAS_CLOUD_DEBUG]` | Gas cloud behavior |
| `enemies` | `[ENEMY_DEBUG]` | Enemy behavior and lifecycle |
| `bullets` | `[BULLET_DEBUG]` | Bullet physics and collision |

### Pool System Debugging

The object pool system includes built-in statistics tracking:

```gdscript
# Print statistics for all pools
PoolSystem.print_all_pool_stats()

# Reset all pools (useful for testing)
PoolSystem.reset_all_pools()
```

Each pool tracks:
- Total objects created
- Current active and available objects
- Cache hit rate
- Maximum pool size reached
- Objects unexpectedly deleted

## Adding New Debug Systems

When implementing new systems, follow these guidelines:

1. **Use the central system**:
   ```gdscript
   if DebugSettings.is_debug_enabled("my_category"):
       DebugSettings.log_debug("my_category", "Debug message")
   ```

2. **Add useful object identification**:
   ```gdscript
   "[MY_SYSTEM] ID:" + str(get_instance_id()) + " - Action performed"
   ```

3. **Include timestamps for time-sensitive operations**:
   ```gdscript
   "Action completed at time: " + str(Time.get_ticks_msec() / 1000.0)
   ```

4. **Track performance metrics**:
   ```gdscript
   var start_time = Time.get_ticks_msec()
   # Operation here
   var duration = Time.get_ticks_msec() - start_time
   DebugSettings.log_debug("performance", "Operation took " + str(duration) + "ms")
   ```

## Performance Considerations

- Debug messages should be conditionally printed based on category toggles
- Heavy debug operations should be wrapped in condition checks
- Statistics gathering should be lightweight enough for production builds

## Common Debug Scenarios

### Troubleshooting Pool Issues

1. Enable pool debugging: `DebugSettings.toggle_debug("pools", true)`
2. Check hit rates: Watch for consistently low hit rates (<70%)
3. Examine pool statistics: `PoolSystem.print_all_pool_stats()`
4. Look for objects being created outside the pool

### Investigating Particle Effects

1. Enable explosions debugging: `DebugSettings.toggle_debug("explosions", true)`
2. Track particle emission: Look for `Starting particle emission` messages
3. Check lifetimes: Ensure objects are being reset and returned to pool properly

### Object Lifecycle Monitoring

Track creation, usage duration, and disposal:
```
[SYSTEM][INFO] ID:12345 - Created at time: 10.50
[SYSTEM][INFO] ID:12345 - Reset at time: 12.30 (alive for 1.80 seconds)
[SYSTEM][INFO] ID:12345 - Prepared for pool at time: 12.30 (used for 1.80 seconds)
```

## Debug Command Summary

```gdscript
# Core toggles
DebugSettings.toggle_debug("category", true/false)

# Log levels
DebugSettings.log_debug("category", "message")
DebugSettings.log_info("category", "message")
DebugSettings.log_warning("category", "message")
DebugSettings.log_error("category", "message")

# Pool statistics
PoolSystem.print_all_pool_stats()
PoolSystem.reset_all_pools()
``` 