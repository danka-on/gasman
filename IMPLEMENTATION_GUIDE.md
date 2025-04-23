# Gas Cloud Pooling Implementation Guide

## Implementation Steps

Follow these steps to implement the gas cloud pooling system in your project:

1. **Add the Script Files:**
   - Add `poolable_gas_cloud.gd` to your scripts folder
   - Ensure it's accessible in your project

2. **Create the Poolable Scene:**
   - Option 1: Run the provided `create_poolable_gas_cloud.gd` editor script:
     - In Godot, open the script in the editor
     - Click "Run Current Script" in the script editor's toolbar
     - This will automatically create the `PoolableGasCloud.tscn` scene
   
   - Option 2: Manual creation:
     - Duplicate your existing `gas_cloud.tscn` scene
     - Save it as `PoolableGasCloud.tscn`
     - Select the root node and change its script to `poolable_gas_cloud.gd`

3. **Update the Pool System:**
   - The modified `pool_system.gd` already includes the necessary updates
   - Make sure the GAS_CLOUD pool type and path constants are correctly set

4. **Update Player.gd:**
   - The spawn_gas_cloud function has been updated to use the pool
   - The gas_cloud_scene preload now points to the poolable version
   - A fallback mechanism is in place for backward compatibility

5. **Enable Debugging:**
   - Use `DebugSettings.enable_gas_cloud_debugging()` to enable gas cloud debugging
   - Gas cloud debug messages will be categorized under "gas_clouds"
   - Pool statistics will be available through `PoolSystem.print_all_pool_stats()`

## Testing

To verify that the gas cloud pooling system is working correctly:

1. **Check Pool Creation:**
   - Look for the "PoolSystem: Created gas cloud pool with initial size of 8" message at startup
   - This confirms the pool was successfully initialized

2. **Monitor Gas Cloud Creation:**
   - Enable debugging with `DebugSettings.enable_gas_cloud_debugging()`
   - Create several gas clouds by using the gas cloud ability
   - Check the logs for "[PLAYER_DEBUG] Got gas cloud ID:X from pool" messages
   - After the initial pool is exhausted, you may see "[PLAYER_DEBUG] Created new gas cloud ID:X (not from pool)"

3. **Verify Pooling Behavior:**
   - When a gas cloud completes its lifetime, look for "Prepared for pool" messages
   - When new gas clouds are created, they should be retrieved from the pool instead of instantiated anew
   - Run `PoolSystem.print_all_pool_stats()` to see hit rate statistics

4. **Check Particle System:**
   - Ensure that particles don't respawn when new gas clouds are created
   - Particles should only appear when a gas cloud is actually created or reset

## Troubleshooting

### Common Issues and Solutions

1. **Missing Scene File:**
   - Error: "Failed to load poolable_gas_cloud.tscn"
   - Solution: Make sure you've created the scene file and it's in the correct location

2. **Particle Respawning Issue:**
   - Symptom: New particle effects appear when another gas cloud is spawned
   - Check: Ensure `particle_materials_initialized` is working correctly
   - Solution: If issues persist, modify the `initialize_particle_materials()` method to ensure proper material isolation

3. **Pool Not Found:**
   - Error: "Gas cloud pool does not exist or PoolSystem not available"
   - Check: Ensure PoolSystem autoload is properly set up
   - Solution: Verify the pool initialization code in `pool_system.gd`

4. **Objects Not Returning to Pool:**
   - Symptom: Cache hit rate remains low even after extended use
   - Check: Look for "Prepared for pool" messages when clouds fade out
   - Solution: Ensure the `prepare_for_pool()` method is properly handling pool returns

## Performance Monitoring

To monitor the performance impact of the gas cloud pooling system:

1. Use the "pools" debug category to track pool statistics
2. Check cache hit rates, which should increase over time
3. Monitor frame times during heavy gas cloud usage
4. Use the `PoolSystem.print_all_pool_stats()` function to get detailed metrics

With proper implementation, you should see reduced CPU usage and improved frame rates during gameplay sections with many gas clouds.

## Documentation

For more detailed information, refer to:

- `GAS_CLOUD_POOLING.md` - Technical documentation of the system
- `poolable_gas_cloud.gd` - Commented source code with implementation details 